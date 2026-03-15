# Implementation Plan

## Inputs
- Requirements: [[../01_requirements/FEATURE_SPEC.md]]
- Design: [[../02_design/ARCHITECTURE.md]]

## Work Breakdown
- Keep task, prompt, and validator contracts aligned when changing document behavior.
- Maintain the internal docs structure under numbered folders.
- Validate each live agent step with health checks and output validators before state transitions.

## Validation Plan
- `bash ops/scripts/validate-task.sh <task-file>`
- `bash ops/scripts/validate-output.sh <role> <output-file>`
- `bash ops/scripts/validate-docs.sh <task-file>`
- `bash ops/scripts/check-codex-health.sh <task-file>`
- targeted live runs via `bash ops/scripts/run-agent.sh <role> <task-file>`
