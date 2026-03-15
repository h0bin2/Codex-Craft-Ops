#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEFAULT_PROJECTS_ROOT="$REPO_ROOT/docs"
PROJECT_INPUT="${1:-docs}"

[[ -n "$PROJECT_INPUT" ]] || {
  echo "Usage: bash ops/scripts/bootstrap-doc-project.sh <docs-root|relative-docs-subdir|absolute-docs-path>" >&2
  exit 1
}

if [[ "$PROJECT_INPUT" = /* ]]; then
  PROJECT_ROOT="$PROJECT_INPUT"
elif [[ "$PROJECT_INPUT" == docs || "$PROJECT_INPUT" == docs/* ]]; then
  PROJECT_ROOT="$REPO_ROOT/$PROJECT_INPUT"
else
  PROJECT_ROOT="$DEFAULT_PROJECTS_ROOT/$PROJECT_INPUT"
fi

PROJECT_NAME="$(basename "$PROJECT_ROOT")"

mkdir -p \
  "$PROJECT_ROOT/01_requirements" \
  "$PROJECT_ROOT/02_design" \
  "$PROJECT_ROOT/03_development" \
  "$PROJECT_ROOT/04_evaluation"

write_if_missing() {
  local path="$1"
  local content="$2"

  if [[ -f "$path" ]]; then
    return 0
  fi

  printf '%s' "$content" >"$path"
}

write_if_missing "$PROJECT_ROOT/01_requirements/PRD.md" "# PRD

## Project
- Name: $PROJECT_NAME

## Problem
- Describe the product problem.

## Goals
- Define measurable goals.

## Scope
- Define in-scope and out-of-scope items.

## References
- [[FEATURE_SPEC]]
- [[INTERFACES]]
"

write_if_missing "$PROJECT_ROOT/01_requirements/FEATURE_SPEC.md" "# Feature Spec

## Project
- Name: $PROJECT_NAME

## User Scenarios
- Describe primary user flows.

## Functional Requirements
- List concrete requirements.

## Acceptance Criteria
- Define measurable success conditions.

## References
- [[PRD]]
- [[INTERFACES]]
"

write_if_missing "$PROJECT_ROOT/01_requirements/INTERFACES.md" "# Interfaces

## Inputs
- Define incoming interfaces, forms, or events.

## Outputs
- Define outputs, responses, or generated artifacts.

## Constraints
- Define boundary conditions and ownership.

## References
- [[PRD]]
- [[FEATURE_SPEC]]
"

write_if_missing "$PROJECT_ROOT/02_design/ARCHITECTURE.md" "# Architecture

## Requirements Input
- Source: [[PRD]]
- Source: [[FEATURE_SPEC]]
- Source: [[INTERFACES]]

## Solution Overview
- Describe the target architecture.

## Data Flow
- Describe the flow across components.

## Risks
- List architectural risks.
"

write_if_missing "$PROJECT_ROOT/02_design/DECISIONS.md" "# Decisions

## Context
- Link to [[ARCHITECTURE]]

## Decisions
- Record design decisions and tradeoffs.

## Consequences
- Describe downstream impact.
"

write_if_missing "$PROJECT_ROOT/03_development/IMPLEMENTATION_PLAN.md" "# Implementation Plan

## Inputs
- Requirements: [[../01_requirements/FEATURE_SPEC.md]]
- Design: [[../02_design/ARCHITECTURE.md]]

## Work Breakdown
- Define implementation steps.

## Validation Plan
- Define lint, test, build, and manual checks.
"

write_if_missing "$PROJECT_ROOT/03_development/WORKLOG.md" "# Worklog

## Source Plan
- [[IMPLEMENTATION_PLAN]]

## Execution Notes
- Track implementation progress and blockers.

## Changes
- Summarize code and document updates.
"

write_if_missing "$PROJECT_ROOT/04_evaluation/ACCEPTANCE_REPORT.md" "# Acceptance Report

## Inputs
- Development: [[../03_development/IMPLEMENTATION_PLAN.md]]
- Development: [[../03_development/WORKLOG.md]]

## Checks
- Record acceptance checks and outcomes.

## Gaps
- Record unresolved issues.
"

write_if_missing "$PROJECT_ROOT/04_evaluation/REVIEW_REPORT.md" "# Review Report

## Inputs
- [[ACCEPTANCE_REPORT]]

## Findings
- Record reviewer findings.

## Next Actions
- Record fixes, follow-ups, or sign-off.
"

echo "Bootstrapped document project: $PROJECT_ROOT"
