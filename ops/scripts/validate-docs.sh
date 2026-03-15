#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

TASK_INPUT="${1:-}"

[[ -n "$TASK_INPUT" ]] || die "Usage: bash ops/scripts/validate-docs.sh <task-file>"

TASK_FILE="$(resolve_path "$TASK_INPUT")"
require_file "$TASK_FILE"
assert_valid_task_file "$TASK_FILE"

if ! task_requires_docs "$TASK_FILE"; then
  echo "No document validation required for: $TASK_FILE"
  exit 0
fi

DOC_ROOT="$(task_resolved_doc_root "$TASK_FILE")"
[[ -d "$DOC_ROOT" ]] || die "Document project root not found: $DOC_ROOT"

require_doc_path() {
  local relative_path="$1"
  [[ -f "$DOC_ROOT/$relative_path" ]] || die "Missing required document: $DOC_ROOT/$relative_path"
}

require_dir_path() {
  local relative_path="$1"
  [[ -d "$DOC_ROOT/$relative_path" ]] || die "Missing required directory: $DOC_ROOT/$relative_path"
}

file_contains_reference() {
  local file="$1"
  local target="$2"
  local stem="${target%.md}"
  grep -Eq "\\[\\[(${target//./\\.}|${stem//./\\.})([#|][^]]+)?\\]\\]|${target//./\\.}|${stem//./\\.}" "$file"
}

for dir in 01_requirements 02_design 03_development 04_evaluation; do
  require_dir_path "$dir"
done

for file in \
  01_requirements/PRD.md \
  01_requirements/FEATURE_SPEC.md \
  01_requirements/CHANGE_LOG.md \
  01_requirements/INTERFACES.md \
  02_design/ARCHITECTURE.md \
  02_design/DECISIONS.md \
  03_development/IMPLEMENTATION_PLAN.md \
  03_development/WORKLOG.md \
  04_evaluation/ACCEPTANCE_REPORT.md \
  04_evaluation/CRITICAL_REQUIREMENTS_REVIEW.md \
  04_evaluation/REVIEW_REPORT.md; do
  require_doc_path "$file"
done

while IFS= read -r relative_doc; do
  [[ -n "$relative_doc" ]] || continue
  require_doc_path "$relative_doc"
done < <(yaml_list_values "doc_outputs" "$TASK_FILE")

file_contains_reference "$DOC_ROOT/02_design/ARCHITECTURE.md" "PRD.md" \
  || file_contains_reference "$DOC_ROOT/02_design/ARCHITECTURE.md" "FEATURE_SPEC.md" \
  || die "ARCHITECTURE.md must reference a requirements document"

file_contains_reference "$DOC_ROOT/02_design/DECISIONS.md" "ARCHITECTURE.md" \
  || die "DECISIONS.md must reference ARCHITECTURE.md"

file_contains_reference "$DOC_ROOT/01_requirements/CHANGE_LOG.md" "FEATURE_SPEC.md" \
  || file_contains_reference "$DOC_ROOT/01_requirements/CHANGE_LOG.md" "PRD.md" \
  || die "CHANGE_LOG.md must reference a requirements document"

file_contains_reference "$DOC_ROOT/03_development/IMPLEMENTATION_PLAN.md" "FEATURE_SPEC.md" \
  || die "IMPLEMENTATION_PLAN.md must reference FEATURE_SPEC.md"

file_contains_reference "$DOC_ROOT/03_development/IMPLEMENTATION_PLAN.md" "ARCHITECTURE.md" \
  || die "IMPLEMENTATION_PLAN.md must reference ARCHITECTURE.md"

file_contains_reference "$DOC_ROOT/03_development/WORKLOG.md" "IMPLEMENTATION_PLAN.md" \
  || die "WORKLOG.md must reference IMPLEMENTATION_PLAN.md"

file_contains_reference "$DOC_ROOT/04_evaluation/ACCEPTANCE_REPORT.md" "IMPLEMENTATION_PLAN.md" \
  || file_contains_reference "$DOC_ROOT/04_evaluation/ACCEPTANCE_REPORT.md" "WORKLOG.md" \
  || die "ACCEPTANCE_REPORT.md must reference development documentation"

file_contains_reference "$DOC_ROOT/04_evaluation/CRITICAL_REQUIREMENTS_REVIEW.md" "ARCHITECTURE.md" \
  || file_contains_reference "$DOC_ROOT/04_evaluation/CRITICAL_REQUIREMENTS_REVIEW.md" "IMPLEMENTATION_PLAN.md" \
  || file_contains_reference "$DOC_ROOT/04_evaluation/CRITICAL_REQUIREMENTS_REVIEW.md" "WORKLOG.md" \
  || die "CRITICAL_REQUIREMENTS_REVIEW.md must reference design or development documentation"

file_contains_reference "$DOC_ROOT/04_evaluation/REVIEW_REPORT.md" "ACCEPTANCE_REPORT.md" \
  || die "REVIEW_REPORT.md must reference ACCEPTANCE_REPORT.md"

echo "Valid document project: $DOC_ROOT"
