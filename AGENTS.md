# Repository Guidelines

## Purpose
이 저장소는 `tmux + Codex` 기반 멀티에이전트 운영 스타터팩을 정리하는 곳입니다. 현재 기본 범위는 `pm-orchestrator`, `implementer`, `reviewer` 3개 역할을 중심으로, 작업 큐, handoff, 리뷰 흐름을 파일 기반으로 운영할 수 있게 만드는 것입니다. 모든 기능 작업은 코드 변경과 함께 저장소 내부 `docs/` 문서 작성 task를 포함해야 합니다.

## Starter Pack Structure
- `ops/agents/`: 역할 정의서. 각 에이전트의 책임, 금지사항, handoff 규칙 관리
- `ops/prompts/`: 역할별 시스템 프롬프트
- `ops/scripts/`: `tmux` 세션 생성, task 이동, role별 Codex 실행, 상태 보드, task/output/doc validator, Codex health check
- `tasks/templates/`: 작업 큐 템플릿
- `tasks/queue/`, `tasks/doing/`, `tasks/done/`: 작업 상태별 디렉터리
- `handoffs/templates/`: 구현 handoff, review report 템플릿
- `state/`, `logs/`, `artifacts/`, `reports/`: 운영 상태와 결과물 저장
- `docs/`: 번호 문서 폴더와 운영 설계 문서
- 프로젝트 문서는 저장소 내부 `docs/` 아래에 저장하며 `01_requirements`, `02_design`, `03_development`, `04_evaluation` 4단계 폴더를 항상 유지합니다.

## Core Agents
- `pm-orchestrator`: 작업 선택, 분해, 담당자 지정, blocker 관리. 제품 코드는 직접 수정하지 않음
- `implementer`: `allowed_paths` 안에서 기능 구현과 필요한 테스트 추가 수행, `doc_project_root` 안에서 프로젝트 문서 작성
- `reviewer`: `lint`, `test`, `build`와 acceptance criteria 기준으로 `pass`, `needs_fix`, `blocked` 판정, 문서 구조와 링크 정합성 검증

각 역할의 상세 규칙은 `ops/agents/`와 `ops/prompts/`를 함께 기준으로 삼습니다.

## Operating Flow
1. PM이 `tasks/templates/task-template.yaml`을 기준으로 작업 파일을 작성해 `tasks/queue/`에 둡니다.
2. `pm-orchestrator`가 작업을 배정하고, 구현 작업은 기본적으로 `implementer`에게 넘깁니다. 각 기능 작업에는 `docs/` 문서 산출물이 함께 정의되어야 합니다.
3. `implementer`는 작업 범위 안에서 코드와 문서를 변경한 뒤 `handoffs/templates/implementation-handoff.md` 형식으로 결과를 남깁니다.
4. `reviewer`는 `handoffs/templates/review-report.md` 형식으로 검증 결과를 기록하며, 문서 task나 mixed task는 `bash ops/scripts/validate-docs.sh <task-file>` 결과를 함께 확인합니다.
5. 통과 시 작업은 `done`, 수정 필요 시 implementer로 되돌리고, 환경 문제는 `blocked`로 처리합니다.
6. live Codex 실행 전에는 `bash ops/scripts/check-codex-health.sh <task-file>`를 통과해야 하며, 실패 시 task는 즉시 `blocked`로 전환하고 `pm-orchestrator`로 되돌립니다.

## Required Conventions
- 작업 파일은 YAML을 사용하며 `id`, `task_type`, `owner`, `priority`, `allowed_paths`, `acceptance`, `handoff_to`, `status`를 반드시 포함합니다.
- `documentation`, `mixed` task는 `doc_project_root`, `doc_stage`, `doc_outputs`를 반드시 포함합니다.
- handoff와 review report는 템플릿 형식을 유지하고 마지막 상태와 다음 owner를 명시합니다.
- 상태값은 `queued`, `assigned`, `running`, `blocked`, `needs_review`, `done`만 사용합니다.
- 리뷰 결과는 `pass`, `needs_fix`, `blocked`만 사용합니다.
- 역할명은 `pm-orchestrator`, `implementer`, `reviewer`로 고정합니다.
- 문서 단계는 `requirements`, `design`, `development`, `evaluation`만 사용합니다.

## Working Rules
- 범위 밖 리팩터링은 하지 않습니다.
- acceptance criteria 없는 작업은 진행하지 않습니다.
- destructive action은 승인 없이 수행하지 않습니다.
- 새 운영 규칙을 추가하면 `AGENTS.md`, 관련 프롬프트, 템플릿의 용어를 함께 맞춥니다.
- 문서는 단계별 폴더 구조를 유지하고 설계 문서는 요구사항을, 개발 문서는 요구사항과 설계를, 평가는 개발 결과를 참조해야 합니다.
- remote MCP는 기본적으로 비활성화한 상태로 live runner를 사용합니다.
- 스크립트는 `bash ops/scripts/start-session.sh`, `pick-task.sh`, `run-agent.sh`, `advance-task.sh`, `status-board.sh`, `validate-task.sh`, `validate-output.sh`, `validate-docs.sh`, `check-codex-health.sh`, `bootstrap-doc-project.sh` 흐름을 기준으로 사용합니다.

## Next Expansion
다음 확장 후보는 `repairer`, `qa-auditor`, `release-guard`입니다. 다만 먼저 공통 runner, 작업 계약, 검증 자동화가 안정화된 뒤에 추가하는 것을 기본 원칙으로 합니다.
