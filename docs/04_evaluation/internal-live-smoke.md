# Internal Live Smoke

## Goal
- Provide a repo-internal smoke path for live Codex execution before external vault writing is enabled.
- Validate that `pm-orchestrator`, `implementer`, and `reviewer` can each emit validator-compliant output for the same task.
- Keep the smoke artifact inside this repository at `docs/04_evaluation/internal-live-smoke.md`.

## Active Task Contract
- Task ID: `TASK-120`
- Active task file after PM advance: `tasks/doing/TASK-120-internal-live-smoke.yaml`
- Allowed implementation path for this task: `docs/`
- External paths required: none

## Smoke Sequence
1. Run the external preflight health check against `tasks/doing/TASK-120-internal-live-smoke.yaml`.
2. Run `pm-orchestrator` and confirm the output matches the required handoff template.
3. Run `implementer` and confirm the output matches the required implementation handoff template.
4. Run `reviewer` and confirm the output matches the required review report template.
5. Verify that the resulting task evidence stays inside repository paths plus standard runtime output paths such as `handoffs/`, `reports/`, `logs/`, `state/`, and `artifacts/`.

## Validation Commands
- `bash ops/scripts/validate-task.sh tasks/doing/TASK-120-internal-live-smoke.yaml`
- `bash ops/scripts/validate-output.sh pm-orchestrator handoffs/TASK-120-pm-orchestrator.md`
- `bash ops/scripts/validate-output.sh implementer handoffs/TASK-120-implementation-handoff.md`
- `bash ops/scripts/validate-output.sh reviewer reports/TASK-120-review-report.md`

## Evidence Matrix
- PM evidence: `handoffs/TASK-120-pm-orchestrator.md` already proves the task can move from PM to implementer with a validator-compliant handoff.
- Implementer evidence: `handoffs/TASK-120-implementation-handoff.md` must describe only repository-internal changes and should list `docs/04_evaluation/internal-live-smoke.md` under `Docs Updated`.
- Reviewer evidence: `reports/TASK-120-review-report.md` must confirm validator success and explicitly note that the smoke flow did not depend on out-of-repo document paths.
- Runtime evidence: `logs/`, `state/`, and `artifacts/` may be populated by the runner, but no acceptance step should require an external document root.

## Expected Runtime Outputs
- `handoffs/TASK-120-pm-orchestrator.md`
- `handoffs/TASK-120-implementation-handoff.md`
- `reports/TASK-120-review-report.md`
- related runtime traces under `logs/`, `state/`, and `artifacts/`

## Validator Checks
- PM output includes `Status`, `Next Owner`, `Task Decision`, `Breakdown`, `Acceptance Criteria`, `Document Deliverables`, `External Paths`, and `Risks or Blockers`.
- Implementer output includes `Status`, `Next Owner`, `Summary of Changes`, `Files Touched`, `Docs Updated`, `Validation Attempted`, `Risks`, and `Open Questions`.
- Reviewer output includes `Review Status`, `Next Owner`, `Checks Run`, `Document Checks`, `Findings`, `Missing Coverage`, and `Required Fixes`.
- The reviewer confirms that no step in this smoke flow depends on out-of-repo document paths.

## Constraints
- Do not write outside this repository for this smoke task.
- Do not treat missing external documentation as a failure for this smoke task.
- Treat `check-codex-health.sh` failures as environment blockers that must go back to `pm-orchestrator`.
- Run health checks and validators against the current task path, not a stale pre-move path.
- Do not run `validate-docs.sh` as a required gate for this task because `TASK-120` is an internal-only `implementation` task with no external document contract.

## Reviewer Notes
- This smoke task is the temporary exception to the normal document-inclusive flow.
- Acceptance is satisfied when the live run proves internal-only execution, produces validator-compliant outputs for all three roles, and leaves all required evidence under repository paths.
