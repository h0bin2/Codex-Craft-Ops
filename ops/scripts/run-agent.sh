#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

ROLE="${1:-}"
TASK_INPUT="${2:-}"

[[ -n "$ROLE" ]] || die "Usage: bash ops/scripts/run-agent.sh <role> <task-file>"
[[ -n "$TASK_INPUT" ]] || die "Usage: bash ops/scripts/run-agent.sh <role> <task-file>"

ensure_runtime_dirs

TASK_FILE="$(resolve_path "$TASK_INPUT")"
require_file "$TASK_FILE"
require_file "$OPS_AGENTS_DIR/$ROLE.md"
require_file "$OPS_PROMPTS_DIR/$ROLE.md"
assert_valid_task_file "$TASK_FILE"

TASK_ID="$(task_id_from_file "$TASK_FILE")"
STAMP="$(timestamp)"
OUTPUT_FILE="$(task_output_file "$ROLE" "$TASK_ID")"
LOG_FILE="$(log_file_for "$TASK_ID" "$ROLE" "$STAMP")"
JSONL_FILE="$(jsonl_file_for "$TASK_ID" "$ROLE" "$STAMP")"
PROMPT_FILE="$(mktemp)"
PREVIOUS_TASK_STATUS="$(read_task_value "status" "$TASK_FILE")"
RUN_AGENT_COMPLETED=0
ADDITIONAL_DIRS=()
EXEC_TIMEOUT_SECONDS="${CODEX_EXEC_TIMEOUT_SECONDS:-300}"
MCP_CONFIG_ARGS=()
OUTPUT_TEMPLATE_FILE=""

CONTEXT_FILE=""
case "$ROLE" in
  implementer)
    CONTEXT_FILE="$(latest_file_matching "$HANDOFFS_DIR" "${TASK_ID}-pm-orchestrator.md")"
    OUTPUT_TEMPLATE_FILE="$HANDOFFS_DIR/templates/implementation-handoff.md"
    ;;
  reviewer)
    CONTEXT_FILE="$(latest_file_matching "$HANDOFFS_DIR" "${TASK_ID}-implementation-handoff.md")"
    OUTPUT_TEMPLATE_FILE="$HANDOFFS_DIR/templates/review-report.md"
    ;;
  pm-orchestrator)
    CONTEXT_FILE="$(latest_file_matching "$REPORTS_DIR" "${TASK_ID}-review-report.md")"
    OUTPUT_TEMPLATE_FILE="$HANDOFFS_DIR/templates/pm-handoff.md"
    ;;
  *)
    die "Unsupported role: $ROLE"
    ;;
esac

append_additional_dir() {
  local candidate="$1"
  local existing

  [[ -n "$candidate" ]] || return 0

  for existing in "${ADDITIONAL_DIRS[@]:-}"; do
    if [[ "$existing" == "$candidate" ]]; then
      return 0
    fi
  done

  ADDITIONAL_DIRS+=("$candidate")
}

while IFS= read -r arg; do
  [[ -n "$arg" ]] || continue
  MCP_CONFIG_ARGS+=("$arg")
done < <(codex_mcp_config_args)

if task_requires_docs "$TASK_FILE"; then
  append_additional_dir "$(task_resolved_doc_root "$TASK_FILE")"
fi

{
  printf '# Agent Definition\n\n'
  cat "$OPS_AGENTS_DIR/$ROLE.md"
  printf '\n\n# Role Prompt\n\n'
  cat "$OPS_PROMPTS_DIR/$ROLE.md"
  printf '\n\n# Execution Notes\n\n'
  printf -- '- Preflight health check already passed for this task before the current live run.\n'
  printf -- '- Do not invoke `bash ops/scripts/check-codex-health.sh` from inside this Codex session. Treat that check as already satisfied by the outer runner.\n'
  printf -- '- Do not invoke nested `codex exec` commands from inside this Codex session.\n'
  printf -- '- This workspace may not be a Git repository. Do not block on `git status` or other Git-only checks.\n'
  printf -- '- Your final response must match the required role output template exactly. Do not replace the template with free-form prose.\n'
  printf '\n\n# Task File\n\n'
  cat "$TASK_FILE"

  if [[ -n "$OUTPUT_TEMPLATE_FILE" ]]; then
    printf '\n\n# Output Template\n\n'
    cat "$OUTPUT_TEMPLATE_FILE"
  fi

  if [[ -n "$CONTEXT_FILE" ]]; then
    printf '\n\n# Latest Context\n\n'
    cat "$CONTEXT_FILE"
  fi
} >"$PROMPT_FILE"

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  cat <<EOF
DRY_RUN=1
ROLE=$ROLE
TASK_FILE=$TASK_FILE
OUTPUT_FILE=$OUTPUT_FILE
LOG_FILE=$LOG_FILE
JSONL_FILE=$JSONL_FILE
CONTEXT_FILE=${CONTEXT_FILE:-none}
PROMPT_FILE=$PROMPT_FILE
EOF
  printf '\n----- PROMPT START -----\n'
  cat "$PROMPT_FILE"
  printf '\n----- PROMPT END -----\n'
  exit 0
fi

parse_health_field() {
  local field="$1"
  printf '%s\n' "$HEALTH_OUTPUT" | awk -F= -v field="$field" '$1 == field { sub("^[^=]+=", "", $0); print; exit }'
}

write_blocked_output() {
  local reason="$1"
  local health_log="$2"
  local health_jsonl="$3"
  local recovery="$4"
  local doc_output
  local external_path

  case "$ROLE" in
    pm-orchestrator)
      {
        printf 'Status: blocked\n'
        printf 'Next Owner: pm-orchestrator\n\n'
        printf '## Task Decision\n'
        printf -- '- Selected Task: %s\n' "$TASK_ID"
        printf -- '- Priority: %s\n' "$(read_task_value "priority" "$TASK_FILE")"
        printf -- '- Reason: %s\n\n' "$reason"
        printf '## Breakdown\n'
        printf -- '- Step 1: Fix the Codex runtime or vault access blocker.\n'
        printf -- '- Step 2: Re-run the health check before retrying the agent.\n\n'
        printf '## Acceptance Criteria\n'
        while IFS= read -r acceptance_line; do
          [[ -n "$acceptance_line" ]] || continue
          printf -- '- %s\n' "$acceptance_line"
        done < <(yaml_list_values "acceptance" "$TASK_FILE")
        printf '\n## Document Deliverables\n'
        while IFS= read -r doc_output; do
          [[ -n "$doc_output" ]] || continue
          printf -- '- %s/%s\n' "$(task_doc_project_root "$TASK_FILE")" "$doc_output"
        done < <(yaml_list_values "doc_outputs" "$TASK_FILE")
        printf '\n## Doc Paths\n'
        printf -- '- %s\n' "$(task_resolved_doc_root "$TASK_FILE")"
        printf '\n## Risks or Blockers\n'
        printf -- '- %s\n' "$reason"
        printf -- '- Health log: %s\n' "$health_log"
        printf -- '- Health JSONL: %s\n' "$health_jsonl"
        printf -- '- Suggested recovery: %s\n' "$recovery"
      } >"$OUTPUT_FILE"
      ;;
    implementer)
      {
        printf 'Status: blocked\n'
        printf 'Next Owner: pm-orchestrator\n\n'
        printf '## Summary of Changes\n'
        printf -- '- No implementation started because the Codex health check failed.\n\n'
        printf '## Files Touched\n'
        printf -- '- None\n\n'
        printf '## Docs Updated\n'
        printf -- '- None\n\n'
        printf '## Validation Attempted\n'
        printf -- '- bash ops/scripts/check-codex-health.sh %s\n\n' "$TASK_FILE"
        printf '## Risks\n'
        printf -- '- %s\n' "$reason"
        printf -- '- Health log: %s\n' "$health_log"
        printf -- '- Health JSONL: %s\n\n' "$health_jsonl"
        printf '## Open Questions\n'
        printf -- '- %s\n' "$recovery"
      } >"$OUTPUT_FILE"
      ;;
    reviewer)
      {
        printf 'Review Status: blocked\n'
        printf 'Next Owner: pm-orchestrator\n\n'
        printf '## Checks Run\n'
        printf -- '- bash ops/scripts/check-codex-health.sh %s\n\n' "$TASK_FILE"
        printf '## Document Checks\n'
        printf -- '- Review did not start because the Codex health check failed first.\n\n'
        printf '## Findings\n'
        printf -- '- %s\n' "$reason"
        printf -- '- Health log: %s\n' "$health_log"
        printf -- '- Health JSONL: %s\n\n' "$health_jsonl"
        printf '## Missing Coverage\n'
        printf -- '- Live reviewer execution was blocked before checks ran.\n\n'
        printf '## Required Fixes\n'
        printf -- '- %s\n' "$recovery"
      } >"$OUTPUT_FILE"
      ;;
  esac
}

cleanup_run_agent() {
  if [[ "$RUN_AGENT_COMPLETED" == "1" ]]; then
    return 0
  fi

  update_task_value "$TASK_FILE" "status" "$PREVIOUS_TASK_STATUS"
  write_role_state "$ROLE" "$TASK_ID" "$TASK_FILE" "failed" "$OUTPUT_FILE"
}

trap cleanup_run_agent EXIT INT TERM

set +e
HEALTH_OUTPUT="$(bash "$SCRIPT_DIR/check-codex-health.sh" "$TASK_FILE" 2>&1)"
HEALTH_EXIT=$?
set -e

if (( HEALTH_EXIT != 0 )); then
  HEALTH_REASON="$(parse_health_field "reason")"
  HEALTH_LOG_PATH="$(parse_health_field "log_file")"
  HEALTH_JSONL_PATH="$(parse_health_field "jsonl_file")"
  HEALTH_RECOVERY="Check the Codex runtime, then rerun bash ops/scripts/check-codex-health.sh before retrying."

  if [[ -n "$HEALTH_OUTPUT" ]]; then
    printf '%s\n' "$HEALTH_OUTPUT" >>"$LOG_FILE"
  fi

  write_blocked_output "$HEALTH_REASON" "$HEALTH_LOG_PATH" "$HEALTH_JSONL_PATH" "$HEALTH_RECOVERY"
  bash "$SCRIPT_DIR/validate-output.sh" "$ROLE" "$OUTPUT_FILE" >>"$LOG_FILE" 2>&1

  update_task_value "$TASK_FILE" "status" "blocked"
  update_task_value "$TASK_FILE" "owner" "pm-orchestrator"
  update_task_value "$TASK_FILE" "handoff_to" "pm-orchestrator"

  case "$TASK_FILE" in
    "$TASKS_DONE_DIR"/*|"$TASKS_DOING_DIR"/*) ;;
    *)
      TASK_FILE="$(move_task_file "$TASK_FILE" "$TASKS_DOING_DIR")"
      ;;
  esac

  RUN_AGENT_COMPLETED=1
  trap - EXIT INT TERM
  write_role_state "$ROLE" "$TASK_ID" "$TASK_FILE" "blocked" "$OUTPUT_FILE"
  write_role_state "pm-orchestrator" "$TASK_ID" "$TASK_FILE" "blocked" "$OUTPUT_FILE"
  die "Codex health check failed. See $LOG_FILE"
fi

update_task_value "$TASK_FILE" "status" "running"
write_role_state "$ROLE" "$TASK_ID" "$TASK_FILE" "running" "$OUTPUT_FILE"

COMMAND=(
  codex exec
  --skip-git-repo-check
  --full-auto
  --sandbox workspace-write
  -C "$REPO_ROOT"
  --json
  -o "$OUTPUT_FILE"
)

if (( ${#MCP_CONFIG_ARGS[@]} > 0 )); then
  COMMAND+=("${MCP_CONFIG_ARGS[@]}")
fi

if [[ -n "${CODEX_PROFILE:-}" ]]; then
  COMMAND+=(-p "$CODEX_PROFILE")
fi

if [[ -n "${CODEX_MODEL:-}" ]]; then
  COMMAND+=(-m "$CODEX_MODEL")
fi

if (( ${#ADDITIONAL_DIRS[@]} > 0 )); then
  for additional_dir in "${ADDITIONAL_DIRS[@]}"; do
    COMMAND+=(--add-dir "$additional_dir")
  done
fi

COMMAND+=(-)

set +e
perl -e 'alarm shift @ARGV; exec @ARGV' "$EXEC_TIMEOUT_SECONDS" "${COMMAND[@]}" \
  <"$PROMPT_FILE" 1>"$JSONL_FILE" 2>"$LOG_FILE"
COMMAND_EXIT=$?
set -e

if (( COMMAND_EXIT == 0 )); then
  if bash "$SCRIPT_DIR/validate-output.sh" "$ROLE" "$OUTPUT_FILE" >>"$LOG_FILE" 2>&1; then
    RUN_AGENT_COMPLETED=1
    trap - EXIT INT TERM
    write_role_state "$ROLE" "$TASK_ID" "$TASK_FILE" "completed" "$OUTPUT_FILE"
    echo "$OUTPUT_FILE"
  else
    write_role_state "$ROLE" "$TASK_ID" "$TASK_FILE" "failed" "$OUTPUT_FILE"
    die "Agent output validation failed. See $LOG_FILE"
  fi
else
  if (( COMMAND_EXIT == 142 )); then
    printf 'ERROR: Codex execution timed out after %s seconds\n' "$EXEC_TIMEOUT_SECONDS" >>"$LOG_FILE"
  fi
  write_role_state "$ROLE" "$TASK_ID" "$TASK_FILE" "failed" "$OUTPUT_FILE"
  die "Codex execution failed. See $LOG_FILE"
fi
