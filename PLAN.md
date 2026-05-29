# SDLC 스킬셋 작업 순서

본 문서는 AI Native SDLC 스킬셋 구축의 작업 순서를 기록한다. 보류 항목 상세는 `TODO.md` 참고.

## 데이터 모델 (확정)

- Initiative ↔ Project = 1:N
- 3단 고정 계층: Initiative(2~6주 베팅) → Request(분해 단위) → Spec(실행 단위)
- Initiative는 재귀 분해하지 않음. 비대해지면 Request로 분해
- 용어: 영어 Initiative, 한국어 이니셔티브 (이전 "Trigger/트리거"에서 마이그레이션 완료)

## 우선순위

<!-- 완료 (2026-05-06): write-project-steering 본문 (A) 정렬 — SKILL.md 재작성 + product/contract/public 3종 references 추가 + 기존 PRD_TEMPLATE은 references/legacy/로 격리 -->
<!-- 완료 (2026-05-06): start-spec-implementation 신설 — Phase 2 진입 스킬 + 연쇄 정합성(write-sdlc-spec 4 templates 확장 / decompose-sdlc-initiative 관계키 rename / notion-api schema 갱신) -->

### 1순위. `record-spec-pr` 신설

Phase 2 종료 보조. Spec URL + PR URL 입력 → Spec 페이지 `PR URL` 속성에 기록 + `상태=완료` 전이. start-spec-implementation의 짝.

근거: PR-Notion 역기록을 GHA(C8) 없이 인간 트리거 스킬로 처리. C8 자동화 트랙 자체가 불필요해질 수 있음.

### 2순위. `review-initiative` 신설

Initiative 종료 판정 보조. Initiative ID 입력 → 하위 Request/Spec 상태 집계 + 지표 vs 목표 비교 + 후속 Initiative 후보 제안. 종료 결정은 인간이.

## 보류 (TODO.md)

- A4. `write-meeting-notes` 액션 아이템 → Requests 푸시 게이트
- B6. Repo Steering(`CLAUDE.md`/`tech.md`/`structure.md`) 운영 정책 + `update-repo-steering` 스킬
- C9. Human 라우팅 게이트(②) 구현 위치
- D10. 외부 제출물 PRD 트랙(수탁/공공 RFP 응답) — 현재 `references/legacy/PRD_TEMPLATE.md` 보존 자산 활용 가능

## 운영 규칙

- 1~3순위 중 한 항목을 시작할 때마다 사용자에게 확인.
- 스킬 신설/수정 후 본 문서의 해당 항목을 제거하고 완료 일자만 코멘트로 남긴다.
