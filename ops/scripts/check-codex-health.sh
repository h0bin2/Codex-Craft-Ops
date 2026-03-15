#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

TASK_INPUT="${1:-}"

[[ -n "$TASK_INPUT" ]] || die "Usage: bash ops/scripts/check-codex-health.sh <task-file>"

TASK_FILE="$(resolve_path "$TASK_INPUT")"
require_file "$TASK_FILE"
assert_valid_task_file "$TASK_FILE"

if task_requires_docs "$TASK_FILE"; then
  DOC_ROOT="$(task_resolved_doc_root "$TASK_FILE")"

  if [[ ! -d "$DOC_ROOT" ]]; then
    printf 'status=failed\n'
    printf 'reason=document root is missing: %s\n' "$DOC_ROOT"
    printf 'log_file=none\n'
    printf 'jsonl_file=none\n'
    exit 1
  fi
fi

HEALTH_TIMEOUT_SECONDS="${CODEX_HEALTHCHECK_TIMEOUT_SECONDS:-15}"
PROBE_OUTPUT_FILE="$(mktemp /tmp/codex-health-output-XXXXXX)"
PROBE_JSONL_FILE="$(mktemp /tmp/codex-health-jsonl-XXXXXX)"
PROBE_LOG_FILE="$(mktemp /tmp/codex-health-stderr-XXXXXX)"
MCP_CONFIG_ARGS=()

while IFS= read -r arg; do
  [[ -n "$arg" ]] || continue
  MCP_CONFIG_ARGS+=("$arg")
done < <(codex_mcp_config_args)

COMMAND=(
  codex exec
  --skip-git-repo-check
  --sandbox read-only
  --ephemeral
  -C "$REPO_ROOT"
  --json
  -o "$PROBE_OUTPUT_FILE"
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

if task_requires_docs "$TASK_FILE"; then
  COMMAND+=(--add-dir "$(task_resolved_doc_root "$TASK_FILE")")
fi

COMMAND+=(-)

set +e
printf 'Reply with the single word OK.\n' \
  | perl -e 'alarm shift @ARGV; exec @ARGV' "$HEALTH_TIMEOUT_SECONDS" "${COMMAND[@]}" \
      1>"$PROBE_JSONL_FILE" 2>"$PROBE_LOG_FILE"
COMMAND_STATUS=$?
set -e

if (( COMMAND_STATUS != 0 )); then
  printf 'status=failed\n'
  printf 'reason=codex exec probe exited with status %s\n' "$COMMAND_STATUS"
  printf 'log_file=%s\n' "$PROBE_LOG_FILE"
  printf 'jsonl_file=%s\n' "$PROBE_JSONL_FILE"
  exit 1
fi

if grep -Eq \
  'Could not create otel exporter|Attempted to create a NULL object|event loop thread panicked|called `Result::unwrap\(\)` on an `Err` value' \
  "$PROBE_LOG_FILE"; then
  printf 'status=failed\n'
  printf 'reason=codex health probe detected a runtime panic signature\n'
  printf 'log_file=%s\n' "$PROBE_LOG_FILE"
  printf 'jsonl_file=%s\n' "$PROBE_JSONL_FILE"
  exit 1
fi

if ! grep -q '"type":"turn.started"' "$PROBE_JSONL_FILE"; then
  printf 'status=failed\n'
  printf 'reason=codex health probe did not emit expected JSONL events\n'
  printf 'log_file=%s\n' "$PROBE_LOG_FILE"
  printf 'jsonl_file=%s\n' "$PROBE_JSONL_FILE"
  exit 1
fi

printf 'status=ok\n'
printf 'reason=codex health probe succeeded\n'
printf 'log_file=%s\n' "$PROBE_LOG_FILE"
printf 'jsonl_file=%s\n' "$PROBE_JSONL_FILE"
