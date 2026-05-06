---
name: write-product-steering
description: Writes a Product Requirements Document (PRD) section-by-section through interactive Q&A, designed to surface decisions that get expensive when discovered late (pricing, multi-tenancy, i18n, audit, permissions). Trigger whenever the user mentions PRD, 기획서, 요구사항 문서, 제품 기획, 프로덕트 스펙 — and also when they describe wanting to plan out a new product or feature in writing, even without naming the artifact. Use for any feature serious enough to warrant a written spec, not for one-line memos.
---

# Write PRD

Author a Product Requirements Document by walking the user through a 9-section template, one section at a time. The skill's primary job is to *surface decisions that are cheap to make now and expensive to discover later* — pricing model, multi-tenancy, i18n boundaries, audit requirements, permission edges. The PRD itself is a side effect; the conversation is the deliverable.

## When to use

- User starts planning a new product, feature, or service and the artifact is intended to be substantive (not a one-line idea).
- User says "PRD 만들어줘", "기획서 정리", "요구사항 문서", "제품 기획", "프로덕트 스펙 작성", or describes wanting a written specification.
- User wants to *re-author* an existing PRD section by section (revision flow).
- User has interview notes, meeting transcripts, or pitch decks and wants them turned into a structured PRD.

## When NOT to use

- One-line memos or simple feature requests → use a Request artifact instead.
- Spec-level work (the executable spec handed to a coding agent) → use **write-sdlc-spec**.
- Initiative-level bets (multi-week strategic) → use **write-sdlc-trigger**.

## Note on examples

Every concrete identifier in this skill's references and examples (domain names, product names, feature names, role names) is illustrative only. When running the skill, never copy example identifiers into the user-facing prompt or the PRD body — always substitute real values from the user's project context. The examples in `PRD_TEMPLATE.md` exist to clarify shape, not content.

## Reference resources

| Path | Purpose |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/skills/write-prd/references/PRD_TEMPLATE.md` | Canonical 9-section template; copied as the working file at start |

## Expensive-late decision categories (default surface targets)

The skill's primary value is *forcing function* for decisions that are cheap to make in writing and expensive to retrofit in code. The 빼먹기 쉬운 결정 점검 blocks embedded in `PRD_TEMPLATE.md` cover section-specific items, but the skill should also actively surface these category clusters across sections, even when the template doesn't explicitly prompt them.

**Tier 1 — Universal (B2B SaaS core)**

| Category | Why it gets expensive late |
|---|---|
| Pricing model | Migrating billing logic post-launch breaks revenue continuity and existing contracts |
| Multi-tenancy / data isolation | Retrofitting tenant boundaries requires data backfill and an access-control rewrite |
| Internationalization (system / admin / user content) | i18n added later forces schema changes for every translatable column |
| Audit and logging | Regulatory or forensic gaps cannot be filled retroactively for past events |
| Permissions and role boundaries | Permission-model changes ripple through every authorization check in the code |

**Tier 2 — Domain-specific (raise when the user's domain matches)**

| Category | Surface when |
|---|---|
| Scalability ceilings (load profile, hot-path performance) | Public-facing product, expected traffic spike, or concurrency-sensitive workflow |
| Data residency and retention | Healthcare, finance, EU/regulated jurisdictions, or PII-heavy product |
| Accessibility (WCAG 2.x) | Public-sector, education, or any product with statutory accessibility obligations |
| Security and encryption (PII / threat model) | Handling sensitive data, payment, identity, or attack-surface-relevant features |

When Section 0.1 source materials or initial Q&A reveals the user's domain, raise the relevant Tier 2 categories to first-class status alongside Tier 1. If the user's product genuinely doesn't match Tier 1 (e.g., a single-tenant internal tool with no external-facing pricing surface), demote those items to "confirm not applicable" rather than silently dropping them.

Do not dilute Tier 1 by mixing in Tier 2 items the user's domain doesn't match. The forcing function works only when each category is plausibly relevant to the product at hand.

## Workflow Overview

| Phase | What happens |
|---|---|
| 0. Setup | Resolve source materials, name the file, copy the template |
| 1. Section authoring loop | Walk through 9 sections in recommended order; per-section cycle (draft → critique → revise → confirm) |
| 2. Anchor verification | Verify cross-section consistency anchors as they are written, not at the end |
| 3. Final pass | Consolidate `[미결정] / [가정] / [검증필요]` markers; run 섹션 9.5 checklist; finalize 섹션 1 metadata; decide guide-text disposition |

---

## Phase 0: Setup

### 0.1 Source materials (entry mode)

Open with this question:

> "PRD 작성에 참고할 자료(인터뷰, 회의록, 발표 PPT, 기존 기획 메모 등)가 있으신가요?
> - 있다면: 파일 경로, 인라인 페이스트, URL, Notion 페이지 URL — 어떤 형태든 던져주세요.
> - 없다면: '없음'이라고 알려주세요. 0부터 함께 만들어 가겠습니다."

Resolve materials by type:

- **File path** (`.md`, `.txt`, `.pdf`, `.docx`, …) → Read.
- **Inline paste** → use as-is.
- **Web URL** → WebFetch.
- **Notion page URL/ID** → use the `notion-api` skill's `fetch-page.sh ... --markdown-only`.
- **Audio/video file** → respond: "오디오/영상 파일은 직접 읽을 수 없어요. 텍스트로 변환된 자료를 주시면 사용하겠습니다."

Save the consolidated source as `{SOURCE_CONTEXT}` for the rest of the session. If multiple files are provided, concatenate with clear separators (`--- {filename} ---`).

If the user says '없음' → set `{SOURCE_CONTEXT} = ""` and continue. The two branches differ only in Phase 1.2.

### 0.2 Name the working file

Ask:

> "이번 PRD의 제품/기능 이름을 알려주세요. 파일명에 사용할 거예요. (예: `Project Atlas`, `결제 모듈 v2`)"

Slugify minimally — preserve Korean, replace whitespace with hyphens, strip filesystem-forbidden chars (`/ \ : * ? " < > |`). Then check existence:

```bash
test -f "./{slug}.md" && echo "EXISTS" || echo "OK"
```

If `OK`:

```bash
cp "${CLAUDE_PLUGIN_ROOT}/skills/write-prd/reference/PRD_TEMPLATE.md" "./{slug}.md"
```

If `EXISTS`, ask:

> "이미 `./{slug}.md` 파일이 있어요. 어떻게 할까요?
> (a) 덮어쓴다 — 기존 내용 사라집니다
> (b) 다른 이름으로 — 새 이름 알려주세요
> (c) 이어서 작성한다 — 기존 파일을 그대로 두고 비어있는 섹션부터 채워나갑니다"

Confirm to user:

> "`./{slug}.md` 파일을 준비했어요. 이 파일을 섹션 단위로 함께 채워나갑니다."

Save the working path as `{PRD_FILE}`.

### 0.3 Announce the recommended order

> "권장 작성 순서는 다음과 같습니다:
> **2 (배경/문제) → 3 (목표/지표) → 4 (사용자) → 6 (시나리오) → 5 (UC) → 7 (IA/화면) → 8 (Epic/Feature) → 9 (범위/일정) → 1 (메타데이터)**
>
> 문제 정의 → 측정 가능한 목표 → 사용자·시나리오 → 구현 스펙 순. 섹션 3 목표를 섹션 8 Epic 이전에 두어 *피처에서 목표를 역도출하는* feature-factory 위험을 구조적으로 제거하고, 섹션 2 문제 정의가 섹션 3 목표 이전에 와서 *문제 없는 목표* 함정도 피합니다.
>
> 시작할까요? (default: 섹션 2부터)"

If the user requests a *different* custom order → follow, but flag any anchor risks per Phase 2 *before* starting each section. **If the custom order places Section 3 after Section 8** → activate the goal-laundering guard in Phase 2.4.

---

## Phase 1: Section Authoring Loop

For each section in order, run this cycle. Do NOT advance until the confirmation phrase is received.

### 1.1 Open the section

- Open `{PRD_FILE}` and locate the target section's heading.
- Read the section's existing template content (intro, guide text, 빼먹기 쉬운 결정 점검 block, placeholders).
- Announce: "지금부터 **섹션 X — {section title}**을 작성합니다."

### 1.2 Draft (or question pack)

Branch on `{SOURCE_CONTEXT}`:

**If source material exists** → Extract the section-relevant content from `{SOURCE_CONTEXT}`. Produce a draft for the section's placeholders. Where the source is silent on a required field, insert a marker (`[미결정: …]` or `[가정: … / 검증자 / 시한]`) — never invent.

**If no source material** → Ask the user the section's core questions as a focused pack of 3–5 questions max (the template already enumerates these as *결정에 필요한 입력*). Capture answers, then produce the draft.

Show the draft to the user inline (in the chat), not yet written to file.

### 1.3 Critique (free-form)

Ask:

> "이 초안을 검토해 주세요. 자유롭게 비판/보강 의견을 주시면 됩니다."

Wait for the user's free-form critique. They may reject specific lines, demand rewrites, add new sub-points, or catch domain-specific wrongness. Do not impose a structured rubric — let them speak in their own terms.

### 1.4 Revise

Apply the critique. Show the revised draft. Loop back to 1.3 until the user confirms.

### 1.5 Section-end "빼먹기 쉬운 결정" check

Before requesting confirmation, walk the user through this section's *빼먹기 쉬운 결정 점검* block (already embedded in the template — for 섹션 2 it's 섹션 2.4, for 섹션 3 it's 섹션 3.5, etc.). For each item:

- If the draft already covers it → mark as 통과.
- If not covered but answerable now → ask the user, fill in.
- If not answerable now → insert a marker (`[미결정: 결정자 / 시한]` or `[가정: … / 검증자 / 시한]`).

Surface a short summary:

> "섹션 X의 빼먹기 점검 결과:
> - 통과: {N}건
> - 마커로 보존: {M}건 ({한 줄 요약})"

### 1.6 Confirmation

Ask:

> "섹션 X를 이 내용으로 확정할까요? '확정' 또는 '승인'이라고 말씀해 주시면 파일에 반영하고 다음 섹션으로 넘어갑니다."

Confirmation phrases recognized: `"확정"`, `"승인"`. Anything else → continue at 1.3 with the user's input as new critique.

On confirmation:
- Write the section content into `{PRD_FILE}` via Edit (replace placeholders, preserve guide text and 점검 block — those will be revisited in Phase 3).
- Announce: "섹션 X 확정했어요. 다음은 섹션 Y."
- Move to the next section in the agreed order.

---

## Phase 2: Cross-Section Anchor Verification

These anchors must hold whenever the related sections are both populated. Verify *as you go*, not at the end. When an anchor is broken, surface it explicitly to the user — never silently reconcile.

### 2.1 Section 5 ↔ Section 6 ping-pong (Use Cases ↔ Scenarios)

Whenever a scenario in Section 6 mentions a user action, check that a corresponding Use Case exists in Section 5.3. If missing:

- Update Section 5 with the missing UC.
- Tell the user: "섹션 6에서 발견된 행위가 섹션 5에 누락. 5에 UC '{X}'를 추가했어요."

Mirror direction (Section 5 → Section 6): a UC with no scenario coverage → flag for Section 6.

### 2.2 섹션 6.5 (시나리오 x UC matrix)

After Section 5 and Section 6 are both confirmed, populate Section 6.5. If any scenario has no UC reference, or any UC has no scenario reference → flag and decide with user (add UC, drop UC, or document why isolated).

### 2.3 Section 8.3 (Feature x CRUD matrix)

After Section 8 is confirmed, populate the Feature x CRUD matrix. If the unknown-cell ratio exceeds 30% → flag as a structural concern:

> "섹션 8.3 매트릭스의 ?셀 비중이 {X}%로 임계(30%)를 넘었어요. Feature 정의가 충분히 결정되지 않은 신호일 수 있습니다. 작성 전 한 번 더 짚어볼까요?"

### 2.4 Section 8.1 ↔ Section 3.2 (Epics ↔ Goals)

Each Epic in Section 8.1 must trace to at least one product goal in Section 3.2. If any Epic has no goal trace:

> "Epic '{X}'가 어떤 목표에 기여하는지 불명확. 목표 매핑이 없으면 Epic 정당성이 흔들립니다. 추가하거나 Epic을 다시 정의하거나 드랍하는 방향 중 어떻게 할까요?"

**Goal-laundering guard (custom-order only):** The recommended order writes Section 3 before Section 8, structurally preventing goals from being reverse-derived from Epics. This guard activates *only* when the user chose a custom order in which Section 3 is authored *after* Section 8 — in that case the existence-based trace check above cannot detect reverse-derived goals, and only the user can confirm independence:

> "방금 작성한 섹션 3 목표들은 섹션 8 Epic 리스트에서 역으로 도출된 게 아니라, 독립적으로 식별된 측정 가능한 결과인가요?"

If the user confirms reverse-derivation for any goal → insert `[가정: 이 목표는 섹션 8 Epic에서 역으로 도출 / {validator} / {YYYY-MM-DD}]` next to that goal and roll up to 섹션 9.4 in Phase 3.

### 2.5 Section 6 ↔ Section 7 ping-pong (Scenarios ↔ Screen flow)

Same pattern as 2.1: a screen flow without a covering scenario → flag and reconcile.

---

## Phase 3: Final Pass

After all 9 sections are individually confirmed, run the final pass.

### 3.1 Marker consolidation (→ Section 9.4)

Search `{PRD_FILE}` for all markers:

```bash
grep -n -E '\[미결정:|\[가정:|\[검증필요:' "{PRD_FILE}"
```

Consolidate into Section 9.4's four sub-tables:
- 섹션 9.4.1 가정 (Assumptions)
- 섹션 9.4.2 미결정 (Open Decisions)
- 섹션 9.4.3 미해결 질문 (Open Questions)
- 섹션 9.4.4 검증 필요 (Verification Needed)

Show the user the consolidated tables and ask:

> "마커 {N}개를 섹션 9.4에 통합했어요. 각 항목의 결정자/시한이 비어있는 게 {M}개 있어요. 지금 채울 수 있는 것 있을까요?"

Walk through each empty owner/deadline. Fill what's possible.

### 3.2 섹션 9.5 PRD 정합성 체크리스트

Walk through 섹션 9.5 line by line with the user. Each item gets 통과 / 미통과. For any 미통과:

- Identify which section needs revision.
- Decide together: revise now, or document why deferred.

### 3.3 Finalize Section 1 (metadata)

Now that the rest is locked, fill Section 1:

- 섹션 1.1 문서 정보: today's date, author, version (default `v0.1`).
- 섹션 1.2 변경 이력: first row = `v0.1 — 초안 — {YYYY-MM-DD}`.
- 섹션 1.3 빼먹기 점검: meta-level questions (배포/공유 범위, 의사결정자 명시성).

Ask:

> "버전을 v0.1로 시작할까요, 아니면 다른 버전 번호를 쓰고 싶으신가요?"

### 3.4 Guide-text disposition

Ask:

> "PRD_TEMPLATE.md에서 가져온 *가이드 텍스트*(섹션 인트로, 예시, 빼먹기 점검 블록 등)를 어떻게 할까요?
> - (a) 그대로 둔다 — 살아있는 문서로 사용 (다음 리뷰 때 재검토에 유용)
> - (b) 가이드 텍스트만 제거하고 사용자 컨텐츠만 남긴다 — 깔끔한 산출물
> - (c) 점검 블록은 남기고 인트로/예시만 제거 — 균형형"

Apply the user's choice via surgical Edit operations. Do NOT use `sed -i` for this — preserve the user's content exactly.

### 3.5 Final report

> "PRD 초안이 `{PRD_FILE}`에 저장됐어요.
> - 섹션 9개 모두 확정
> - 미결정 마커 {N}개 (섹션 9.4 통합)
> - 정합성 체크리스트 통과
>
> 다음 단계는 노션 업로드인데, 별도로 진행하시겠어요?"

---

## Markers (강제 사용 규칙)

The skill MUST use these markers anytime a fact, owner, or deadline is uncertain. Never silently invent values.

| Marker | Use when | Format |
|---|---|---|
| `[미결정: 결정자 / 시한]` | Decision exists but has no answer yet | `[미결정: {decision_owner} / {YYYY-MM-DD}]` |
| `[가정: <statement> / 검증자 / 시한]` | Proceeding under an assumption that needs validation | `[가정: <one-line statement> / {validator} / {YYYY-MM-DD}]` |
| `[검증필요: 검증자 / 시한]` | A claim needs external verification (data, market fact) | `[검증필요: {validator} / {YYYY-MM-DD}]` |

Every marker that survives the section eventually rolls up to Section 9.4 in Phase 3.

Rationale: the user's primary value from this skill is *forcing function for late-discovered decisions*. Markers are how that forcing function survives the section boundary instead of getting smoothed over into prose.

---

## Authoring Rules

- **Output language**: Korean by default. Section headings stay as defined in `PRD_TEMPLATE.md`.
- **Critique format**: free-form. Do not impose a structured rubric on the user.
- **Confirmation phrases**: `"확정"`, `"승인"`. Anything else continues the current section's revise loop.
- **Never advance unilaterally**: confirmation must come from the user, not be inferred from silence or partial agreement.
- **Never invent facts**: if `{SOURCE_CONTEXT}` is silent and the user has not answered, use a marker.
- **Examples are illustrative**: when the template embeds a SaaS / B2B / dental example, *do not* inherit those identifiers into the user's PRD. Substitute the user's actual domain.
- **Live edits, not rewrites**: when revising after critique, use `Edit` for surgical changes — do not regenerate the whole section from scratch unless the user explicitly asks for a clean rewrite.

---

## Error Handling

- **Source file missing/unreadable** → tell the user, ask for an alternative or proceed with `{SOURCE_CONTEXT} = ""`.
- **`{PRD_FILE}` already exists at cwd** → use the (a)/(b)/(c) prompt in Section 0.2.
- **Template file missing** at `${CLAUDE_PLUGIN_ROOT}/skills/write-prd/reference/PRD_TEMPLATE.md` → stop and surface: "`PRD_TEMPLATE.md`를 찾을 수 없어요. 플러그인 설치 상태를 확인해 주세요."
- **Anchor verification fails repeatedly** → after 2 unresolved flags on the same anchor, save state, surface to user: "이 정합성 닻은 추가 결정이 필요해 보입니다. 잠시 멈추고 결정자에게 확인 후 재개하시는 게 좋을 것 같아요."
- **User wants to pause mid-section** → write current draft to `{PRD_FILE}` with a `<!-- DRAFT: section X in progress -->` marker, save current state in chat, allow resume next session.

---

## Anti-Patterns (DO NOT do these)

- **Do not write all sections in one shot.** The forcing function *is* the per-section cycle.
- **Do not skip 빼먹기 점검 blocks.** The whole point is surfacing decisions before solution stage.
- **Do not infer confirmation.** "응", "OK", "그래" alone are not enough — wait for `"확정"` or `"승인"`.
- **Do not overwrite the user's free-form critique with a fixed template.** Let them speak in their own terms.
- **Do not promote `[가정]` to fact silently.** If the user accepts an assumption, leave the marker — its job is to track that an external check is owed.
- **Do not strip guide text without asking.** Section 3.4 is the only place where guide-text disposition is decided.
- **Do not borrow concrete domain examples** from the reference template (specific company names, real product names from the user's industry). The template's examples are SaaS-generic for that reason.
- **Do not skip the recommended-order announcement (Section 0.3).** The order encodes *which decisions depend on which* — silent default ordering loses that signal.
