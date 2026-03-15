# Codex-Craft-Ops

`tmux + Codex` 기반 멀티에이전트 운영 스타터팩입니다.

현재 기본 범위는 아래 3개 역할입니다.

- `pm-orchestrator`
- `implementer`
- `reviewer`

이 저장소는 작업 큐, handoff, review 흐름을 파일 기반으로 운영할 수 있게 만드는 것을 목표로 합니다.

## 포함 내용

- 역할 정의: `ops/agents/`
- 역할 프롬프트: `ops/prompts/`
- 실행 및 상태 전이 스크립트: `ops/scripts/`
- 작업 템플릿과 상태 디렉터리: `tasks/`
- handoff 및 review 템플릿: `handoffs/templates/`
- 실행 상태, 로그, 아티팩트, 리포트: `state/`, `logs/`, `artifacts/`, `reports/`
- 번호 기반 문서 구조: `docs/01_requirements`, `docs/02_design`, `docs/03_development`, `docs/04_evaluation`

## 기본 흐름

1. PM이 작업 파일을 만들거나 갱신합니다.
2. `pm-orchestrator`가 작업을 배정하고 PM handoff를 남깁니다.
3. `implementer`가 `allowed_paths` 안에서 구현하고 `docs/` 내부 문서를 갱신합니다.
4. `reviewer`가 결과를 검증하고 `pass`, `needs_fix`, `blocked` 중 하나로 판정합니다.
5. `advance-task.sh`가 작업 상태를 `queued`, `assigned`, `running`, `needs_review`, `done`, `blocked`로 전이합니다.

## 주요 스크립트

- `bash ops/scripts/start-session.sh <session-name>`
- `bash ops/scripts/pick-task.sh`
- `bash ops/scripts/check-codex-health.sh <task-file>`
- `bash ops/scripts/run-agent.sh <role> <task-file>`
- `bash ops/scripts/advance-task.sh <role> <task-file> <output-file>`
- `bash ops/scripts/validate-task.sh <task-file>`
- `bash ops/scripts/validate-output.sh <role> <output-file>`
- `bash ops/scripts/validate-docs.sh <task-file>`
- `bash ops/scripts/status-board.sh`

## 문서 구조

프로젝트 문서는 저장소 내부에서 관리합니다.

- `docs/01_requirements`
- `docs/02_design`
- `docs/03_development`
- `docs/04_evaluation`

문서형 작업과 혼합 작업은 위 단계 간 링크 정합성을 유지해야 합니다.

## 현재 상태

- 내부 `docs/` 기반 운영 모드 적용
- live run에서 remote MCP 기본 비활성화
- `TASK-120` 기준 internal live smoke 검증 완료

## 다음 범위

- mixed task 예제 확장
- status board 가시성 개선
- `repairer` 추가 후 `qa-auditor`, `release-guard` 확장
