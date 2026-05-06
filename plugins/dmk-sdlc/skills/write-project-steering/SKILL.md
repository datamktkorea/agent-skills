---
name: write-project-steering
description: Authors a project's internal Single Source of Truth (SSOT) by walking the user through a section-by-section interview, then writes the result into the corresponding Project DB page body in Notion. The skill auto-detects the project type (product / contract / public) from the Project DB `type` Select property and loads the matching section template. Trigger when the user mentions Project Steering, 프로덕트 헌장/스티어링, Statement of Work, SOW, RFP Response, RFP 응답, 제안서, 사업 수행 계획서, 도메인 용어집, 유비쿼터스 언어, 비즈니스 규칙 정리, 멀티테넌시·i18n·권한 모델 결정, monetization gating rules — and also when they describe wanting to lock down time-invariant product knowledge that AI coding sessions will fetch.
---

# Write Project Steering

Authors the **internal Single Source of Truth (SSOT)** for a project, written directly into the project's page body in the Notion Projects DB. The skill is the producer side of the SSOT contract: every Phase-2 coding session fetches this body verbatim as authoritative context, so the document must contain only *time-invariant, decision-grade* knowledge — not roadmap, not metrics, not active risks.

The forcing function is the per-section interview. The conversation surfaces decisions that are cheap now and expensive to retrofit (multi-tenancy, i18n, permissions, monetization gating). The document is the side effect; the conversation is the deliverable.

## What this skill is, and what it is not

| Layer | Time-bound? | Where it lives | Skill |
|---|---|---|---|
| Project Steering / SOW / RFP Response | **No — invariants only** | Project DB page body | **this skill** |
| Initiative (2–6 week bet) | Yes — bet horizon | Initiatives DB | `write-sdlc-initiative` |
| Spec (executable unit) | Yes — sprint horizon | Specs DB | `write-sdlc-spec` |
| Active risks, open decisions, success metrics, milestones | Yes | Initiative body | `write-sdlc-initiative` |

**Hard rule.** Any sentence with a date, a metric target, an open question, or "TBD" does not belong in this document. If the user wants to capture those, redirect them to `write-sdlc-initiative`.

## When to use

- Standing up a new project's SSOT for the first time.
- Re-authoring an existing Project Steering / SOW / RFP Response page section by section (revision flow).
- Converting interview notes, kickoff transcripts, or pitch/RFP materials into a structured SSOT.
- User mentions: Project Steering, 프로덕트 헌장, SOW, Statement of Work, 제안서, 사업 수행 계획서, RFP 응답, 도메인 용어집, 비즈니스 규칙, 멀티테넌시 결정, i18n 결정, 권한 모델, 가격 게이팅 규칙.

## When NOT to use

- One-line task or feature request → `capture-request`.
- 2–6 week bet with success metrics → `write-sdlc-initiative`.
- Executable spec for a coding agent → `write-sdlc-spec`.
- Customer-facing deliverable that lives outside Notion as a final external artifact (e.g., signed PDF SOW) → out of scope; the Notion-side SSOT may inform that artifact, but rendering and delivery are not this skill's job.

## Note on examples

Every concrete identifier in this skill's text and in the reference templates (domain names, product names, role names, regulator names, agency names) is illustrative. When running the skill, never copy example identifiers into the user-facing prompt or the document body — substitute real values from the project's context.

## Reference resources

| Path | Purpose |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/skills/write-project-steering/references/product.md` | Section template for `type=product` (자사 SaaS / 제품) — output: *Project Steering* |
| `${CLAUDE_PLUGIN_ROOT}/skills/write-project-steering/references/contract.md` | Section template for `type=contract` (수탁) — output: *Statement of Work (SOW)* |
| `${CLAUDE_PLUGIN_ROOT}/skills/write-project-steering/references/public.md` | Section template for `type=public` (공공) — output: *RFP Response* |
| `${CLAUDE_PLUGIN_ROOT}/skills/write-project-steering/references/legacy/PRD_TEMPLATE.md` | Pre-A-alignment 9-section external PRD template; retained for the future external-PRD track (not used by this skill) |

## Workflow Overview

| Phase | What happens |
|---|---|
| 0. Setup | Resolve the target Project DB page, detect branch, load source materials, load the matching section template |
| 1. Section authoring loop | Walk through the loaded sections in the recommended order; per-section cycle (draft → critique → revise → confirm) |
| 2. Cross-section consistency | As each section lands, verify domain/glossary/business-rule anchors against earlier sections |
| 3. Final pass | Push resolved invariants into the Project DB page body; route any open decisions or active risks out of Steering and into the appropriate Initiative |

---

## Phase 0: Setup

### 0.1 Resolve the target Project DB page

Open with this question:

> "어느 Project의 Steering 문서를 작성/갱신할까요? Project DB의 페이지 URL이나 제목을 알려주세요."

Resolve:

- **Notion page URL or ID** → use the `notion-api` skill: fetch the page (markdown body) and read its properties for the `type` Select.
- **Title only** → search the Projects DB by title via `notion-api`.
- **None / new project** → ask whether the user will create a new Project DB page first, or whether to abort and return after creation. Do not auto-create.

Save:
- `{PROJECT_PAGE_ID}` — Notion page ID
- `{PROJECT_TITLE}` — page title
- `{EXISTING_BODY}` — current page body as markdown (may be empty)
- `{PROJECT_TYPE_RAW}` — value of the `type` Select property (may be unset)

### 0.2 Detect branch (project type)

Branch logic:

1. If `{PROJECT_TYPE_RAW}` is one of `product`, `contract`, `public` → set `{BRANCH} = {PROJECT_TYPE_RAW}`.
2. Otherwise (unset / unrecognized) → ask the user:

   > "이 프로젝트는 어느 분기인가요?
   > (a) **product** — 자사 SaaS·내부 제품. 산출물 명: *Project Steering*
   > (b) **contract** — 수탁·고객 발주. 산출물 명: *Statement of Work (SOW)*
   > (c) **public** — 공공·RFP 대응. 산출물 명: *RFP Response*"

   Capture as `{BRANCH}`. Do NOT write back to the Notion `type` property automatically — tell the user to set it themselves so the next session auto-detects:

   > "다음 세션을 위해 Project DB의 `type` Select 속성을 `{BRANCH}`로 설정해 두시면 자동 감지됩니다."

3. Load the matching template:

   ```
   {TEMPLATE_PATH} = ${CLAUDE_PLUGIN_ROOT}/skills/write-project-steering/references/{BRANCH}.md
   ```

   Read `{TEMPLATE_PATH}` once. It contains the full section list, per-section *결정에 필요한 입력* question packs, *빼먹기 쉬운 결정 점검* blocks, and the recommended section order for that branch. Do NOT paste the template wholesale into chat — surface one section at a time.

Announce:

> "분기: `{BRANCH}` → 산출물 명칭: `{Project Steering | Statement of Work (SOW) | RFP Response}`. 이 명칭을 본문 1행 헤더로 사용합니다."

### 0.3 Source materials

Ask:

> "작성에 참고할 자료(인터뷰, 회의록, 발표 PPT, 기존 메모, RFP 본문 등)가 있으신가요?
> - 있다면: 파일 경로, 인라인 페이스트, URL, Notion 페이지 URL — 어떤 형태든 알려주세요.
> - 없다면: '없음'이라고 알려주세요. 0부터 함께 만듭니다."

Resolve by type:

- **File path** (`.md`, `.txt`, `.pdf`, `.docx`) → Read.
- **Inline paste** → use as-is.
- **Web URL** → WebFetch.
- **Notion page URL/ID** → `notion-api` fetch with markdown-only output.
- **Audio/video** → respond: "오디오/영상은 직접 읽을 수 없어요. 텍스트로 변환된 자료를 주세요."

Concatenate into `{SOURCE_CONTEXT}` with `--- {filename or url} ---` separators. If '없음' → `{SOURCE_CONTEXT} = ""`.

### 0.4 Existing body disposition

If `{EXISTING_BODY}` is non-empty, ask:

> "이 페이지에 이미 본문이 약 {N}자 있습니다. 어떻게 할까요?
> (a) 처음부터 다시 — 기존 본문은 백업한 뒤 폐기
> (b) 비어있는 섹션부터 이어서 — 기존 섹션은 검토 후 통과 처리
> (c) 섹션별로 점검하며 갱신 — 한 섹션씩 기존 내용을 보고 결정"

If (a) → save `{EXISTING_BODY}` to `./.steering-backup-{YYYYMMDD-HHMM}.md` before clearing.

### 0.5 Announce the section order

Read the recommended ordering from `{TEMPLATE_PATH}`. Announce:

> "분기 `{BRANCH}`의 권장 작성 순서:
> {ordered list from template}
>
> 이 순서는 *어느 결정이 어느 결정에 의존하는지*를 인코딩합니다. 다른 순서를 원하시면 알려주세요. 시작할까요? (default: 첫 섹션부터)"

If the user requests a custom order, accept but flag any anchor risks per Phase 2 *before* starting each section.

---

## Phase 1: Section Authoring Loop

For each section in agreed order, run this cycle. Do NOT advance until confirmation.

### 1.1 Open the section

- Locate the section in `{TEMPLATE_PATH}` and read its scaffold (heading, intro, *결정에 필요한 입력* questions, *빼먹기 쉬운 결정 점검* block).
- Announce: "지금부터 **{section title}**을 작성합니다."

### 1.2 Draft (or question pack)

Branch on `{SOURCE_CONTEXT}`:

**Source exists** → extract section-relevant content. Produce a draft for the section's placeholders. Where the source is silent on a required field → mark `[가정: <statement> / 검증자 / 시한]`. **Never use `[미결정: ...]` markers in this skill** — Steering does not host open decisions; if a decision is unmade, route to Initiative instead (see Phase 1.5 and Phase 3.1).

**No source** → ask the section's *결정에 필요한 입력* as a focused pack of 3–5 questions max. Capture answers, then draft.

Show the draft inline (chat), not yet pushed to Notion.

### 1.3 Critique (free-form)

> "이 초안을 검토해 주세요. 자유롭게 비판/보강 의견을 주시면 됩니다."

Wait for free-form critique. Do not impose a structured rubric.

### 1.4 Revise

Apply the critique. Show the revised draft. Loop 1.3 until the user confirms.

### 1.5 Section-end "빼먹기 쉬운 결정" check

Walk the user through this section's *빼먹기 쉬운 결정 점검* block from `{TEMPLATE_PATH}`. For each item:

- Already covered → 통과.
- Answerable now → ask, fill in.
- Not answerable now → **do NOT add a `[미결정]` to Steering.** Surface to user:

  > "'{item}'은 아직 결정되지 않았네요. 이건 Steering이 아닌 Initiative에서 다뤄야 합니다. 어느 Initiative로 보낼지 알려주세요. (적합한 Initiative가 아직 없으면 'later'라고 답해주세요. 본 세션 종료 시 한 번에 정리합니다.)"

  Capture as `{PENDING_DECISIONS} += {item, target_initiative_or_later}`.

Surface a short summary:

> "{section} 빼먹기 점검 결과:
> - 통과: {N}건
> - Initiative로 라우팅: {M}건"

### 1.6 Confirmation

> "{section}을 이 내용으로 확정할까요? '확정' 또는 '승인'이면 다음 섹션으로 넘어갑니다."

Confirmation phrases recognized: `"확정"`, `"승인"`. Anything else → continue at 1.3.

On confirmation:
- Append the section content to a session-local working buffer `{WORKING_BODY}`. **Do not push to Notion section-by-section** — push once at Phase 3.4 to avoid header fragmentation.
- Announce: "{section} 확정. 다음은 {next section}."

---

## Phase 2: Cross-Section Consistency

These anchors must hold whenever the related sections are both populated. Verify *as you go*, not at the end. When an anchor breaks, surface explicitly — never silently reconcile.

### 2.1 Glossary ↔ everywhere (all branches)

When a section introduces a domain noun absent from the Glossary, add it (or flag for the Glossary section if not yet authored). When the Glossary section is written, scan all earlier confirmed sections for terms used but undefined.

### 2.2 Business Rules ↔ Permissions / Monetization (product branch)

When a Business Rule references a role or a tier, reconcile against the Permissions and Monetization sections. Tier-gated rules must match Monetization access-tier definitions; role-gated rules must match the Permissions role list.

### 2.3 Non-goals ↔ Vision (product branch)

Each Non-goal must be defensible against the Vision. A Non-goal that contradicts the Vision is either vision drift or mis-scoped — surface and force a choice.

### 2.4 Compliance Matrix ↔ RFP Requirement Traceability (public branch)

Every requirement in the RFP Requirement Traceability section must have a corresponding row in the Compliance Matrix.

### 2.5 SOW Scope ↔ Acceptance Criteria (contract branch)

Each in-scope deliverable must have at least one Acceptance Criterion. Each Acceptance Criterion must trace back to a scope item.

(Branch-specific anchors with finer detail may live in `references/{branch}.md`.)

---

## Phase 3: Final Pass

After all sections are individually confirmed, run the final pass.

### 3.1 Route open decisions out of Steering

If `{PENDING_DECISIONS}` is non-empty:

> "Steering에서 빠지고 Initiative로 보낼 미결정 {N}건이 있습니다:
> {numbered list with target_initiative_or_later}
>
> 'later' 항목들은 어느 Initiative로 보낼까요? 적합한 Initiative가 아직 없으면 '신규 Initiative 필요'라고 답해주세요. 그 항목은 후속 작업으로 표시합니다."

For each item routed to an existing Initiative:
- Use `notion-api` to append a `Risks/Assumptions` block (markdown bullet form) to that Initiative's page body. Do not auto-create new Initiatives — that is `write-sdlc-initiative`'s job.

For items marked '신규 Initiative 필요':
- Hold them in `{FOLLOWUP_INITIATIVES}` for the final report. Do not act.

### 3.2 Verify no time-bound content leaked into Steering

Write `{WORKING_BODY}` to a temp file and scan:

```bash
TMP=$(mktemp) && printf '%s' "{WORKING_BODY}" > "$TMP" && \
  grep -n -E '\b(202[0-9]|203[0-9])-[01][0-9]-[0-3][0-9]\b|\bTBD\b|미정|by Q[1-4]|\bdeadline\b|일정|마일스톤' "$TMP" || true
```

Any hit → surface to the user:

> "Steering에 시간 의존 내용으로 보이는 줄이 있어요:
> {line — content}
>
> 이건 Initiative로 옮길까요, 아니면 Steering에 남길 정당한 이유가 있을까요?"

(`[가정: ... / 검증자 / YYYY-MM-DD]` 형식의 정당한 시한은 통과 처리한다.)

### 3.3 Verify glossary completeness

Surface domain nouns mentioned in the body but absent from the Glossary section. For each missing term: ask the user to add a one-line definition, or confirm omission with reason.

### 3.4 Push to Notion

Once consistency is clean, push `{WORKING_BODY}` to Notion using the `notion-api` skill's page-content update flow. Use `replace_content` (full rewrite) — Steering is a single coherent document and section-level partial updates fragment headers.

Confirm success before announcing.

### 3.5 Final report

> "Steering 본문이 `{PROJECT_TITLE}` Project DB 페이지에 반영됐어요.
> - 분기: `{BRANCH}` ({artifact name})
> - 섹션 {N}개 모두 확정
> - Initiative로 라우팅한 미결정: {M}건
> - 신규 Initiative가 필요한 항목: {K}건 — `write-sdlc-initiative`로 후속 작성하세요.
>
> 이 페이지는 이제부터 코딩 세션 시작 시 fetch되는 SSOT입니다."

---

## Markers (강제 사용 규칙)

This skill uses **only one marker type**, sparingly:

| Marker | Use when | Format |
|---|---|---|
| `[가정: <statement> / 검증자 / 시한]` | Source material implies a positive claim that needs explicit human confirmation, but is not yet contradicted | `[가정: <one-line> / {validator} / {YYYY-MM-DD}]` |

**Banned in Steering body:**
- `[미결정: ...]` — Steering does not host open decisions. Route to Initiative.
- `[검증필요: ...]` — same reason; Steering hosts only resolved invariants.
- Bare `TBD`, `?`, `미정`.

Rationale: AI coding sessions treat Steering as authoritative. Any unresolved marker in Steering will be silently filled in by the agent's prior. A `[가정]` is acceptable only because it is a *positive claim with a named validator on the hook*, not an empty slot.

---

## Authoring Rules

- **Output language**: Korean by default. Section headings follow the loaded `{TEMPLATE_PATH}`.
- **Critique format**: free-form. Do not impose a structured rubric.
- **Confirmation phrases**: `"확정"`, `"승인"`. Silence ≠ confirmation.
- **Never invent facts**: silent source + no user answer → ask, or route to Initiative. Never auto-fill.
- **Examples are illustrative**: never inherit reference-template example identifiers into the user's document. Substitute real project values.
- **Live edits, not rewrites**: when revising after critique, surgical changes — do not regenerate the whole section unless the user explicitly asks.
- **One push, not many**: write to Notion once at Phase 3.4, not per section.

---

## Error Handling

- **Project page not found** → ask the user for URL/ID directly. Do not auto-create.
- **Branch detection ambiguous** (e.g., `type` set to a value outside the three) → ask user; do not guess.
- **Template file missing** at `${CLAUDE_PLUGIN_ROOT}/skills/write-project-steering/references/{branch}.md` → stop and surface: "분기 템플릿을 찾을 수 없어요. 플러그인 설치 상태를 확인해 주세요."
- **Notion push fails** at Phase 3.4 → save `{WORKING_BODY}` to `./.steering-draft-{YYYYMMDD-HHMM}.md` and surface the error. Do not retry blindly.
- **User wants to pause mid-section** → write `{WORKING_BODY}` to `./.steering-draft-{YYYYMMDD-HHMM}.md` with a `<!-- DRAFT: section X in progress -->` marker, save state in chat, allow resume next session.

---

## Anti-Patterns (DO NOT do these)

- **Do not write all sections in one shot.** The forcing function *is* the per-section cycle.
- **Do not skip 빼먹기 점검 blocks.** They are the surfacing mechanism for late-discovered decisions.
- **Do not infer confirmation.** "응", "OK", "그래" alone are not enough.
- **Do not allow `[미결정]` into Steering body.** Route to Initiative instead.
- **Do not include success metrics, milestones, or roadmap content.** Those belong in the Initiative layer.
- **Do not push partial sections to Notion.** One full push at Phase 3.4.
- **Do not borrow concrete domain examples** from reference templates. Substitute project-real values.
- **Do not skip the recommended-order announcement (Phase 0.5).** The order encodes dependency direction; silent default ordering loses that signal.
