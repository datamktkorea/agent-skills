# SDLC 스킬셋 TODO

본 문서는 AI Native SDLC 스킬셋 설계 대화에서 "추후 처리"로 합의된 항목을 기록한다. 각 항목은 결정이 필요한 시점에 다시 꺼내어 다듬는다.

## 보류 항목

### A4. `write-meeting-notes`에 액션 아이템 → Requests 푸시 게이트 추가

회의록 작성 종료 시점에 액션 아이템을 Requests DB로 일괄 등록할지 묻는 인터랙션을 넣는다. 현재는 회의록이 Meeting DB에서 끝나고 Requests로 흘러갈 길이 없다.

판단 필요: 자동 푸시 vs 인간 승인 게이트, 노이즈 차단 기준.

### B6. Repo Steering 운영 정책

`CLAUDE.md` / `tech.md` / `structure.md`의 위치, 갱신 주기, 책임자, 드리프트 검증 방식을 정한다. 그 후 `update-repo-steering` 스킬을 신설한다.

판단 필요: 각 타깃 레포 단위인가 datamktkorea 공통 일부 + 레포 고유 일부 분리인가, 갱신을 PR 단위 강제로 할 것인가.

<!-- C8 폐기 (2026-05-06): 인간 트리거 스킬 `record-spec-pr`(PLAN.md 1순위)이 GHA 역기록 트랙을 대체. Spec→PR 추적은 PR-URL-on-Notion 단방향만 유지. -->

### C9. Human 라우팅 게이트(②) 구현 위치

요청이 이니셔티브 트랙으로 갈지 Spec 트랙으로 갈지 인간이 판단하는 단계의 구현 형태를 정한다.

판단 필요: `capture-request` 종료 시 한 번 묻는 인터랙션인가, Requests DB 속성("track: 미정/initiative/spec")으로 비동기 처리인가.

### D10. 외부 제출물 PRD 트랙

수탁/공공 프로젝트에서 *외부 제출용* PRD, 제안서, RFP 응답이 *필요해지는 시점*에 별도 스킬을 신설한다. 내부 SSOT는 이미 `write-project-steering`의 contract/public 분기로 커버됨 — D10은 그 SSOT를 *외부 제출 형식*(고객사 양식, 나라장터 양식, 인쇄용 PDF)으로 렌더링하는 트랙.

판단 필요: 트리거 시점(첫 수탁 안건 발생 시), 명칭(`render-customer-deliverable`, `export-rfp-response` 등). 보존 자산: `plugins/dmk-sdlc/skills/write-project-steering/references/legacy/PRD_TEMPLATE.md`.

## 운영 규칙

- 결정이 끝난 항목은 이 파일에서 제거하고 해당 스킬에 반영한다.
- 새로 합의된 보류 항목은 본 파일에 추가한다.
- 항목 간 의존성이 있으면(예: B6 → start-spec-implementation) 본문에 명시한다.
