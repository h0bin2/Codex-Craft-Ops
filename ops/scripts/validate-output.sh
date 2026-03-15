#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

ROLE="${1:-}"
OUTPUT_INPUT="${2:-}"

[[ -n "$ROLE" ]] || die "Usage: bash ops/scripts/validate-output.sh <role> <output-file>"
[[ -n "$OUTPUT_INPUT" ]] || die "Usage: bash ops/scripts/validate-output.sh <role> <output-file>"

OUTPUT_FILE="$(resolve_path "$OUTPUT_INPUT")"
require_file "$OUTPUT_FILE"

require_line() {
  local pattern="$1"
  if ! grep -Eq "$pattern" "$OUTPUT_FILE"; then
    die "Missing required line or pattern '$pattern' in $OUTPUT_FILE"
  fi
}

require_section() {
  local heading="$1"
  if ! grep -Eq "^## ${heading}\$" "$OUTPUT_FILE"; then
    die "Missing required section '## ${heading}' in $OUTPUT_FILE"
  fi
}

require_any_section() {
  local pattern="$1"
  if ! grep -Eq "^## (${pattern})\$" "$OUTPUT_FILE"; then
    die "Missing required section matching '## (${pattern})' in $OUTPUT_FILE"
  fi
}

case "$ROLE" in
  pm-orchestrator)
    require_line '^Status: (assigned|blocked)$'
    require_line '^Next Owner: (implementer|reviewer|pm-orchestrator)$'
    require_section 'Task Decision'
    require_section 'Breakdown'
    require_section 'Acceptance Criteria'
    require_section 'Document Deliverables'
    require_any_section 'Doc Paths|External Paths'
    require_section 'Risks or Blockers'
    ;;
  implementer)
    require_line '^Status: (needs_review|blocked)$'
    require_line '^Next Owner: (reviewer|pm-orchestrator)$'
    require_section 'Summary of Changes'
    require_section 'Files Touched'
    require_section 'Docs Updated'
    require_section 'Validation Attempted'
    require_section 'Risks'
    require_section 'Open Questions'
    ;;
  reviewer)
    require_line '^Review Status: (pass|needs_fix|blocked)$'
    require_line '^Next Owner: (pm-orchestrator|implementer)$'
    require_section 'Checks Run'
    require_section 'Document Checks'
    require_section 'Findings'
    require_section 'Missing Coverage'
    require_section 'Required Fixes'
    ;;
  *)
    die "Unsupported role: $ROLE"
    ;;
esac

echo "Valid output for $ROLE: $OUTPUT_FILE"
