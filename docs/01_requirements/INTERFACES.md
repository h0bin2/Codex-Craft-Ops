# Interfaces

## Inputs
- YAML task files in `tasks/queue/`, `tasks/doing/`, and `tasks/done/`
- Agent definitions in `ops/agents/` and role prompts in `ops/prompts/`
- Existing handoffs and review reports in `handoffs/` and `reports/`

## Outputs
- PM handoff markdown in `handoffs/`
- Implementer handoff markdown in `handoffs/`
- Reviewer report markdown in `reports/`
- Role state in `state/*.env`
- Runtime logs in `logs/`
- Project documents in numbered `docs/` folders

## Constraints
- Live runs must stay inside repository write scope.
- Documentation is managed in-repo rather than in an external vault.
- Remote MCP integrations are disabled by default to avoid authentication-related hangs during live execution.

## References
- [[PRD]]
- [[FEATURE_SPEC]]
