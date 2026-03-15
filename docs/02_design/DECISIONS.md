# Decisions

## Context
- Link to [[ARCHITECTURE]]

## Decisions
- Keep documentation inside repository `docs/` instead of writing into an external vault.
- Enforce numbered stage folders: `01_requirements`, `02_design`, `03_development`, `04_evaluation`.
- Disable remote MCP servers by default during live Codex execution.
- Feed role-specific output templates directly into the live runner prompt to reduce output-format drift.

## Consequences
- Task schema and validators must treat `doc_project_root` as an in-repo path.
- Bootstrap and validation scripts need to work against `docs/`.
- Future external document publishing, if needed, should be treated as a separate synchronization layer rather than the primary authoring path.
