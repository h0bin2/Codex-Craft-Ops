# Document-Inclusive MVP Workflow

## Goal
- Every feature task includes repository-internal documentation work.
- Project documents live under `docs/`.
- The docs root always keeps `01_requirements`, `02_design`, `03_development`, `04_evaluation`.

## Canonical Commands
- `bash ops/scripts/validate-task.sh <task-file>`
- `bash ops/scripts/validate-output.sh <role> <output-file>`
- `bash ops/scripts/validate-docs.sh <task-file>`
- `bash ops/scripts/check-codex-health.sh <task-file>`
- `bash ops/scripts/bootstrap-doc-project.sh docs`
- `bash ops/scripts/check-codex-health.sh tasks/doing/TASK-120-internal-live-smoke.yaml`

## Recommended Test Loop
Internal-only live smoke:
1. Before PM advance, copy the smoke task into `tasks/queue/` or start from `tasks/examples/`.
2. After PM advance, use the active file at `tasks/doing/TASK-120-internal-live-smoke.yaml`.
3. Run `bash ops/scripts/check-codex-health.sh tasks/doing/TASK-120-internal-live-smoke.yaml`.
4. If health check passes, run `bash ops/scripts/run-agent.sh <role> tasks/doing/TASK-120-internal-live-smoke.yaml`.

Document-inclusive flow:
1. Copy a sample task from `tasks/examples/` into `tasks/queue/`.
2. Bootstrap the repo-internal docs root before running documentation or mixed tasks.
3. Run `bash ops/scripts/pick-task.sh` to assign the next task.
4. Run `bash ops/scripts/check-codex-health.sh <task-file>` before each live agent execution.
5. Run `bash ops/scripts/run-agent.sh <role> <task-file>` for PM, implementer, and reviewer.
6. Advance task state with `bash ops/scripts/advance-task.sh <role> <task-file> <output-file>`.
7. Re-run `validate-task.sh`, `validate-output.sh`, and `validate-docs.sh` when debugging failures.

## Review Gates
- Task schema is valid.
- Handoff or review report format is valid.
- Required numbered stage folders exist under `docs/`.
- Required baseline documents exist.
- `doc_outputs` files exist.
- Design docs reference requirements.
- Development docs reference requirements and design.
- Evaluation docs reference development artifacts.
- Health check failures are treated as environment blockers and should produce a blocked artifact for `pm-orchestrator`.
