#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

ensure_runtime_dirs

TASK_INPUT="${1:-}"

if [[ -n "$TASK_INPUT" ]]; then
  TASK_FILE="$(resolve_path "$TASK_INPUT")"
else
  TASK_FILE=""
fi

if [[ -n "${TASK_FILE:-}" ]]; then
  require_file "$TASK_FILE"
else
  BEST_RANK=99
  while IFS= read -r candidate; do
    assert_valid_task_file "$candidate"

    if ! task_dependencies_satisfied "$candidate"; then
      continue
    fi

    candidate_rank="$(priority_rank "$(read_task_value "priority" "$candidate")")"
    if (( candidate_rank < BEST_RANK )); then
      BEST_RANK="$candidate_rank"
      TASK_FILE="$candidate"
    fi
  done < <(yaml_files_in_dir "$TASKS_QUEUE_DIR")
fi

[[ -n "${TASK_FILE:-}" ]] || die "No queued task with satisfied dependencies found."

case "$TASK_FILE" in
  "$TASKS_QUEUE_DIR"/*) ;;
  *)
    die "pick-task.sh only accepts tasks from $TASKS_QUEUE_DIR"
    ;;
esac

assert_valid_task_file "$TASK_FILE"
TASK_ID="$(task_id_from_file "$TASK_FILE")"

update_task_value "$TASK_FILE" "owner" "implementer"
update_task_value "$TASK_FILE" "handoff_to" "reviewer"
update_task_value "$TASK_FILE" "status" "assigned"

TASK_FILE="$(move_task_file "$TASK_FILE" "$TASKS_DOING_DIR")"
write_role_state "pm-orchestrator" "$TASK_ID" "$TASK_FILE" "assigned" ""

echo "$TASK_FILE"
