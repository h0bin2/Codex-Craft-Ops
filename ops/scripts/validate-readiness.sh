#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

TASK_INPUT="${1:-}"

[[ -n "$TASK_INPUT" ]] || die "Usage: bash ops/scripts/validate-readiness.sh <task-file>"

TASK_FILE="$(resolve_path "$TASK_INPUT")"
require_file "$TASK_FILE"
assert_valid_task_file "$TASK_FILE"

if [[ "$(task_type_from_file "$TASK_FILE")" == "documentation" ]]; then
  echo "No implementation readiness gate required for documentation task: $TASK_FILE"
  exit 0
fi

DOC_ROOT="$(task_resolved_doc_root "$TASK_FILE")"
FEATURE_SPEC="$DOC_ROOT/01_requirements/FEATURE_SPEC.md"
CHANGE_LOG="$DOC_ROOT/01_requirements/CHANGE_LOG.md"
CRITICAL_REVIEW="$DOC_ROOT/04_evaluation/CRITICAL_REQUIREMENTS_REVIEW.md"

require_heading() {
  local file="$1"
  local heading="$2"
  grep -Eq "^## ${heading}$" "$file" || die "Missing required heading '## ${heading}' in $file"
}

requirements_status="$(read_task_value "requirements_status" "$TASK_FILE")"
design_status="$(read_task_value "design_status" "$TASK_FILE")"
implementation_ready="$(read_task_value "implementation_ready" "$TASK_FILE")"
critical_review_required="$(read_task_value "critical_review_required" "$TASK_FILE")"
critical_review_status="$(read_task_value "critical_review_status" "$TASK_FILE")"

[[ "$requirements_status" == "approved" ]] || die "requirements_status must be approved before implementation"
[[ "$design_status" == "approved" ]] || die "design_status must be approved before implementation"
[[ "$implementation_ready" == "true" ]] || die "implementation_ready must be true before implementation"

bash "$SCRIPT_DIR/validate-docs.sh" "$TASK_FILE" >/dev/null

require_heading "$FEATURE_SPEC" "Requirements Table"
require_heading "$FEATURE_SPEC" "Narrative Requirements"
require_heading "$FEATURE_SPEC" "Acceptance Criteria"
require_heading "$FEATURE_SPEC" "Version History"

require_heading "$CHANGE_LOG" "Change Entries"
require_heading "$CHANGE_LOG" "Integration Decisions"

if [[ "$critical_review_required" == "true" ]]; then
  [[ "$critical_review_status" == "approved" ]] || die "critical_review_status must be approved when critical_review_required=true"
  require_heading "$CRITICAL_REVIEW" "Critical Requirements"
  require_heading "$CRITICAL_REVIEW" "Design Review"
  require_heading "$CRITICAL_REVIEW" "Implementation Review"
  require_heading "$CRITICAL_REVIEW" "Verdict"

  while IFS= read -r critical_requirement; do
    [[ -n "$critical_requirement" ]] || continue
    grep -Fq "$critical_requirement" "$CRITICAL_REVIEW" || die "Critical requirement '$critical_requirement' must be referenced in $CRITICAL_REVIEW"
  done < <(yaml_list_values "critical_requirements" "$TASK_FILE")
fi

echo "Implementation readiness validated: $TASK_FILE"
