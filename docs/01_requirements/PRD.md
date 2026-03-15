# PRD

## Project
- Name: Instagram Feed Creator Multi-Agent Starter Pack

## Problem
- Teams need a repeatable way to run `pm-orchestrator`, `implementer`, and `reviewer` through a file-backed workflow without relying on manual chat coordination.
- Documentation, implementation, and review evidence should stay inside the repository so the starter pack can be tested end-to-end without external vault dependencies.

## Goals
- Run `pm-orchestrator -> implementer -> reviewer` as a live Codex workflow using task files, handoffs, and review reports.
- Keep project documents under `docs/01_requirements`, `docs/02_design`, `docs/03_development`, and `docs/04_evaluation`.
- Make health checks, output validation, and task transitions scriptable and deterministic.

## Scope
- In scope: task schema, runner scripts, validator scripts, internal docs structure, live smoke verification.
- Out of scope: external vault sync, additional roles beyond the first three core agents, deployment workflows.

## References
- [[FEATURE_SPEC]]
- [[INTERFACES]]
