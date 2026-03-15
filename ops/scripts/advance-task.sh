#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

ROLE="${1:-}"
TASK_INPUT="${2:-}"
OUTPUT_INPUT="${3:-}"

[[ -n "$ROLE" ]] || die "Usage: bash ops/scripts/advance-task.sh <role> <task-file> <output-file>"
[[ -n "$TASK_INPUT" ]] || die "Usage: bash ops/scripts/advance-task.sh <role> <task-file> <output-file>"
[[ -n "$OUTPUT_INPUT" ]] || die "Usage: bash ops/scripts/advance-task.sh <role> <task-file> <output-file>"

ensure_runtime_dirs

TASK_FILE="$(resolve_path "$TASK_INPUT")"
OUTPUT_FILE="$(resolve_path "$OUTPUT_INPUT")"

require_file "$TASK_FILE"
require_file "$OUTPUT_FILE"
assert_valid_task_file "$TASK_FILE"
bash "$SCRIPT_DIR/validate-output.sh" "$ROLE" "$OUTPUT_FILE"

TASK_ID="$(task_id_from_file "$TASK_FILE")"
NEXT_OWNER="$(doc_value "Next Owner" "$OUTPUT_FILE")"

[[ -n "$NEXT_OWNER" ]] || die "Missing Next Owner in $OUTPUT_FILE"

case "$ROLE" in
  pm-orchestrator)
    RESULT_STATUS="$(doc_value "Status" "$OUTPUT_FILE")"
    [[ -n "$RESULT_STATUS" ]] || die "Missing Status in $OUTPUT_FILE"

    case "$RESULT_STATUS" in
      assigned)
        update_task_value "$TASK_FILE" "status" "assigned"
        update_task_value "$TASK_FILE" "owner" "$NEXT_OWNER"
        update_task_value "$TASK_FILE" "handoff_to" "$NEXT_OWNER"
        TASK_FILE="$(move_task_file "$TASK_FILE" "$TASKS_DOING_DIR")"
        ;;
      blocked)
        update_task_value "$TASK_FILE" "status" "blocked"
        update_task_value "$TASK_FILE" "owner" "pm-orchestrator"
        update_task_value "$TASK_FILE" "handoff_to" "pm-orchestrator"
        TASK_FILE="$(move_task_file "$TASK_FILE" "$TASKS_DOING_DIR")"
        ;;
      *)
        die "Unsupported pm-orchestrator status: $RESULT_STATUS"
        ;;
    esac
    ;;
  implementer)
    RESULT_STATUS="$(doc_value "Status" "$OUTPUT_FILE")"
    [[ -n "$RESULT_STATUS" ]] || die "Missing Status in $OUTPUT_FILE"

    case "$RESULT_STATUS" in
      needs_review)
        if task_requires_external_docs "$TASK_FILE"; then
          bash "$SCRIPT_DIR/validate-docs.sh" "$TASK_FILE"
        fi
        update_task_value "$TASK_FILE" "status" "needs_review"
        update_task_value "$TASK_FILE" "owner" "reviewer"
        update_task_value "$TASK_FILE" "handoff_to" "reviewer"
        TASK_FILE="$(move_task_file "$TASK_FILE" "$TASKS_DOING_DIR")"
        ;;
      blocked)
        update_task_value "$TASK_FILE" "status" "blocked"
        update_task_value "$TASK_FILE" "owner" "pm-orchestrator"
        update_task_value "$TASK_FILE" "handoff_to" "pm-orchestrator"
        TASK_FILE="$(move_task_file "$TASK_FILE" "$TASKS_DOING_DIR")"
        ;;
      *)
        die "Unsupported implementer status: $RESULT_STATUS"
        ;;
    esac
    ;;
  reviewer)
    RESULT_STATUS="$(doc_value "Review Status" "$OUTPUT_FILE")"
    [[ -n "$RESULT_STATUS" ]] || die "Missing Review Status in $OUTPUT_FILE"

    case "$RESULT_STATUS" in
      pass)
        if task_requires_external_docs "$TASK_FILE"; then
          bash "$SCRIPT_DIR/validate-docs.sh" "$TASK_FILE"
        fi
        update_task_value "$TASK_FILE" "status" "done"
        update_task_value "$TASK_FILE" "owner" "pm-orchestrator"
        update_task_value "$TASK_FILE" "handoff_to" "pm-orchestrator"
        TASK_FILE="$(move_task_file "$TASK_FILE" "$TASKS_DONE_DIR")"
        ;;
      needs_fix)
        update_task_value "$TASK_FILE" "status" "assigned"
        update_task_value "$TASK_FILE" "owner" "implementer"
        update_task_value "$TASK_FILE" "handoff_to" "reviewer"
        TASK_FILE="$(move_task_file "$TASK_FILE" "$TASKS_DOING_DIR")"
        ;;
      blocked)
        update_task_value "$TASK_FILE" "status" "blocked"
        update_task_value "$TASK_FILE" "owner" "pm-orchestrator"
        update_task_value "$TASK_FILE" "handoff_to" "pm-orchestrator"
        TASK_FILE="$(move_task_file "$TASK_FILE" "$TASKS_DOING_DIR")"
        ;;
      *)
        die "Unsupported reviewer status: $RESULT_STATUS"
        ;;
    esac
    ;;
  *)
    die "Unsupported role: $ROLE"
    ;;
esac

write_role_state "$ROLE" "$TASK_ID" "$TASK_FILE" "$RESULT_STATUS" "$OUTPUT_FILE"

case "$NEXT_OWNER" in
  pm-orchestrator|implementer|reviewer)
    write_role_state "$NEXT_OWNER" "$TASK_ID" "$TASK_FILE" "$RESULT_STATUS" "$OUTPUT_FILE"
    ;;
esac

echo "$TASK_FILE"
