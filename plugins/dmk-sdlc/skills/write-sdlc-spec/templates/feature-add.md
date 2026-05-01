---
category: feature-add
handles_request_type: 기능 추가
section_count: 7
---

# Template: 기능 추가 (Feature Add Spec)

A feature-add Spec is prospective ("something will exist"). It needs user-scenario anchoring, non-goals, and pattern-continuity so the AI agent builds consistent with the codebase. Modeled on Kiro requirements.md, Linear Project spec, Intercom JTBD, React/Rust RFC structure.

**Grounding mandate:** Sections 5, 6, 7 MUST cite real file:line from the Implementation Map: especially the "similar pattern to follow" and "extension point".

> **Note on examples.** All Good/Bad examples below are drawn from a single illustrative project (a book-publishing agent called BINGBONG: roles like `publisher`, features like TOC generation, file paths like `src/features/publisher/...`). They exist to show shape, not content. When running the skill, substitute actual identifiers from the user's Request, Projects DB, and `code.json`. Never reproduce these example identifiers in the user-facing prompt or the Spec body.

## Sections (in order)

1. 한 줄 Spec (Spec Line)
2. 사용자 시나리오 (User Scenario, JTBD)
3. 수용 기준 (Acceptance Criteria, WHEN/THEN)
4. 범위 밖 (Non-Goals)
5. 따라야 할 기존 패턴 (Existing Patterns to Follow)
6. 확장 지점 및 의존 표면 (Extension Points & Dependencies)
7. 검증 커맨드 (Verification Commands)

## Section 1: 한 줄 Spec

**이 섹션의 역할:** Linear Summary + Intercom JTBD. 한 문장으로 역할·상황·동작·가치를 커밋.

**Ask (stem):**

> "다음 형식으로 한 문장 Spec을 써주세요:
>
> **[사용자 역할]**이 **[상황]**에서 **[동작]**할 수 있게 해서 **[측정 가능한 결과/가치]**를 달성한다."

**Good example:**

> publisher가 TOC 생성 스트림 중 실시간으로 섹션 순서를 드래그해서 최종 결과에 반영하게 해서, 생성 완료 후 재정렬 비용을 없앤다.

**Bad example:**

> TOC 편집 기능 개선. / 사용자 경험 향상.

**Self-check:**

- [ ] 역할이 명시되었나 (publisher / editor / admin 등)
- [ ] 상황이 구체적인가 ("생성 스트림 중" 수준)
- [ ] 가치가 측정 가능한 결과인가 ("재정렬 비용 제거" 수준)
- [ ] 한 문장인가

**Pushback probes:**

- "'사용자'는 역할이 아니에요. 정확히 어떤 role/권한의 사용자인가요?"
- "'향상'은 측정 불가능해요. 지금 몇 초 걸리는 게 몇 초로 줄어드나요? 또는 어떤 행동이 없어지나요?"
- "한 문장으로 줄여주세요. 못 줄이면 아직 요약이 안 된 거예요."

**Length:** 1 문장.

**Grounding:** Request body에서 사용자 역할/상황 힌트 추출.

## Section 2: 사용자 시나리오 (JTBD)

**이 섹션의 역할:** Amazon PR quote + Intercom JTBD. 추상을 구체적 1인칭 경험으로 강제.

**Ask (stem):**

> "다음 형식으로 써주세요:
>
> **[상황]**에서, **[사용자 페르소나]**가 **[동기/감정]**를 느낀다.
> 지금은 **[현재 하는 고통스러운 행동]**을 한다: 평균 **[시간/횟수]** 낭비.
> 이 기능이 있으면 **[대신 이것]**을 할 수 있다."

**Good example:**

> 원고 50페이지를 업로드하고 TOC 생성을 기다리는 중, publisher는 1번째 섹션부터 구조가 이상함을 본다.
> 지금은 끝까지 기다린 뒤 전체 재생성 (평균 3분) 하거나 생성 후 수동으로 드래그 재정렬 (평균 4분)한다.
> 이 기능이 있으면 스트림 중 드래그 한 번으로 남은 섹션 생성이 그 순서를 따른다: 완료 시점에 이미 올바른 순서.

**Bad example:**

> 사용자가 TOC를 더 쉽게 편집할 수 있다.

**Self-check:**

- [ ] 현재의 고통이 구체적 시간/횟수로 표현됐나
- [ ] 한 명의 특정 사용자처럼 읽히나 (1인칭 narrative)
- [ ] "대신 이것을"이 Section 1의 동작과 일치하나
- [ ] 상황이 Implementation Map의 실제 flow와 맞는가

**Pushback probes:**

- "'더 쉽게'는 측정 불가. 지금 몇 분 걸리는 일을 몇 분으로 줄이나요?"
- "이 사용자는 누구인가요? publisher 중에서도 어떤 상황의 어떤 사람?"
- "현재 '고통스러운 행동'이 실제로 관찰된 것인가요, 추측인가요? 로그나 인터뷰 근거가 있나요?"

**Length:** 3~6줄.

**Grounding:** 실제 사용자 인터뷰 인용이 있으면 포함. 없으면 명시적으로 '추정'.

## Section 3: 수용 기준 (Acceptance Criteria)

**이 섹션의 역할:** Kiro EARS. 모호한 "작동한다" 차단. AI 에이전트가 테스트로 변환 가능한 수준.

**Ask (stem):**

> "WHEN/THEN/SHALL 형식으로 수용 기준 4~8개를 써주세요.
>
> WHEN **[trigger]** THEN the system SHALL **[측정 가능 결과]**
>
> 최소 요구:
>
> - Happy path AC 2~3개
> - Edge case AC 1~3개
> - Error case AC 1~2개"

**Good example:**

- WHEN publisher가 스트림 중 섹션 카드를 드래그해서 놓으면 THEN 시스템은 현재 생성 중 이후의 섹션 순서를 새 순서로 업데이트하고 UI에 100ms 이내 반영해야 한다.
- WHEN 드래그가 현재 생성 중인 섹션 위로 떨어지면 THEN 시스템은 드롭을 거부하고 "생성 중인 섹션은 이동 불가" toast를 표시해야 한다.
- WHEN 스트림이 완료되고 드래그 중 was-in-progress였던 섹션이 있으면 THEN 시스템은 재정렬 기록에 따라 최종 순서를 반영해야 한다.
- WHEN 네트워크가 끊기면 THEN 현재까지의 재정렬은 유지되고, 재연결 시 순서가 보존되어야 한다.

**Bad example:**

> 드래그가 잘 작동해야 한다.

**Self-check:**

- [ ] 각 AC가 WHEN/THEN/SHALL 형식인가
- [ ] SHALL 뒤에 측정 가능한 동작이 있나 (100ms 이내 / toast 표시 / 등)
- [ ] Edge case AC가 최소 2개인가
- [ ] Error case AC가 최소 1개인가
- [ ] 각 AC가 자동/수동 테스트 가능한가

**Pushback probes:**

- "'잘 작동해야 한다'는 측정 불가. 무엇이 어떻게 관찰되어야 하나요?"
- "AC에 Edge case가 없어요. 예: 드래그를 생성 중 섹션에 떨어뜨리면? 드래그 중 스트림 완료되면?"
- "이 AC는 코드로 검증 불가능한 표현이에요. Section 7 (Verification) 작성이 어려울 거예요. 다시 써주세요."

**Length:** 4~8 AC.

**Grounding:** Implementation Map에서 인접 기능의 edge case 패턴 참고.

## Section 4: 범위 밖 (Non-Goals)

**이 섹션의 역할:** Linear "not building" + Shape Up appetite. 야심 억제.

**Ask (stem):**

> "이 Spec이 **하지 않는** 것 3~6개를 써주세요.
>
> 형식: 이 Spec은 **[X]**를 하지 않는다. **[X]**를 원하는 사용자는 **[기존 경로 / 후속 Spec]**을 사용한다.
>
> 유혹적이지 않으면 쓸 가치 없음. 진짜로 누군가 '이것도 넣자'라고 할 만한 것만."

**Good example:**

- 완성된 TOC의 재정렬은 하지 않는다. 완성 후 재정렬은 기존 편집 모드 사용.
- 모바일 드래그 인터랙션은 하지 않는다. 데스크탑 publisher workflow만.
- 다중 선택 드래그는 하지 않는다. 후속 Spec 후보.
- 드래그 후 undo/redo는 하지 않는다. 페이지 새로고침이 reset.

**Bad example:**

> (섹션 생략 또는 "TBD")

**Self-check:**

- [ ] 최소 3개인가
- [ ] 각 항목이 유혹적인 스코프인가 (아무도 안 할 일은 쓸 필요 없음)
- [ ] 제외 이유가 "시간 없음"인지 "범위 밖"인지 구분됐나
- [ ] 후속 경로가 있다면 언급됐나

**Pushback probes:**

- "Non-goal이 1~2개면 생각이 덜 된 거예요. 드래그 기능이면 '완성 후 재정렬', '모바일', '다중 선택', 'undo', '키보드 단축키' 등 다 고민해봤나요?"
- "이 Non-goal이 유혹적이지 않아요. 아무도 안 할 일이면 쓸 필요 없어요."

**Length:** 3~6 bullets.

## Section 5: 따라야 할 기존 패턴

**이 섹션의 역할:** AI 에이전트가 코드베이스와 일관되게 작성하도록 앵커. 새 패턴을 도입하지 않고 기존을 확장.

**Ask (stem):**

> "다음 형식으로 3~6개 패턴을 써주세요:
>
> - **[요소]**: `[파일:줄]`의 **[패턴 이름]**을 따른다. 근거: **[일관성 이유]**."

**Good example:**

- 스트림 처리: `src/features/publisher/hooks/use-toc-generation.ts:L42-L120`의 `useStreamWithAbort` 패턴을 따른다. AbortController cleanup과 Zustand 동기화가 이미 확립됨.
- Zustand slice: `src/features/publisher/store.ts:L15-L80`의 `tocSlice` 확장. 새 feature 폴더 만들지 말 것.
- 드래그 UI: `src/components/ui/sortable.tsx`의 shadcn sortable 사용. 이미 도입됨.
- Toast: `sonner`의 `toast.error()` 사용 (CLAUDE.md 규칙).
- 타입: `drizzle-zod`로 schema에서 infer: 수동 타입 선언 금지.

**Bad example:**

> 기존 코드 스타일을 따른다.

**Self-check:**

- [ ] 실제 파일 경로(:line)가 있나
- [ ] 왜 이 패턴인지 근거가 있나
- [ ] 새 의존성 추가가 있다면 그 이유가 명시됐나
- [ ] Implementation Map의 유사 기능에서 참조했나

**Pushback probes:**

- "'기존 스타일'은 앵커가 아니에요. 구체적으로 어떤 파일의 어떤 함수를 모방하나요?"
- "새 라이브러리를 추가한다는데, 이유가 뭔가요? 기존 패턴으로 안 되나요?"
- "이 파일이 Implementation Map에 없어요. 다시 코드 읽을까요?"

**Length:** 3~6 bullets.

**Grounding (강제):** 모든 참조는 Implementation Map에서 실제로 읽은 파일.

## Section 6: 확장 지점 및 의존 표면

**이 섹션의 역할:** "Dependencies" 일반 섹션의 재해석. "어디에 연결해야 하나"를 명확히 해서 AI 에이전트가 touching-set을 예측 가능.

**Ask (stem):**

> "다음 3가지를 써주세요:
>
> 1. **수정**: 기존 파일 중 수정할 것 (`파일:줄` + 무엇을 수정)
> 2. **추가**: 새로 만들 파일/함수/컴포넌트 (경로 + 역할)
> 3. **외부 계약**: API/Schema/DB 변경 여부. 변경 있으면 migration 필요 여부 명시."

**Good example:**

- **수정:**
  - `src/features/publisher/schemas/book-detail.schema.ts:L42`: `tocSections`에 `order: number` 필드 추가 (JSONB이므로 DB migration 불필요).
  - `src/features/publisher/store.ts:L60-L80`: `tocSlice`에 `reorderSections` action 추가.
  - `src/features/publisher/components/toc-panel.tsx:L200`: `SortableList` 렌더링 추가.
- **추가:**
  - `src/features/publisher/hooks/use-toc-reorder.ts`: 재정렬 상태와 stream 동기화.
  - `src/features/publisher/components/reorderable-toc-list.tsx`: shadcn sortable 래핑.
- **외부 계약:**
  - FastAPI `/toc/generate`: 변경 없음. 재정렬은 client-side. 다음 섹션 생성 요청 시 현재 순서를 payload에 포함하여 전달.
  - Supabase schema: 변경 없음 (JSONB 내 필드 추가).

**Bad example:**

> 여러 파일을 수정하고 새 컴포넌트를 추가한다.

**Self-check:**

- [ ] 수정/추가/외부 계약이 분리되었나
- [ ] 모든 파일이 file:line 형식인가
- [ ] Schema 변경 시 migration 필요 여부가 명시됐나
- [ ] API 계약 영향이 명시됐나 (변경 없음이면 그것도 OK)
- [ ] AI 에이전트가 이 목록으로 touching-set 예측 가능한가

**Pushback probes:**

- "'여러 파일'은 구체적이지 않아요. 몇 개, 어느 파일인가요?"
- "Schema 변경인데 migration 언급이 없어요. 기존 row에 영향 있나요?"
- "외부 계약 영향이 빠졌어요. FastAPI 호출이 있는 기능이면 request/response 변경 여부를 명시해주세요."

**Length:** 수정 2~5, 추가 1~4, 외부 계약 1~3.

**Grounding:** Implementation Map의 진입점 + 관련 schema.

## Section 7: 검증 커맨드

**이 섹션의 역할:** AI 에이전트가 "완료"를 코드로 판정 가능.

**Ask (stem):**

> "다음을 써주세요:
>
> **FAIL→PASS** (새 테스트: fix 후 통과):
>
> - 자동 테스트 이름 or 수동 절차 verbatim
>
> **KEEP-PASSING** (regression 방지):
>
> - 기존 테스트 파일 / 특정 테스트 이름
>
> AC (Section 3)의 각 항목이 하나 이상의 검증 항목과 매핑되는가?"

**Good example:**

- **FAIL→PASS (새 테스트):**
  - `bun run test:unit -- use-toc-reorder.test.ts` (새 파일)
  - 수동: 시나리오(Section 2) 단계를 복기: 드래그 → 남은 생성 섹션 순서가 변경됨.
- **KEEP-PASSING:**
  - `bun run test:unit -- use-toc-generation.test.ts` 전체 (기존 생성 flow 유지)
  - 수동: 드래그 없이 생성하면 기본 순서 유지 + 기존 편집 모드 재정렬 동작.

**Bad example:**

> 테스트 작성.

**Self-check:**

- [ ] FAIL→PASS가 새로 추가할 테스트인지 기존 실패 테스트인지 구분됐나
- [ ] KEEP-PASSING 범위가 합리적인가 (관련 모듈만)
- [ ] AC 각 항목이 검증 항목에 매핑되나
- [ ] 수동 절차가 복붙 가능한가

**Pushback probes:**

- "AC 4번(네트워크 끊김)에 대한 검증이 없어요. 어떻게 검증하나요?"
- "KEEP-PASSING 범위가 너무 넓어요. 이 feature가 건드릴 모듈만 좁혀주세요."

**Length:** FAIL→PASS 2~4개, KEEP-PASSING 2~5개.

**Grounding:** Implementation Map의 인접 테스트 파일.

## Final Body Format (Notion 쓰기용)

```markdown
## 1. 한 줄 Spec

<user input>

## 2. 사용자 시나리오

<3-6 line narrative>

## 3. 수용 기준

- WHEN <trigger> THEN the system SHALL <result>
- WHEN <trigger> THEN the system SHALL <result>
  ...

## 4. 범위 밖

- <non-goal 1>
- <non-goal 2>
- <non-goal 3>

## 5. 따라야 할 기존 패턴

- <element>: `<file:line>`의 <pattern>: <근거>
- ...

## 6. 확장 지점 및 의존 표면

**수정:**

- `<file:line>`: <what>

**추가:**

- `<new-file-path>`: <role>

**외부 계약:**

- <API/Schema>: <변경 내용 또는 "변경 없음">

## 7. 검증 커맨드

**FAIL→PASS:**

- `<command>`
- 수동: <procedure>

**KEEP-PASSING:**

- `<command>`
- 수동: <procedure>
```
