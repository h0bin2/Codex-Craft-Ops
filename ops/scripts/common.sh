#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TASKS_DIR="$REPO_ROOT/tasks"
TASKS_QUEUE_DIR="$TASKS_DIR/queue"
TASKS_DOING_DIR="$TASKS_DIR/doing"
TASKS_DONE_DIR="$TASKS_DIR/done"
HANDOFFS_DIR="$REPO_ROOT/handoffs"
REPORTS_DIR="$REPO_ROOT/reports"
LOGS_DIR="$REPO_ROOT/logs"
STATE_DIR="$REPO_ROOT/state"
ARTIFACTS_DIR="$REPO_ROOT/artifacts"
OPS_AGENTS_DIR="$REPO_ROOT/ops/agents"
OPS_PROMPTS_DIR="$REPO_ROOT/ops/prompts"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

timestamp() {
  date +"%Y%m%dT%H%M%S"
}

ensure_runtime_dirs() {
  mkdir -p \
    "$TASKS_QUEUE_DIR" \
    "$TASKS_DOING_DIR" \
    "$TASKS_DONE_DIR" \
    "$HANDOFFS_DIR" \
    "$REPORTS_DIR" \
    "$LOGS_DIR" \
    "$STATE_DIR" \
    "$ARTIFACTS_DIR"
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || die "File not found: $path"
}

resolve_path() {
  local candidate="$1"

  if [[ "$candidate" = /* ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  if [[ -f "$candidate" ]]; then
    (
      cd "$(dirname "$candidate")" >/dev/null 2>&1
      printf '%s/%s\n' "$(pwd)" "$(basename "$candidate")"
    )
    return 0
  fi

  printf '%s/%s\n' "$REPO_ROOT" "$candidate"
}

yaml_files_in_dir() {
  local dir="$1"
  find "$dir" -maxdepth 1 -type f \( -name '*.yaml' -o -name '*.yml' \) | sort
}

read_task_value() {
  local key="$1"
  local file="$2"

  awk -v key="$key" '
    $0 ~ ("^" key ":") {
      sub("^[^:]+:[[:space:]]*", "", $0)
      print $0
      exit
    }
  ' "$file"
}

yaml_list_values() {
  local key="$1"
  local file="$2"

  awk -v key="$key" '
    BEGIN { in_block = 0 }
    $0 ~ ("^" key ":[[:space:]]*\\[\\][[:space:]]*$") {
      exit
    }
    $0 ~ ("^" key ":[[:space:]]*$") {
      in_block = 1
      next
    }
    in_block {
      if ($0 ~ /^[^[:space:]-]/) {
        exit
      }
      if ($0 ~ /^[[:space:]]*-[[:space:]]+/) {
        sub(/^[[:space:]]*-[[:space:]]+/, "", $0)
        print $0
      }
    }
  ' "$file"
}

update_task_value() {
  local file="$1"
  local key="$2"
  local value="$3"
  local tmp

  tmp="$(mktemp)"

  awk -v key="$key" -v value="$value" '
    BEGIN { found = 0 }
    $0 ~ ("^" key ":") {
      print key ": " value
      found = 1
      next
    }
    { print }
    END {
      if (found == 0) {
        print key ": " value
      }
    }
  ' "$file" >"$tmp"

  mv "$tmp" "$file"
}

task_id_from_file() {
  local file="$1"
  local task_id

  task_id="$(read_task_value "id" "$file")"
  [[ -n "$task_id" ]] || die "Missing id in task file: $file"
  printf '%s\n' "$task_id"
}

task_type_from_file() {
  local file="$1"
  read_task_value "task_type" "$file"
}

task_doc_project_root() {
  local file="$1"
  read_task_value "doc_project_root" "$file"
}

task_resolved_doc_root() {
  local file="$1"
  local raw_root

  raw_root="$(task_doc_project_root "$file")"
  [[ -n "$raw_root" ]] || return 0
  resolve_path "$raw_root"
}

task_requires_docs() {
  local file="$1"
  case "$(task_type_from_file "$file")" in
    documentation|mixed)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

task_requires_external_docs() {
  task_requires_docs "$@"
}

codex_mcp_config_args() {
  local disable_remote_mcp="${CODEX_DISABLE_REMOTE_MCP:-1}"

  if [[ "$disable_remote_mcp" != "1" ]]; then
    return 0
  fi

  printf '%s\n' "-c"
  printf '%s\n' "mcp_servers.figma.enabled=false"
  printf '%s\n' "-c"
  printf '%s\n' "mcp_servers.supabase.enabled=false"
  printf '%s\n' "-c"
  printf '%s\n' "mcp_servers.notion.enabled=false"
  printf '%s\n' "-c"
  printf '%s\n' "mcp_servers.h2d.enabled=false"
}

priority_rank() {
  local priority="$1"
  case "$priority" in
    critical)
      printf '0\n'
      ;;
    high)
      printf '1\n'
      ;;
    medium)
      printf '2\n'
      ;;
    low)
      printf '3\n'
      ;;
    *)
      printf '9\n'
      ;;
  esac
}

list_contains() {
  local expected="$1"
  shift
  local value
  for value in "$@"; do
    if [[ "$value" == "$expected" ]]; then
      return 0
    fi
  done
  return 1
}

all_task_files() {
  find "$TASKS_DIR" -type f \( -name '*.yaml' -o -name '*.yml' \) | sort
}

find_task_file_by_id() {
  local expected_id="$1"
  local file

  while IFS= read -r file; do
    if [[ "$(task_id_from_file "$file")" == "$expected_id" ]]; then
      printf '%s\n' "$file"
      return 0
    fi
  done < <(all_task_files)

  return 1
}

task_dependencies_satisfied() {
  local file="$1"
  local dependency
  local dependency_file
  local dependency_status

  while IFS= read -r dependency; do
    [[ -n "$dependency" ]] || continue

    if ! dependency_file="$(find_task_file_by_id "$dependency")"; then
      return 1
    fi

    dependency_status="$(read_task_value "status" "$dependency_file")"
    if [[ "$dependency_status" != "done" ]]; then
      return 1
    fi
  done < <(yaml_list_values "dependencies" "$file")

  return 0
}

assert_valid_task_file() {
  local file="$1"
  local errors=()
  local key
  local value
  local task_type
  local owner
  local handoff_to
  local status
  local priority
  local doc_stage
  local doc_root
  local has_allowed_paths=0
  local has_acceptance=0
  local has_doc_outputs=0

  for key in id title summary owner priority handoff_to status task_type; do
    value="$(read_task_value "$key" "$file")"
    if [[ -z "$value" ]]; then
      errors+=("Missing required key: $key")
    fi
  done

  task_type="$(task_type_from_file "$file")"
  owner="$(read_task_value "owner" "$file")"
  handoff_to="$(read_task_value "handoff_to" "$file")"
  status="$(read_task_value "status" "$file")"
  priority="$(read_task_value "priority" "$file")"
  doc_stage="$(read_task_value "doc_stage" "$file")"
  doc_root="$(task_resolved_doc_root "$file")"

  if ! list_contains "$task_type" implementation documentation mixed; then
    errors+=("Unsupported task_type: ${task_type:-missing}")
  fi

  if ! list_contains "$owner" pm-orchestrator implementer reviewer; then
    errors+=("Unsupported owner: ${owner:-missing}")
  fi

  if ! list_contains "$handoff_to" pm-orchestrator implementer reviewer; then
    errors+=("Unsupported handoff_to: ${handoff_to:-missing}")
  fi

  if ! list_contains "$status" queued assigned running blocked needs_review done; then
    errors+=("Unsupported status: ${status:-missing}")
  fi

  if ! list_contains "$priority" critical high medium low; then
    errors+=("Unsupported priority: ${priority:-missing}")
  fi

  while IFS= read -r value; do
    [[ -n "$value" ]] || continue
    has_allowed_paths=1
  done < <(yaml_list_values "allowed_paths" "$file")

  while IFS= read -r value; do
    [[ -n "$value" ]] || continue
    has_acceptance=1
  done < <(yaml_list_values "acceptance" "$file")

  if [[ "$has_acceptance" -eq 0 ]]; then
    errors+=("acceptance must contain at least one item")
  fi

  case "$task_type" in
    implementation)
      if [[ "$has_allowed_paths" -eq 0 ]]; then
        errors+=("implementation tasks require at least one allowed_paths entry")
      fi
      ;;
    documentation)
      ;;
    mixed)
      if [[ "$has_allowed_paths" -eq 0 ]]; then
        errors+=("mixed tasks require at least one allowed_paths entry")
      fi
      ;;
  esac

  if task_requires_docs "$file"; then
    if ! list_contains "$doc_stage" requirements design development evaluation; then
      errors+=("Unsupported doc_stage: ${doc_stage:-missing}")
    fi

    if [[ -z "$doc_root" ]]; then
      errors+=("Missing required key: doc_project_root")
    elif [[ "$doc_root" != "$REPO_ROOT/docs" && "$doc_root" != "$REPO_ROOT/docs/"* ]]; then
      errors+=("doc_project_root must resolve inside $REPO_ROOT/docs")
    fi

    while IFS= read -r value; do
      [[ -n "$value" ]] || continue
      has_doc_outputs=1
      if [[ "$value" == /* ]]; then
        errors+=("doc_outputs must be relative to doc_project_root: $value")
      elif ! [[ "$value" == 01_requirements/* || "$value" == 02_design/* || "$value" == 03_development/* || "$value" == 04_evaluation/* ]]; then
        errors+=("doc_outputs must live under 01_requirements, 02_design, 03_development, or 04_evaluation: $value")
      fi
    done < <(yaml_list_values "doc_outputs" "$file")

    if [[ "$has_doc_outputs" -eq 0 ]]; then
      errors+=("documentation and mixed tasks require doc_outputs entries")
    fi
  fi

  if (( ${#errors[@]} > 0 )); then
    printf 'ERROR: invalid task file: %s\n' "$file" >&2
    printf ' - %s\n' "${errors[@]}" >&2
    return 1
  fi
}

state_file_for_role() {
  local role="$1"
  printf '%s/%s.env\n' "$STATE_DIR" "$role"
}

write_role_state() {
  local role="$1"
  local task_id="$2"
  local task_file="$3"
  local status="$4"
  local last_output="${5:-}"

  cat >"$(state_file_for_role "$role")" <<EOF
role=$role
task_id=$task_id
task_file=$task_file
status=$status
last_update=$(timestamp)
last_output=$last_output
EOF
}

latest_file_matching() {
  local dir="$1"
  local pattern="$2"

  find "$dir" -maxdepth 1 -type f -name "$pattern" | sort | tail -n 1
}

doc_value() {
  local label="$1"
  local file="$2"

  awk -F': ' -v label="$label" '$1 == label { print $2; exit }' "$file"
}

task_output_file() {
  local role="$1"
  local task_id="$2"

  case "$role" in
    pm-orchestrator)
      printf '%s/%s-pm-orchestrator.md\n' "$HANDOFFS_DIR" "$task_id"
      ;;
    implementer)
      printf '%s/%s-implementation-handoff.md\n' "$HANDOFFS_DIR" "$task_id"
      ;;
    reviewer)
      printf '%s/%s-review-report.md\n' "$REPORTS_DIR" "$task_id"
      ;;
    *)
      die "Unsupported role: $role"
      ;;
  esac
}

log_file_for() {
  local task_id="$1"
  local role="$2"
  local stamp="$3"
  printf '%s/%s-%s-%s.log\n' "$LOGS_DIR" "$task_id" "$role" "$stamp"
}

jsonl_file_for() {
  local task_id="$1"
  local role="$2"
  local stamp="$3"
  printf '%s/%s-%s-%s.jsonl\n' "$LOGS_DIR" "$task_id" "$role" "$stamp"
}

move_task_file() {
  local file="$1"
  local target_dir="$2"
  local destination="$target_dir/$(basename "$file")"

  if [[ "$file" != "$destination" ]]; then
    mv "$file" "$destination"
  fi

  printf '%s\n' "$destination"
}

print_status_summary() {
  local dir="$1"
  local count

  count="$(yaml_files_in_dir "$dir" | wc -l | tr -d ' ')"
  printf '%s' "$count"
}
