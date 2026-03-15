# tmux + Codex Multi-Agent Ops Draft

## Sub-Agent Directory
| Name | Description | Primary Role | Main Output |
| --- | --- | --- | --- |
| `pm-orchestrator` | 작업 우선순위를 정하고 각 에이전트에 일을 분배하는 상위 제어 에이전트 | 작업 분해, 할당, 재시도 판단, 승인 요청 | `handoffs/*.md`, `state/assignments.json` |
| `implementer` | 실제 기능 구현을 담당하는 기본 작업 에이전트 | 코드 수정, 테스트 대상 기능 구현 | `artifacts/*.diff`, 작업 브랜치 변경사항 |
| `reviewer` | 구현 결과를 검증하고 회귀 위험을 점검하는 에이전트 | 테스트 실행, 코드 리뷰, 실패 원인 정리 | `reports/review-*.md` |
| `repairer` | 실패 로그를 기반으로 빠르게 수정 루프를 돌리는 복구 에이전트 | lint/test/build 실패 수정, flaky 이슈 재시도 | `reports/repair-*.md` |
| `qa-auditor` | 시나리오 기준으로 사용자 관점의 품질을 확인하는 에이전트 | 수동 점검 체크리스트, e2e 결과 해석 | `reports/qa-*.md` |
| `release-guard` | merge, deploy 직전 승인 게이트를 담당하는 에이전트 | 최종 체크, 배포 조건 확인, 릴리즈 판단 | `reports/release-*.md` |

## Overview
이 구조의 핵심은 `tmux`가 에이전트를 실행하고 관찰하는 운영 레이어이고, 실제 동작은 `PM + 공통 agent-runner + validation harness`가 담당한다는 점입니다. 각 서브에이전트는 별도 프로그램이 아니라 같은 러너에 역할별 설정을 주는 방식으로 구현합니다.

## Core Components
- `ops/agents/`: 역할 정의서. `name`, `description`, 책임, 금지사항, handoff 규칙 관리
- `ops/supervisor/`: `tmux` 세션 생성, pane 재시작, heartbeat 수집
- `ops/prompts/`: 역할별 시스템 프롬프트. 공통 runner가 이 파일을 읽어 역할을 고정
- `ops/scripts/`: 세션 시작, task 선택, agent 실행, 상태 전이, 상태 보드, task/output/doc validator
- `ops/skills/`: 역할별 고정 규칙, 금지사항, 완료 조건
- `tasks/templates/`: 작업 큐 템플릿
- `tasks/queue/`: 아직 시작하지 않은 작업
- `tasks/doing/`: 현재 에이전트가 수행 중인 작업
- `tasks/done/`: 완료된 작업과 결과 요약
- `handoffs/templates/`: 구현 handoff, review report 템플릿
- `state/`: 에이전트 상태, 작업 할당, 마지막 heartbeat
- `logs/`: pane 로그, 검증 로그, 오류 로그
- `artifacts/`: diff, 스크린샷, 테스트 결과, handoff

예상 구조:

```text
ops/
  agents/
  scripts/
  supervisor/
  prompts/
  skills/
tasks/
  templates/
  queue/
  doing/
  done/
handoffs/
  templates/
state/
logs/
artifacts/
reports/
```

## tmux Layout
- `window: pm` - `pm-orchestrator` 전용
- `window: workers` - `implementer`, `repairer`
- `window: review` - `reviewer`, `qa-auditor`
- `window: release` - `release-guard`
- `window: monitor` - 상태 보드, 로그 tail, 실패 알림

각 pane은 하나의 역할만 담당하고, 작업마다 별도 Git worktree를 사용합니다. 충돌을 줄이기 위해 한 pane이 동시에 두 작업을 잡지 않도록 합니다.

## Task Contract
각 작업 파일은 최소한 아래 필드를 가져야 합니다.

```yaml
id: TASK-001
title: Add Instagram feed draft generator
summary: >
  Build a first draft generator for Instagram feed content.
task_type: mixed
owner: implementer
priority: high
dependencies: []
allowed_paths:
  - src/
  - tests/
context_files:
  - docs/spec.md
acceptance:
  - npm test
  - npm run lint
  - draft output renders without runtime error
doc_project_root: docs
doc_stage: design
doc_outputs:
  - 02_design/ARCHITECTURE.md
  - 02_design/DECISIONS.md
handoff_to: reviewer
status: queued
```

문서형 task 기본 규칙:

- 모든 기능 작업은 `task_type: mixed`를 기본으로 사용한다.
- 문서만 다루는 작업은 `task_type: documentation`을 사용한다.
- 문서는 저장소 내부 `docs/` 아래에 저장한다.
- 각 프로젝트는 `01_requirements`, `02_design`, `03_development`, `04_evaluation` 4단계 폴더를 유지한다.
- 설계 문서는 요구사항을, 개발 문서는 요구사항과 설계를, 평가는 개발 문서를 링크해야 한다.

## State Machine
- `queued`: 작업 대기
- `assigned`: PM이 에이전트에 할당
- `running`: 에이전트가 실행 중
- `blocked`: 권한, 의존성, 요구사항 문제로 중단
- `needs_review`: 구현 완료, 리뷰 대기
- `done`: 완료

리뷰 결과는 task status와 별개로 아래 값만 사용합니다.

- `pass`
- `needs_fix`
- `blocked`

## Execution Flow
1. `pm-orchestrator`가 `tasks/queue/`에서 작업을 읽고 담당 에이전트를 정합니다.
2. `supervisor`가 새 worktree를 만들고 해당 role pane에서 `agent-runner`를 실행합니다.
3. `implementer`가 코드를 수정하고 `artifacts/`와 `handoffs/`에 결과를 남깁니다.
4. `reviewer`가 `lint`, `test`, `build`와 리뷰 체크를 수행합니다.
5. 실패하면 `repairer`가 로그를 받아 수정 루프를 돌립니다.
6. 최종 승인 조건을 만족하면 `release-guard`가 merge 또는 deploy 가능 상태로 올립니다.

## Harness Requirements
- 입력 계약: 작업 목표, 수정 가능 경로, 금지 사항, 완료 조건 고정
- 실행 계약: sandbox, 승인 정책, 허용 도구를 역할별로 분리. remote MCP는 기본적으로 끈 상태로 실행
- 출력 계약: 모든 에이전트가 같은 형식의 handoff와 report를 남기도록 강제
- 검증 계약: `lint`, `test`, `build`, 필요 시 e2e까지 자동 실행. 문서 task는 `validate-docs.sh`로 구조와 링크 정합성 검증
- 재시도 정책: 실패 로그 첨부 후 제한된 횟수만 재시도
- 관찰성: pane별 로그, heartbeat, 최근 실패 원인, 마지막 성공 시각 저장

## First Implementation Scope
처음에는 아래 3개 역할만 먼저 구현하는 것이 안전합니다.

- `pm-orchestrator`
- `implementer`
- `reviewer`

그 다음 순서로 확장합니다.

1. `repairer` 추가
2. worktree 자동 생성
3. 상태 파일과 heartbeat 추가
4. `tmux` supervisor 자동 복구
5. `qa-auditor`, `release-guard` 추가

## Practical Rule
에이전트 수를 늘리기 전에 먼저 공통 러너와 하네스를 안정화해야 합니다. 운영 품질은 pane 개수보다 `작업 계약`, `검증 자동화`, `로그`, `재시도 규칙`에서 결정됩니다.

## Current MVP Additions
- `validate-task.sh`: task schema 검사
- `validate-output.sh`: PM/implementer/reviewer 출력 포맷 검사
- `validate-docs.sh`: 저장소 내부 문서 구조와 링크 정합성 검사
- `check-codex-health.sh`: live Codex 실행 전 런타임 및 외부 문서 경로 상태 검사
- `bootstrap-doc-project.sh`: 저장소 내부 문서 뼈대 생성
