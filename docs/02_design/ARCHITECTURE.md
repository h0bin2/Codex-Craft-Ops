# Architecture

## Requirements Input
- Source: [[PRD]]
- Source: [[FEATURE_SPEC]]
- Source: [[INTERFACES]]

## Solution Overview
- `tmux` and shell scripts act as the operational layer.
- Task files define the contract for PM, implementer, and reviewer.
- `run-agent.sh` assembles role definition, role prompt, task file, template, and latest context into a single Codex prompt.
- `advance-task.sh` applies the state machine after validator-compliant outputs are produced.
- `docs/` is the single document root and is validated through numbered stage folders.

## Data Flow
- `tasks/queue` -> `pm-orchestrator` -> `handoffs/TASK-*-pm-orchestrator.md`
- `tasks/doing` -> `implementer` -> `handoffs/TASK-*-implementation-handoff.md`
- `tasks/doing` -> `reviewer` -> `reports/TASK-*-review-report.md`
- Successful outputs update `state/*.env`, task ownership, and final task directory placement.

## Risks
- Output format drift can break automatic state transitions.
- Long-running Codex sessions can time out before final artifact emission.
- External integrations such as remote MCP can destabilize otherwise valid local task runs.
