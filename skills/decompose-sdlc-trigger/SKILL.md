---
name: decompose-sdlc-trigger
description: Decomposes a 트리거(Initiative) document into N sub-Requests in the Notion Requests DB via AI-draft + Human-edit loop. Reads the parent Trigger's Fat Marker Sketch, Success Criteria, Appetite, and Rabbit Holes; proposes 3–7 candidate sub-Requests aligned with INVEST criteria (Independent, Negotiable, Valuable, Estimable, Small, Testable); lets the human review/edit/reject/add in a single approval gate; then batch-writes to Notion with proper relations. Use when the user says "트리거 분해", "하위 요구사항 나눠줘", "이 Trigger를 Requests로 쪼개줘", "decompose trigger", "break down initiative", or after a Trigger's Phase 8 Review has completed and sub-work items need to exist in Requests DB. Do NOT use for small Requests that directly map to a single Spec (bypass to write-sdlc-spec) or for Triggers without a completed Fat Marker Sketch.
---

# Decompose SDLC Trigger

A 트리거(Initiative) is a 2–6 week strategic bet. It is not directly executable: it must be decomposed into atomic sub-Requests that each become inputs to `write-sdlc-spec`. This skill performs that decomposition: AI proposes candidates grounded in the Trigger's Fat Marker Sketch, human reviews with forcing-function pushback, and the final set is batch-written to Notion Requests DB with proper parent relations.

**Position in pipeline:**

```
Trigger (Initiative)
    │
    ▼
  [THIS SKILL]
    │
    ▼
N sub-Requests (in Requests DB)
    │
    ▼ (each, separately)
  write-sdlc-spec → N Specs
```

## When to Use

- User has finalized a Trigger (상태 not Killed) and wants to produce executable sub-work.
- User says "트리거 분해", "하위 요구사항 나눠줘", "decompose trigger", "break down initiative".
- Re-decomposition: user wants to add more sub-Requests under an already-decomposed Trigger.

## When NOT to Use

- Request that maps 1:1 to a Spec → use `write-sdlc-spec` directly.
- Trigger without a completed Fat Marker Sketch → push back to complete the Trigger first.
- Non-dev request types (지원 요청, 행정 요청, 리서치 요청): these do not follow this pipeline.
- A Killed Trigger: decomposition after kill is wasted effort; either revive or start new.

## Prerequisites

### 1. Notion MCP connected

Check by confirming `mcp__notion__*` tools are available. If not:

> "먼저 Notion MCP를 연결해주세요. 연결 없이는 분해 결과를 저장할 수 없습니다."

and stop.

### 2. Parent Trigger specified

The user must provide one of:

- Trigger page URL
- Trigger page ID
- A keyword to search (skill lists matches and asks user to pick)

If none provided:

> "분해할 Trigger를 알려주세요. Notion URL / 페이지 ID / 검색 키워드 중 하나로."

### 3. Fixed DB IDs for this workspace

- Triggers DB: `33fcd0143f6e80a5bb1fc67a1bd387ac`
- Triggers data source: `33fcd014-3f6e-8092-a585-000b407693e7`
- Requests DB: `33ecd0143f6e8037adcee2672e0abd0c`
- Requests data source: `33ecd014-3f6e-80c0-b177-000b3e08ac88`
- Projects DB: `b6ce9cb2184e47f0ba8c370b03dacf49`

## Core Principles

### Principle 1: Decompose by functional Path, not by layer

Align with Shape Up + SPIDR: Fat Marker Sketch's 핵심 흐름 (core flow) is the primary splitting axis. Do NOT split by frontend/backend/QA layers. Each sub-Request must be a **shippable functional slice** that delivers user-visible value.

### Principle 2: Sub-Requests are intake-level, not spec-level

A sub-Request is a _placeholder for a future conversation_ (Bill Wake's INVEST "Negotiable"). It must NOT prescribe implementation. The lightweight 5-section body holds goal/scope/acceptance-hints only: `write-sdlc-spec` will later expand into full spec.

### Principle 3: Plan-and-Solve discipline

Before listing individual candidates, the AI drafts a **decomposition strategy** (what splitting axis, why, expected N) and gets user approval. This separates planning from generation and prevents cascade errors. (Wang et al. 2023.)

### Principle 4: HITL with forcing functions, not ceremony

Single approval gate per candidate (Accept / Edit / Reject / Skip) plus one final set-level gate. Every candidate surfaces inline warning flags from the INVEST validator and anti-pattern checks. The AI must never silently suppress flags.

## Workflow

| Phase                      | Responsibility                                                                |
| -------------------------- | ----------------------------------------------------------------------------- |
| 0. Preflight               | Load Trigger, existing children, parse sections                               |
| 1. AI Strategy Draft       | AI proposes splitting axis + expected N; user approves or redirects           |
| 2. AI Candidate Generation | AI emits N candidates per approved strategy                                   |
| 2.5. AI Self-Critique      | AI runs INVEST validator + anti-pattern check on its own output, flags inline |
| 3. Human Review Loop       | User walks candidates; Accept / Edit / Reject / Add; iterate until finalize   |
| 4. Batch Write             | Create N Requests in Notion with parent relations                             |

## Phase 0: Preflight

### 0.1 Resolve parent Trigger

Use `mcp__notion__notion-fetch` on the supplied URL/ID. If user gave a keyword, `mcp__notion__notion-search` on the Triggers data source, show top 5, ask user to pick.

### 0.2 Parse required sections

Extract from Trigger body:

- **§1 TL;DR**: for context in AI prompt.
- **§4 Fat Marker Sketch**: primary input (핵심 흐름 steps, 관건 지점, 접점).
- **§5 Appetite**: determines sub-Request budget (2주 / 6주).
- **§6 Rabbit Holes & No-gos**: exclusion context.
- **§7 Success / Kill Criteria**: each sub-Request must contribute to one success criterion.

If Fat Marker Sketch is empty or section is missing:

> "이 Trigger의 Fat Marker Sketch가 비어있습니다. 분해의 근거가 되는 섹션이 없으면 AI 초안이 의미가 없습니다. 먼저 Trigger §4를 완성해주세요."

and stop.

### 0.3 Load Project relation

Fetch the Trigger's `프로젝트` relation value. Save for child Requests to inherit.

### 0.4 Load existing children (re-decomposition case)

Query Requests DB for rows with `트리거` relation pointing to this Trigger page:

```
mcp__notion__notion-search(
  query = "",
  data_source_url = "collection://33ecd014-3f6e-80c0-b177-000b3e08ac88",
  page_size = 25
)
```

Client-side filter by `트리거` relation = parent Trigger.

If existing children found, surface:

> "이 Trigger에 이미 연결된 하위 Request가 **{N}개** 있습니다:
> {numbered list with titles}
>
> (a) 추가 분해: 기존 유지 + 새 후보 추가
> (b) 확인만 하고 종료
>
> 중복 제목은 Phase 3에서 경고합니다."

### 0.5 Announce preflight summary

> "준비 완료:
>
> - Trigger: {title}
> - Appetite: {2주/6주} ({N} dev-days 예산)
> - 핵심 흐름 단계: {N}개
> - Rabbit Holes: {N}개 · No-gos: {N}개
> - 기존 하위 Request: {N}개
> - 프로젝트: {project name}
>
> 분해 전략 제안을 시작합니다."

## Phase 1: AI Strategy Draft

### 1.1 AI produces decomposition strategy

Using the parsed Trigger, the AI writes a 3–5 sentence strategy that MUST include:

- **Splitting axis** chosen (Paths / Data / Interfaces / Rules: SPIDR).
- **Justification** citing a specific Trigger section.
- **Expected N** (3–7 typical; 2–3 for 2주 Appetite; 3–7 for 6주).
- **Unknowns** explicitly noted as Spikes (not sub-Requests) for future Spec phase.

### 1.2 Heuristics for axis selection

| Trigger signal                         | Suggested axis              |
| -------------------------------------- | --------------------------- |
| Sequential numbered steps in 핵심 흐름 | **Paths** (primary default) |
| Multiple input/output formats          | **Data**                    |
| Multiple surfaces (UI + API + mobile)  | **Interfaces**              |
| Substantial branching logic            | **Rules** (secondary only)  |

When in doubt, default to **Paths**: it matches Fat Marker Sketch structure directly.

### 1.3 Present strategy to user

> "제안 분해 전략:
>
> **분해 축:** Paths (Fat Marker Sketch §4의 핵심 흐름 {N}단계를 따름)
> **예상 하위 Request 수:** {N}
> **근거:** {one-line from Trigger §4 or §7}
> **Spike 마크 (Spec 단계로):** {any unknown regions from §4}
>
> 이 전략으로 진행? (yes / redirect '축=Data' / edit)"

If user redirects, accept and re-plan. Do NOT generate candidates until strategy is approved.

### 1.4 Forcing function

Strategy must name one SPIDR letter and cite a specific Trigger section line or concept. Vague strategies (e.g., "split by logical chunks") get rejected by the skill itself before showing to user.

## Phase 2: AI Candidate Generation

### 2.1 Generate candidates per approved strategy

The AI emits N candidates. Each candidate must have all 5 body sections draft-filled (see **Sub-Request Body Template** below) and the following metadata:

- **제목** (Title): verb + concrete object, not a noun phrase
- **유형**: one of: 기능 추가 / 기능 변경 / 기능 개선 / 기능 에러 (per heuristic below)
- **크기** (Size): one of S (≤2 dev-days) / M (3–4 dev-days) / L (5–7 dev-days)
- **우선순위** (Priority): default inherit from Trigger's 우선순위; candidate can mark higher for cut-line

### 2.2 유형 assignment heuristic

- **기능 추가**: candidate introduces new user-facing capability (default when ambiguous)
- **기능 변경**: candidate modifies existing behavior's contract
- **기능 개선**: candidate improves non-functional quality (perf, UX polish) without contract change
- **기능 에러**: candidate addresses a defect explicitly referenced in Trigger §2 Problem

### 2.3 Fat Marker Sketch → Candidate mapping

For Paths axis:

- Each numbered step in 핵심 흐름 → one candidate (default 1:1).
- **관건 지점** noted in Trigger: candidate carrying that step gets a warning flag: "관건 지점 포함: Spec 단계에서 특히 주의".
- **접점** (integration points): candidate carrying the interface gets size +1 bump (boundary work is costly).

### 2.4 Rabbit Holes / No-gos handling

- For each candidate, AI token-checks scope against No-go text. If overlap, **drop candidate and flag** in internal trace:
  > "{candidate title} was dropped: scope intersects No-go '{no-go text}'."
- Rabbit Holes are WARNINGS, not work. AI must NEVER emit a candidate whose goal matches Rabbit Hole description. If AI detects Rabbit Hole as the essence of the work, return a single-line: "이 작업은 Trigger에 Rabbit Hole로 표기되어 있습니다. Trigger 자체의 재검토를 권장합니다."

### 2.5 Constraints

- Min 2 candidates (below this is not decomposition).
- Max 10 candidates generated internally; if the AI's plan demands >10, it must instead propose **grouping** into 10 or fewer.
- No sub-Request-of-sub-Request. Flat only.
- Sum of sizes ≤ Appetite budget × 1.2 (20% tolerance before Phase 3 warning).

## Phase 2.5: AI Self-Critique

Before showing candidates to user, the AI runs the INVEST validator and anti-pattern checks privately. Any failure is surfaced as an inline warning tag on the candidate: NOT silently fixed.

### INVEST validator (applied per candidate)

**I: Independent**

- Scan description for cross-references ("after #X", "requires Y"). If present, flag `[Independence: references #X]`.
- Token-overlap with other candidates' 목적 > 60% → flag `[Redundant with #Y]`.

**N: Negotiable**

- Scan for implementation prescriptions (library names, architecture terms, specific technology choices like "Redis", "REST", "GraphQL", "useEffect", "PostgreSQL trigger"). If present, flag `[Spec-leakage: 'X']` and ask user in Phase 3: "이건 Spec 단계로 미루세요."

**V: Valuable**

- Goal must complete "[사용자/시스템]이 X를 할 수 있게 된다". If purely internal (e.g., "Refactor auth"), flag `[No user-visible outcome]`.
- Trigger 기여 section must cite a specific Success Criterion from Trigger §7. If generic ("전반적 목표에 기여"), flag `[Unspecific contribution]`.

**E: Estimable**

- If AI itself cannot assign S/M/L, flag `[Too vague for size]`.

**S: Small**

- Size > L → auto-propose split; flag `[XL: propose split]`.
- Candidate with size XL must be replaced, not surfaced as-is.

**T: Testable**

- At least one acceptance hint that passes the "<5 min to verify" rule (observable, not "사용자 만족").
- No acceptance hint → flag `[No observable acceptance]`.

### Anti-pattern scan (top 10 from research)

1. **Task Smuggling**: goal describes technical action, not capability.
2. **Horizontal Slicing**: two candidates share outcome, differ by layer.
3. **Unbounded Parent**: scope > 1 sentence, size indeterminate.
4. **Forbidden Quest**: overlap with Rabbit Hole/No-go.
5. **Spec Leakage**: named technology in goal/scope.
6. **MMMSS Misapplied**: two S-size candidates with >50% overlap.
7. **Phantom Success**: no observable acceptance.
8. **Serialized Pipeline**: each depends on prior; count > N-1.
9. **Doppelgänger**: title collision with existing child.
10. **Bucket Title**: noun-phrase title, body lists unrelated items.

Each detection attaches a flag to the candidate's display in Phase 3.

## Phase 3: Human Review Loop

### 3.1 Display format per candidate

Show ONE candidate at a time, or a numbered list (user preference at start). Default: numbered list with summary + first candidate expanded.

Per-candidate block:

```
[1/5] {title}                               [유형: 기능 추가] [크기: M] [우선순위: P1]

목적: {one-line goal}

Trigger 기여: {specific success criterion reference}

범위:
  포함: {what's in}
  제외: {what's out}

수용 기준 힌트:
  - {hint 1}
  - {hint 2}

참조: 부모 Trigger {title}. 관련 하위: #{N} ({relation}).

⚠ flags: [Independence: references #3] [Size: borderline L]

[A]ccept  [E]dit  [R]eject  [S]kip
```

### 3.2 Actions

- **Accept** → move to finalized set.
- **Edit** → open inline editor; on save, re-run INVEST; if size changes, update running total; if title changes, re-run dedup.
- **Reject** → prompt: "한 줄 사유? (AI가 다음 반복 개선에 반영)". Store reason.
- **Skip** → move on without decision; can return later.
- **Add** → user types title + goal; AI fills remaining sections as draft; user edits.

### 3.3 Running totals (shown at top of display)

```
Accepted: 3 / Proposed: 5
Total size: 12 dev-days (Appetite budget: 30: 18 days headroom)
Coverage: 2/3 core-flow steps mapped
```

### 3.4 Iteration termination

User issues `finalize` (or button). Skill runs Phase 3.5 validation.

### 3.5 Set-level validation (runs at finalize)

**Coverage check**

- Extract core-flow step list from Trigger §4.
- Build reverse index: which sub-Request addresses which step.
- **Fail:** any step has zero sub-Requests mapped.
- **Message:** "핵심 흐름 단계 **{N: '편집'}**이 어떤 하위 Request에도 매핑되지 않았습니다. 누락입니까, 의도적 제외입니까?"

**Appetite fit**

- Sum T-shirt sizes (S=2, M=4, L=7 dev-days).
- Compare with Appetite budget (2주=10 · 6주=30 for single dev; ×team size if user specified).
- **Fail condition:** sum > 1.2 × Appetite.
- **Message:** "예상 공수 **{X}일**이 Appetite 예산 **{Y}일**을 초과합니다. 범위 축소 또는 Trigger Appetite 재검토."

**Independence**

- Count cross-references. **Warn** if > N-1.
- **Message:** "의존성 {N}개 감지. 순차 파이프라인이라면 병합 검토."

**No-go intersection**

- Pairwise token-check sub-Request scope against Trigger §6 No-gos.
- **Fail:** any intersection.
- **Message:** "하위 Request #{N}의 범위가 No-go '{text}'와 충돌합니다."

**Redundancy**

- Pairwise 목적+acceptance overlap > 60%.
- **Warn:** "후보 #{A}와 #{B} 중복 가능성. 병합 검토."

User may override with a recorded reason:

> "이 집합은 {Coverage failed}. 계속하시려면 사유를 입력해주세요:"

Reason is prepended to the Notion write as a callout.

### 3.6 Abort condition (3 failed iterations)

If 3 rounds of review produce no accepted candidates:

> "3번째 반복에도 확정된 하위 Request가 없습니다. Trigger 자체가 분해 가능한 수준까지 구체화되지 않았을 수 있습니다. 다음 중 선택:
> (a) 분해 축을 바꿔 다시 시도 ('Data'로 재전략)
> (b) 수동 모드: AI 초안 없이 직접 후보 입력
> (c) 중단: Trigger 구체화 후 재시도"

## Phase 4: Batch Write to Notion

### 4.1 Confirm

> "{N}개 하위 Request를 Notion Requests DB에 생성합니다. 모두 부모 Trigger **{title}**에 연결됩니다. 진행?"

### 4.2 Batch write

Use `mcp__notion__notion-create-pages` with up to 100 pages in one call (fits our 2–10 range easily).

```
parent: { type: "data_source_id", data_source_id: "33ecd014-3f6e-80c0-b177-000b3e08ac88" }
pages: [
  {
    properties: {
      "이름": "<sub-request title>",
      "유형": "<기능 추가 | 기능 변경 | 기능 개선 | 기능 에러>",
      "카테고리": "개발",
      "우선순위": "<inherited or overridden>",
      "트리거": "<parent trigger URL>",
      "프로젝트": "<project URL inherited from Trigger>"
    },
    content: "<compiled 5-section markdown body>"
  },
  ...
]
```

Do NOT set `상태` explicitly: defaults to "미할당" automatically when 담당자 is empty.

### 4.3 Atomic handling

If any write fails:

- Collect successful page IDs.
- Surface failure: "Created {M} of {N}. Failed: {list with errors}. 재시도할까요?"
- Do NOT silently lose content. Keep draft in memory for retry.

### 4.4 Final report

> "분해 완료:
>
> Trigger: {title}
> 생성된 하위 Request: {N}개
>
> {numbered list with titles + 유형 + size + Notion URL}
>
> 총 공수: {X}일 / Appetite 예산: {Y}일
> 핵심 흐름 커버리지: {M}/{N}
>
> 다음 단계: 각 하위 Request에 대해 `write-sdlc-spec` 호출 → Spec 작성."

## Sub-Request Body Template (5-section)

Each sub-Request's body in Notion. Target 150–300 words total.

```markdown
## 1. 목적

<this sub-Request가 완료되면 [사용자/시스템]이 [구체적 능력]을 할 수 있게 된다>

## 2. Trigger 기여

부모 Trigger의 성공 기준 `<quoted from Trigger §7>`에 기여한다.
이 하위 Request가 <측정 가능 결과>를 달성하면 전체 목표에서 <~%/단계> 진전이다.

## 3. 범위

**포함:** <구체 artifact/surface>
**제외:** <명시적으로 이 하위 Request에서 다루지 않을 것>

## 4. 수용 기준 힌트

- <관찰 가능한 조건 1>
- <관찰 가능한 조건 2>

(이는 힌트이며, 전체 수용 기준은 향후 write-sdlc-spec에서 확정됩니다.)

## 5. 참조

- 부모 Trigger: <title + Notion link>
- 관련 하위 Request: #<N> <title> (<relation: 선행/후행/병렬>)
```

### Section stems + good/bad examples

**§1 목적: 30–60 words**

- Stem: "이 하위 Request가 완료되면, [사용자/시스템]이 [구체적 능력]을 할 수 있게 된다."
- Good: "작가가 업로드한 원고 PDF에서 목차를 자동 추출해 편집 가능한 형태로 볼 수 있게 된다."
- Bad: "PDF 파싱 개선" (no actor, no outcome)

**§2 Trigger 기여: 20–40 words**

- Good: "Trigger 성공기준 '목차 생성 시간 2분 이내' 중 추출 단계. 현재 5분 → 목표 1분."
- Bad: "Trigger의 전반적 목표에 기여"

**§3 범위: 40–80 words**

- Good: "포함: PDF 텍스트 레이어 기반 추출, 한국어. 제외: OCR, 영어, 편집 UI (별도 하위 Request)."
- Bad: "PDF에서 목차 추출 관련 작업"

**§4 수용 기준 힌트: 2–4 bullets, each 1 sentence**

- Good:
  - "샘플 10개 원고에 대해 추출 결과가 수동 입력 목차와 90% 이상 일치."
  - "추출 시간이 원고당 1분 이내."
- Bad:
  - "잘 동작한다."
  - "사용자가 만족한다."

**§5 참조: 20–40 words**

- Good: "부모: '자동 목차 생성' Trigger. 관련: #3 '목차 편집 UI' (이 Request의 출력이 입력)."
- Bad: "관련 문서 참조."

## Forcing Function Stems (copy-ready)

The skill surfaces these verbatim when appropriate.

**Phase 0: Preflight**

- "이 Trigger의 Appetite는 **{2주/6주}**입니다. 하위 Request 총 공수가 이를 넘지 않도록 합니다."
- "Fat Marker Sketch의 핵심 흐름 단계 **{N}개**를 확인했습니다. 각 단계가 하위 Request로 표현될 수 있나요?"

**Phase 1: Strategy**

- "어떤 축으로 분해하시겠어요? Paths(흐름) / Data(데이터) / Interfaces(인터페이스) / Rules(규칙)?"
- "선택한 분해 축이 Trigger의 Success Criteria와 어떻게 연결되는지 한 문장으로 설명해주세요."

**Phase 2–3: Review**

- "이 하위 Request가 완료되면 사용자가 구체적으로 무엇을 할 수 있게 되나요?"
- "이 문장은 Spec 단계 같습니다. 지금은 '무엇'만 적고 '어떻게'는 미루세요."
- "이 하위 Request의 크기는 S / M / L 중 어느 정도인가요?"
- "Trigger의 No-go 항목 **'{text}'**과 충돌하지 않는지 확인해주세요."
- "이 하위 Request는 Trigger의 어떤 성공 기준에 직접 기여하나요?"
- "완료 여부를 5분 안에 객관적으로 확인할 수 있는 조건을 1–2개 적어주세요."

**Set-level (finalize)**

- "현재 **{N}**개 하위 Request 총 공수 **{X}일**. Appetite 예산 **{Y}일** 대비 **{여유 Z일/초과 W일}**."
- "핵심 흐름 단계 중 매핑되지 않은 항목: **{list}**. 의도적 제외인가요?"
- "하위 Request 간 의존성이 **{N}개** 감지되었습니다. 순차 파이프라인이라면 병합을 고려하세요."
- "Rabbit Hole **'{text}'**과 유사한 후보가 보입니다. 파생이 아니라 경고로 취급해야 합니다."

**Anti-pattern probes**

- "이 후보의 제목이 카테고리(명사구)처럼 보입니다. 구체적 결과물로 바꿀 수 있나요?"
- "후보 #{A}와 #{B}가 내용이 비슷합니다. 하나로 합치거나 경계를 명확히."
- "이 후보는 기술적 리팩터링처럼 보입니다. 어떤 사용자 가치와 연결되나요? 아니면 Spec의 task로 미룰까요?"

**Phase 4: Write**

- "**{N}개** 하위 Request를 Notion Requests DB에 생성합니다. 모두 부모 Trigger에 연결됩니다. 진행할까요?"
- "생성 후에도 언제든 재분해 가능합니다. 기존 하위는 유지/병합/교체 중 선택."

**Abort**

- "반복 3회에도 확정된 하위 Request가 없습니다. Trigger 자체의 구체성을 점검하는 것이 더 빠를 수 있습니다. 중단할까요?"

## Error Handling

- **Notion MCP not connected** → stop at Prerequisites.
- **Trigger URL/ID invalid** → ask user to re-supply.
- **Fat Marker Sketch empty** → stop at Phase 0.2, instruct to complete Trigger.
- **AI proposes 0 candidates** → halt Phase 2, surface "분해 실패: Fat Marker Sketch에서 핵심 흐름을 찾을 수 없습니다. Trigger를 더 구체화해주세요."
- **AI proposes >10 candidates** → AI must self-trim to 10 max by grouping. If still 10+, skill keeps top 10 by size (largest first) and warns: "AI가 과다 분해했습니다. 상위 10개만 표시. Trigger가 실제로는 여러 Trigger로 쪼개져야 할 수 있습니다."
- **User rejects all 3 iterations** → see Phase 3.6 abort options.
- **Existing children collision** → surface side-by-side with skip/replace/rename options.
- **Batch write partial failure** → surface created + failed list; offer retry for failed only.

## Anti-Patterns (do NOT do these)

- **Do not skip Phase 1 strategy.** Jumping straight to candidate generation produces cascade errors (Plan-and-Solve research).
- **Do not silently fix flagged candidates.** Surface all INVEST / anti-pattern flags to user.
- **Do not layer-slice** (frontend/backend/QA). Split by function, not by craft role.
- **Do not emit Rabbit Holes as work.** They are warnings.
- **Do not create sub-Request-of-sub-Request.** Flat structure only.
- **Do not set `상태` on child Requests.** Let default "미할당" apply.
- **Do not set `출처` on child Requests.** 출처 is for raw intake only; sub-Requests inherit from Trigger context (its Source lives on Trigger itself, not duplicated).
- **Do not generate candidates before user approves strategy.** Strategy gate is load-bearing.

## Principles Summary

The four load-bearing ideas:

1. **Decompose along functional paths** (Shape Up + SPIDR "P"). Fat Marker Sketch core flow is the primary splitting axis.
2. **Sub-Requests are intake-level, not spec-level.** INVEST at story granularity (1–5 days), lightweight 5-section body, acceptance _hints_ not criteria.
3. **Plan-and-Solve discipline.** AI writes strategy (Phase 1) and self-critiques (Phase 2.5) before human review.
4. **HITL with forcing functions, not ceremony.** Single approval gate, set-level validators (coverage / appetite / no-go / independence), concrete Korean-language probes that make evasion obvious.

Without Parts 2, 6, 8 of this design in live operation, the skill degenerates into "AI generates a list and you click OK": the theater outcome the team explicitly rejected.
