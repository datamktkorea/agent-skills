---
category: feature-change
handles_request_type: 기능 변경
section_count: 9
---

# Template: 기능 변경 (Feature Change Spec)

A feature-change is comparative (AS-IS vs TO-BE) with migration concerns. This is the least publicly-documented Spec category, so the template is the longest. Each section defends against a specific migration failure mode. Modeled on Stripe API versioning, Shopify deprecation, React RFCs, SemVer breaking criteria, LaunchDarkly rollout patterns, and Chesterton's Fence principle.

**Grounding mandate:** Sections 2, 3, 4, 5 MUST cite real code (file:line) and git history (commit hashes). Changing behavior without understanding why the current behavior exists is the #1 cause of regressions.

> **Note on examples.** All Good/Bad examples below are drawn from a single illustrative project (a book-publishing agent called BINGBONG: roles like `publisher`, features like TOC generation, file paths like `src/features/publisher/...`). They exist to show shape, not content. When running the skill, substitute actual identifiers from the user's Request, Projects DB, and `code.json`. Never reproduce these example identifiers in the user-facing prompt or the Spec body.

## Sections (in order)

1. 변경 한 줄 (Change Line)
2. Chesterton's Fence: 기존 동작의 존재 이유 (Why AS-IS Exists)
3. AS-IS vs TO-BE (Before / After with examples)
4. 영향 받는 호출자 (Affected Callers & Users)
5. Migration 경로 (Migration Path)
6. Breaking 분류 및 롤아웃 (Classification & Rollout)
7. 롤백 플랜 (Rollback Plan)
8. 검증 커맨드 (Verification: FAIL→PASS / KEEP-PASSING / MIGRATED)
9. 관련 Steering 섹션 (Steering Sections to Read)

## Section 1: 변경 한 줄

**이 섹션의 역할:** 무엇을 바꾸고 왜 지금 바꾸는지를 한 문장으로 커밋.

**Ask (stem):**

> "다음 형식으로 써주세요:
>
> **[대상]**의 **[AS-IS 동작]**을 **[TO-BE 동작]**으로 변경한다.
> 이유: **[AS-IS가 해결하던 문제가 더 이상 유효하지 않거나, 새 문제가 우선한다]**."

**Good example:**

> publisher 책 상세의 TOC 저장 동작을 '생성 완료 시 자동 저장'에서 '사용자 명시적 Save 클릭 시 저장'으로 변경한다.
> 이유: 자동 저장이 사용자가 편집하기 전의 AI 결과물을 덮어써서 데이터 손실 사례 발생 (Request에 명시된 3건).

**Bad example:**

> TOC 저장 개선.

**Self-check:**

- [ ] AS-IS와 TO-BE가 모두 구체적인가 (한 문장씩 관찰 가능한 동작)
- [ ] "왜 지금 바꾸나"가 설명됐나 (현 상태의 문제 or 새 요구)
- [ ] 2~3 문장 이내인가

**Pushback probes:**

- "'개선'은 방향만 있고 동작이 없어요. 지금 어떻게 동작하고, 바뀌면 어떻게 동작하나요?"
- "왜 지금 바꾸나요? 이 AS-IS는 누군가 의도적으로 만든 거예요. 바꿀 만한 이유가 있어야 해요 (Section 2에서 자세히)."

**Length:** 2~3 문장.

## Section 2: Chesterton's Fence: 기존 동작의 존재 이유

**이 섹션의 역할:** 이 템플릿의 가장 중요한 섹션. 기존 동작을 왜 만들었는지 모르고 바꾸면 regression이 난다. git history + 과거 관련 PR/문서 citation 필수.

**Ask (stem):**

> "다음을 써주세요:
>
> **AS-IS 도입 시점:** commit/PR (hash 또는 URL)
> **원래 해결하려던 문제:** 당시 어떤 사용자 고통 또는 기술적 이슈를 풀기 위해 도입됐는가
> **그 문제는 여전히 유효한가:** [유효 / 무효] because [근거]
> **유효하다면 TO-BE가 어떻게 같은 문제를 푸나:** [설명]"

**Good example:**

> **AS-IS 도입:** PR #87 (2025-09-12), commit `a81351e`. 메시지: "🐛 fix: prevent TOC loss on tab close".
> **원래 문제:** 사용자가 TOC 편집 중 브라우저 탭을 닫으면 모든 편집 내용이 소실되는 사례 보고 (N=14). 당시 draft 저장 인프라가 없어 즉시 저장이 유일한 해결책.
> **여전히 유효한가:** 유효. 탭 닫기로 인한 손실 문제는 아직 있음.
> **TO-BE가 어떻게 해결:** 2025-12 이후 localStorage-based draft 저장 인프라가 도입됨 (`src/lib/draft-storage.ts`). 명시적 Save로 옮겨도 탭 닫기 시 draft는 복원됨.

**Bad example:**

> 왜 이렇게 되어 있는지 모르겠다.

**Self-check:**

- [ ] 원 commit/PR을 citation했나
- [ ] 원래 해결하던 문제가 기술됐나 (추측 아닌 실제 과거 근거)
- [ ] 그 문제가 여전히 유효한지 판단했나
- [ ] 유효하다면 TO-BE가 어떻게 같은 문제를 푸는지 설명됐나

**Pushback probes:**

- "'모르겠다'면 이 변경을 시작할 수 없어요. git log/blame으로 원 commit을 찾아보거나, 조사 후 다시 작성해주세요. 모르고 바꾸면 regression 확정이에요."
- "원 commit을 찾았는데 문제가 여전히 유효하네요. TO-BE가 어떻게 같은 문제를 푸는지 설명 없이는 이 변경을 승인할 수 없어요."

**Length:** 4~8줄.

**Grounding (강제):** git log/blame 결과 + 원 PR 링크. Implementation Map에 git 정보 포함되어 있어야 함.

## Section 3: AS-IS vs TO-BE (Before / After)

**이 섹션의 역할:** Stripe upgrade notes 패턴. 코드/UI/API 예시로 차이를 눈으로 확인.

**Ask (stem):**

> "다음을 써주세요:
>
> **AS-IS:** 현재 코드/UI/API 예시 (실제 파일:줄 인용)
> **TO-BE:** 변경 후 예시
> **관찰 가능한 차이:** 사용자/호출자 관점 변화"

**Good example:**

```
AS-IS:
  // src/features/publisher/components/toc-panel.tsx:L210
  useEffect(() => {
    if (tocGenerated) {
      saveToc(toc)  // 자동 저장
    }
  }, [tocGenerated, toc])

TO-BE:
  // src/features/publisher/components/toc-panel.tsx:L210
  <Button onClick={handleSave} disabled={!isDirty}>저장</Button>
  // 자동 저장 useEffect 제거

관찰 가능한 차이:
  - 사용자: 생성 완료 후 "저장" 버튼 클릭해야 저장됨. 미클릭 상태에서 탭 닫기 → localStorage draft로 복원.
  - 호출자: `saveToc` 호출 경로가 `useEffect`에서 `onClick`으로 이동. hook chain 변경 없음.
```

**Bad example:**

> 저장 방식이 바뀐다.

**Self-check:**

- [ ] AS-IS 코드가 실제 파일:줄 인용인가 (Implementation Map 기반)
- [ ] TO-BE 코드가 작동할 형태로 그려졌나
- [ ] 사용자 관점 차이가 명시됐나
- [ ] 호출자 관점 차이가 명시됐나 (API/계약 변경이면)

**Pushback probes:**

- "AS-IS 코드가 인용이 아니에요. Implementation Map의 실제 코드를 복사해주세요."
- "사용자 관점이 없어요. 사용자가 이 변경을 어떻게 경험하나요? 버튼이 생기나요? 뭐가 사라지나요?"

**Length:** 코드 스니펫 2개 + 차이 설명 2~4줄.

**Grounding:** Implementation Map의 진입점 파일 verbatim.

## Section 4: 영향 받는 호출자 / 사용자

**이 섹션의 역할:** Migration surface area. Shopify가 deprecation 노티 낼 때 하는 impact report.

**Ask (stem):**

> "두 가지를 써주세요:
>
> **코드 호출자:** AS-IS에 의존하는 파일:줄 전체 목록. grep 결과 기반.
>
> - 각 항목마다: 제거/수정/유지 중 무엇인가?
> - 영향 받는 테스트도 포함
>
> **사용자:** 역할 + 추정 수 + 변경 직후 경험"

**Good example:**

- **코드 호출자:**
  - `src/features/publisher/components/toc-panel.tsx:L210`: 자동 저장 useEffect (**제거 대상**)
  - `src/features/publisher/hooks/use-toc-auto-save.ts`: hook 전체 (**제거**)
  - `src/features/publisher/hooks/use-toc-auto-save.test.ts`: 관련 테스트 (**제거**)
  - `src/features/publisher/components/toc-panel.test.ts:L45-L80`: "auto saves on generation complete" 테스트 (**수정 → dirty state test로 대체**)
  - `src/features/publisher/store.ts:L45`: `lastAutoSaveAt` 필드 (**유지: 분석용으로만 사용, 더 이상 업데이트 안 됨. 다음 스펙에서 제거 검토**)
- **사용자:**
  - 활성 publisher 전원 (~87명, 최근 30일 기준).
  - 변경 직후: 생성 완료 후 저장 버튼을 못 보면 "저장이 안 되나?" 혼동 예상. Tooltip으로 완화 (Section 5).

**Bad example:**

> 몇 군데 수정하면 됨.

**Self-check:**

- [ ] 파일:줄 단위로 열거했나
- [ ] 각 호출자에 대해 제거/수정/유지 명시했나
- [ ] 테스트 영향이 포함됐나
- [ ] 사용자 수가 숫자(추정이라도)로 있나
- [ ] 변경 직후 사용자 경험이 기술됐나

**Pushback probes:**

- "grep 결과가 이것뿐인가요? AS-IS 함수 이름이 `saveToc`인데, 다른 호출처가 정말 없나요? 다시 grep 해볼까요?"
- "호출자는 있는데 상태(제거/수정/유지)가 빠져 있어요. AI 에이전트가 어떻게 할지 모르면 각자 덧붙여 주세요."
- "테스트 영향이 없어요. AS-IS 동작을 검증하던 테스트가 하나도 없을 리 없어요. 다시 찾아보세요."

**Length:** 코드 호출자 4~12개, 사용자 2~4줄.

**Grounding (강제):** Implementation Map의 grep 결과 + 테스트 파일 목록.

## Section 5: Migration 경로

**이 섹션의 역할:** Stripe upgrade path 패턴. 자동/수동 구분은 중요: 자동화 가능하면 반드시 codemod/script, 아니면 사용자가 볼 UI.

**Ask (stem):**

> "다음을 써주세요:
>
> **데이터 migration:** 필요한가? 필요하면 어떻게? (script 경로 or SQL)
> **코드 migration:** 호출자 수정이 자동화 가능한가? (codemod) 아니면 수동 목록.
> **사용자 migration:** 사용자가 혼란 없이 새 UX에 적응하도록: tooltip/banner/공지.
> **이관 실패 시 fallback:** 무엇이 일어나는가?"

**Good example:**

- **데이터 migration:** 불필요. 저장된 TOC 구조 변경 없음.
- **코드 migration:**
  - Section 4의 '제거/수정' 항목 총 5곳: 수동. 유사 패턴이 아니라서 codemod 자동화 가치 낮음.
  - 단, `grep -rn "useAutoSave" src/` 로 누락 여부 최종 확인 필수.
- **사용자 migration:**
  - 최초 접속 시 1회 tooltip: "이제 저장 버튼을 눌러 TOC를 저장하세요. 버튼을 안 눌러도 페이지를 떠날 때까지 작성 중인 내용은 자동 복원됩니다."
  - tooltip은 localStorage 키 `toc-save-migration-seen` 로 개인별 1회만.
- **Fallback:** 사용자가 저장 버튼을 못 보면: 세션 종료 시 localStorage에 draft 자동 저장. 재접속 시 복원. 즉 이관 '실패'로 인한 데이터 손실 경로는 없음.

**Bad example:**

> 사용자가 알아서 적응할 것.

**Self-check:**

- [ ] 데이터 migration 필요 여부가 Y/N인가
- [ ] 코드 migration이 자동(codemod) / 수동(리스트) 중 명확한가
- [ ] 사용자 migration UI가 기술됐나
- [ ] Fallback이 기술됐나 (이관 '실패' 경로)
- [ ] 수동 migration이면 누락 확인 방법(grep 등)이 있나

**Pushback probes:**

- "'알아서'는 migration이 아니에요. 사용자가 처음 저장 버튼 없는 걸 보면 어떻게 반응할까요? 그걸 막을 UI가 있나요?"
- "코드 호출자가 5군데인데 자동화 안 한다면 이유가 뭔가요? 실수 없이 전부 찾을 방법은요?"

**Length:** 4~8줄.

## Section 6: Breaking 분류 및 롤아웃

**이 섹션의 역할:** SemVer operational definition + LaunchDarkly/Statsig rollout spec.

**Ask (stem):**

> "다음을 써주세요:
>
> **분류:** Breaking / Non-breaking / Deprecation
>
> - 근거: 호출자(코드 또는 사용자)가 무변경으로 계속 동작 가능한가?
> - 외부 API 계약 변경이 있는가? (있으면 Breaking)
>
> **롤아웃:**
>
> - Feature flag 이름
> - 단계별 %와 각 단계 기간
> - 각 단계에서 관찰할 metric
>
> **Kill criterion:**
>
> - 구체 metric + 임계치
> - 초과 시 즉시 rollback 또는 롤아웃 중단"

**Good example:**

- **분류:** Breaking (내부): 사용자 UI 변경. 외부 FastAPI 계약 변경 없음.
- **롤아웃:**
  - Feature flag: `toc_manual_save`
  - Stage 1: publisher 10% / 24시간 / metric: 저장 실패 toast 발생률
  - Stage 2: 50% / 48시간 / metric: 동일 + 사용자 문의 수
  - Stage 3: 100% / 지속 / flag 유지 기간 2주
- **Kill criterion:**
  - 저장 실패 toast 발생률이 baseline의 2배 초과 → 즉시 flag off
  - 사용자 문의 수가 24시간에 3건 초과 → 일시 정지, 원인 조사 후 재개 여부 결정

**Bad example:**

> 점진적으로 출시한다.

**Self-check:**

- [ ] Breaking/Non-breaking이 SemVer 기준(호출자 무변경 가능?)으로 판단됐나
- [ ] 외부 API 계약 영향이 명시됐나
- [ ] Rollout 단계가 %와 시간으로 구체적인가
- [ ] 각 단계에서 관찰할 metric이 명시됐나
- [ ] Kill criterion이 특정 metric + 숫자인가 (주관 판단 금지)

**Pushback probes:**

- "'점진적'은 롤아웃 계획이 아니에요. 언제 10%, 언제 50%, 언제 100%?"
- "Kill criterion이 '문제 생기면 rollback'이면 불명확해요. 어떤 metric이 어떤 숫자 넘으면 rollback?"
- "Breaking인지 Non-breaking인지 판단이 없어요. 호출자가 무변경으로 계속 동작하면 Non-breaking이에요."

**Length:** 4~8줄.

## Section 7: 롤백 플랜

**이 섹션의 역할:** Migration 없는 변경은 없다. 롤백이 단순(flag off)이면 1줄, 복잡하면 plan 필수.

**Ask (stem):**

> "다음을 써주세요:
>
> **롤백 방법:** flag off / revert PR / data rollback script / 여러 단계
> **롤백 시 사용자 영향:** 진행 중이던 세션/작업에 무엇이 일어나는가
> **롤백 시 데이터 영향:** 이미 새 방식으로 저장된 데이터가 있다면 어떻게?
> **롤백 가능 기한:** flag 제거 전 / 지속 가능 / 특정 날짜 이후 불가"

**Good example:**

- **롤백 방법:** `toc_manual_save` flag off.
- **사용자 영향:** 활성 세션은 새로고침 시 AS-IS UX로 복귀. 저장되지 않은 draft는 localStorage에서 그대로 유지되므로 데이터 손실 없음.
- **데이터 영향:** TOC 데이터 구조 변경이 없었으므로 영향 없음.
- **가능 기한:** flag 제거 전까지. 최소 2주 유지 예정. 2주 경과 후 flag 제거 → 롤백 불가.

**Bad example:**

> 문제 생기면 되돌린다.

**Self-check:**

- [ ] 롤백 동작이 구체적인가 (flag off / script / revert)
- [ ] 사용자 영향이 명시됐나
- [ ] 데이터 영향이 명시됐나 (없음이면 그것도 OK)
- [ ] 롤백 불가 시점이 있나 (flag 제거 후)

**Pushback probes:**

- "'되돌린다'는 어떻게? flag가 있으면 off, 없으면 revert PR이 필요해요."
- "데이터가 이미 새 형식으로 저장되어 있다면 롤백 시 호환 문제가 있을 수 있어요. 고려했나요?"

**Length:** 3~6줄.

## Section 8: 검증 커맨드 (FAIL→PASS / KEEP-PASSING / MIGRATED)

**이 섹션의 역할:** Feature Change는 3단 구조. 새 동작(FAIL→PASS) + 무관한 기존 동작(KEEP-PASSING) + AS-IS 테스트의 수정 버전(MIGRATED).

**Ask (stem):**

> "3 그룹을 써주세요:
>
> **FAIL→PASS** (TO-BE 동작 검증: fix 후 통과):
>
> - 새 테스트 or 수동 절차
>
> **KEEP-PASSING** (무관한 기존 동작):
>
> - 이 변경과 무관한 인접 모듈 테스트
>
> **MIGRATED** (AS-IS 테스트의 수정 버전):
>
> - Section 4에서 '수정'으로 마킹된 테스트들의 새 버전
> - AS-IS 테스트 → TO-BE 테스트 매핑"

**Good example:**

- **FAIL→PASS:**
  - `bun run test:unit -- toc-panel.test.ts -t "save button saves draft when dirty"`
  - 수동: 생성 완료 → 편집 → 저장 버튼 클릭 → 저장 확인 toast 표시.
- **KEEP-PASSING:**
  - `bun run test:unit -- toc-generation.test.ts` 전체 (생성 flow 무관)
  - `bun run test:unit -- manuscript-panel.test.ts` 전체 (인접 탭 무관)
- **MIGRATED:**
  - `toc-panel.test.ts`의 "auto saves on generation complete" (L45-L80)
    → "dirty state enables save button" 로 rename + 로직 교체
  - `use-toc-auto-save.test.ts` 전체 → **제거** (hook 자체 제거)

**Bad example:**

> 테스트 통과하면 된다.

**Self-check:**

- [ ] FAIL→PASS가 TO-BE 동작을 검증하나
- [ ] KEEP-PASSING이 이 변경과 무관한 범위인가
- [ ] MIGRATED 항목이 Section 4의 '수정' 항목과 1:1 매핑되나
- [ ] 제거되는 테스트도 MIGRATED에 명시됐나

**Pushback probes:**

- "Section 4에서 'use-toc-auto-save.test.ts'를 제거한다고 했는데, MIGRATED에 없어요. 추가하거나 Section 4와 정합성 맞춰주세요."
- "MIGRATED가 빠졌어요. AS-IS 동작을 검증하던 테스트가 정말 하나도 없었나요?"

**Length:** FAIL→PASS 2~4개, KEEP-PASSING 2~5개, MIGRATED 2~6개.

## Section 9: 관련 Steering 섹션 (Steering Sections to Read)

**이 섹션의 역할:** 본 Spec 구현 시 *반드시 함께 읽어야 할* Project Steering 본문의 섹션을 지정한다. `start-spec-implementation` 스킬이 이 목록을 파싱하여 코딩 세션 컨텍스트에 그 섹션들만 주입한다 (Steering 본문 전체 주입 X — context bloat 방지). 본 Spec의 forcing function 중 하나: 작성자가 *이 변경이 어떤 invariant를 건드리는지* 의식적으로 명시.

**Ask (stem):**

> "이 Spec이 *건드리는* 결정 영역에 해당하는 Project Steering 섹션 헤딩을 1~5개 bullet으로 적어주세요. Steering 본문에 적힌 섹션 헤딩을 *그대로* 인용하세요 (start-spec-implementation이 정확 일치로 추출).
>
> 분기·도메인 무관 거의 항상 포함 권장: `Domain Glossary`, `Business Rules`.
> 권한·롤이 관련되면: `Permissions & Role Model`.
> 데이터 격리·테넌시가 관련되면: `Multi-tenancy & Data Isolation`.
> 가격 게이팅이 관련되면: `Monetization Rules & Access Tiers`.
> 외부 시스템 연동이 관련되면: `External Interfaces & Dependencies`.
> 컴플라이언스가 관련되면: `Audit / Logging / Compliance`.
> i18n 결정이 관련되면: `i18n / l10n Invariants`."

**Good example:**

> - Domain Glossary
> - Business Rules
> - Permissions & Role Model

**Bad example:**

> - 모두 / Steering 전체

(전체 주입은 컨텍스트 노이즈를 만들고 본 섹션의 forcing function을 무력화한다.)

**Self-check:**

- [ ] 1개 이상 5개 이하인가
- [ ] Steering 본문의 *실제 섹션 헤딩*과 정확히 일치하는가 (typo 없이 그대로)
- [ ] 본 Spec이 *건드리는* 영역만 골랐는가 (over-selection 금지)
- [ ] 변경(Change)인 만큼 `Resolved Architectural Assumptions`도 검토했는가 (변경이 invariant를 건드리는지)

**Pushback probes:**

- "5개를 넘으면 forcing function이 무력화돼요. 본 Spec이 *직접* 건드리는 것만 추려주세요."
- "헤딩이 정확히 일치하지 않으면 start-spec-implementation이 fetch를 못해요. Steering 본문에서 복사·붙여넣기 권장."
- "기존 동작을 *변경*하는 Spec이면 그 변경이 Steering의 어떤 invariant를 흔드는지 한 번 확인하세요. 흔든다면 Initiative 레이어로 escalate."

**Length:** 1~5 bullets.

**Grounding:** Project DB 페이지 본문(Steering)의 섹션 헤딩을 직접 인용.

## Final Body Format (Notion 쓰기용)

````markdown
## 1. 변경 한 줄

<user input>

## 2. Chesterton's Fence

**AS-IS 도입:** <PR/commit>
**원래 해결하던 문제:** <...>
**여전히 유효한가:** <유효/무효>: <근거>
**TO-BE가 어떻게 해결:** <...>

## 3. AS-IS vs TO-BE

**AS-IS:**

```code
<actual code from file:line>
```
````

**TO-BE:**

```code
<new code>
```

**관찰 가능한 차이:**

- 사용자: <...>
- 호출자: <...>

## 4. 영향 받는 호출자

**코드 호출자:**

- `<file:line>`: <제거/수정/유지>

**사용자:**

- <역할 + 추정 수>
- 변경 직후 경험: <...>

## 5. Migration 경로

**데이터:** <필요/불필요 + how>
**코드:** <자동/수동 + 방법>
**사용자:** <UI/공지>
**Fallback:** <...>

## 6. Breaking 분류 및 롤아웃

**분류:** <Breaking/Non-breaking/Deprecation>: <근거>
**롤아웃:**

- Flag: `<name>`
- Stage 1: <% + 기간 + metric>
- Stage 2: <...>
- Stage 3: <...>

**Kill criterion:**

- <metric> <operator> <threshold> → <action>

## 7. 롤백 플랜

- **방법:** <...>
- **사용자 영향:** <...>
- **데이터 영향:** <...>
- **가능 기한:** <...>

## 8. 검증 커맨드

**FAIL→PASS:**

- `<command>`

**KEEP-PASSING:**

- `<command>`

**MIGRATED:**

- <AS-IS test> → <TO-BE test / 제거>

## 9. 관련 Steering 섹션

- <Steering section heading>
- <Steering section heading>

```

```
