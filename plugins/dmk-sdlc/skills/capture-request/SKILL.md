---
name: capture-request
description: Writes a new Request page in Notion's Requests DB from a free-form description, sizing the body to match the actual work. Use when the user wants to formalize a 업무 지시 / 티켓 / 작업 요청 / hand-off — including "업무 지시 써줘", "티켓 작성해줘", "task 만들어줘". Also trigger when the user describes a task to delegate without explicitly asking for a document. Do NOT use for 2–6주 strategic bets (`write-sdlc-initiative`), implementation specs (`write-sdlc-spec`), or meeting notes (`write-meeting-notes`).
---

# Task Writer Skill

A Task is a Request page in Notion's `requests_db`. This skill writes a new Request from a free-form description: it infers a tier (간결/보통/상세) that matches the actual size of the work, drafts a body whose length and structure follow that tier, runs a tier-appropriate quality review, and writes the page via the `notion-api` skill's scripts. Notion is the single source of truth — no local files, no markdown caches.

The reviewer that used to live in `task-reviewer` is fully absorbed here. Quality control is a phase inside the writing flow, not a separate skill.

## When to Use

- The user wants to formalize an assignment or hand-off and writes it as a free-form description.
- The work is bounded enough to be a single Request (i.e., not a multi-week strategic bet, not a full implementation spec).
- The task may be 개발 or 비개발 (지원 / 행정 / 리서치).

## When NOT to Use

- 2–6주짜리 전략적 베팅 → use `write-sdlc-initiative` (an Initiative, not a Request).
- 이미 만들어진 Request에 구현 스펙을 붙여야 함 → use `write-sdlc-spec`.
- 회의록 정리 → use `write-meeting-notes`.
- The user has no concrete description, only a vague "뭔가 정리해줘" — push back and ask what the work actually is before invoking this skill.

## Prerequisites

All Notion access goes through the `notion-api` skill's bash scripts. Its preconditions apply verbatim: `~/.datamktkorea/config.json` with `notion_token` + `notion_dbs` map, `jq` installed, the Integration shared with `requests_db` and `projects_db`. If any `notion-api` script exits with code 2 (precondition failure), surface its stderr hint to the user and stop.

Do not use Notion templates. All content is generated here and written directly via `create-page.sh`.

## Scripts used

Shorthand used throughout this skill. Full signatures and behavior live in `notion-api/SKILL.md`.

| Shorthand        | Resolves to                                                      |
| ---------------- | ---------------------------------------------------------------- |
| `query-db.sh`    | `${CLAUDE_PLUGIN_ROOT}/skills/notion-api/scripts/query-db.sh`    |
| `create-page.sh` | `${CLAUDE_PLUGIN_ROOT}/skills/notion-api/scripts/create-page.sh` |

DB references use config keys: `requests_db`, `projects_db`. Raw UUIDs live only in `~/.datamktkorea/config.json` and the authoritative schema in `notion-api/SKILL.md`.

## Core Principles

1. **Shape matches size.** The single most important rule. A one-paragraph task gets a one-paragraph body. A 7-section template forced onto a 30-minute task is bureaucratic theater that nobody reads. Tier-judgment is a load-bearing AI step, not optional ceremony.

2. **AI infers fast, user confirms minimal.** The legacy 4-field intake (프로젝트/요청자/담당자/마감) is gone. The user dumps a description; the AI extracts everything it can; the user confirms or edits in one consolidated gate. People-properties (요청자/담당자), 작업 기간, 우선순위, 상태 are filled in Notion's UI by the requester — this skill never sets them.

3. **Why is non-negotiable, even at 간결 tier.** If a 담당자 reads the body and cannot tell _why_ the work matters, no amount of detail in _what_ compensates. When the AI cannot extract a Why from the user's dump, it must elicit one through dialogue — never invent a Why, never proceed without one.

4. **Review depth scales with tier.** 간결 skips review (the body is too short to hide problems). 보통 runs an internal review pass and silently revises. 상세 runs an explicit review and shows the summary to the user in the final preview. The web-search currency check fires only when a specific tool / technology is named.

## Note on examples

Concrete identifiers in this skill's Good/Bad blocks (project names, role names, deliverable specifics) are illustrative and exist to teach shape. When running the skill, never copy these into user-facing prompts or Notion bodies — substitute real values from the user's context resolved at runtime.

## Workflow Overview

| Phase                          | What happens                                                                |
| ------------------------------ | --------------------------------------------------------------------------- |
| 0. Intake                      | User dumps description; AI parses; anti-pattern check (Initiative-shaped?)     |
| 1. Project resolution (Gate 1) | Match against `projects_db`; user picks, or marks "없음"                    |
| 2. Classification (Gate 2)     | AI proposes tier + 유형 + 카테고리 + 제목 + 요점; user confirms in one shot |
| 3. Drafting                    | AI writes body per tier rules; for 간결, dialogues if Why is missing        |
| 4. Review (tier-differential)  | 간결: skip · 보통: internal silent revise · 상세: explicit 검토 요약        |
| 5. Final preview (Gate 3)      | Show body + 메타 + (상세 only) 검토 요약; user confirms                     |
| 6. Write to Notion             | `create-page.sh` to `requests_db`; return page URL                          |

## Phase 0: Intake

The user opens with either a one-line ask or a multi-paragraph dump. Read what they wrote and extract:

- A description of what needs to be done (the actual task).
- Mentions of a project name (a string to search `projects_db` against).
- Signals about size: words like "급한 건 아님", "이번 주 안에", "오늘 EOD", named deliverables, scope hints.
- Mentions of tools, technologies, or methodologies (these will trigger the currency check at Phase 4 if applicable).

If the dump is genuinely too thin to proceed (one-line ask with no clue what the actual work is), ask one consolidated probe before continuing. Do not advance to Phase 1 with insufficient signal — that just produces hallucinated Requests.

### Anti-pattern check: Initiative-shaped Request

If the dump looks like a 2–6주 strategic bet — multiple stakeholders, ambiguous outcome, requires DIBB-style framing, scope spans several teams' worth of work — pause and ask:

> "이 작업은 단일 Request보다 큰 베팅으로 보입니다 ({sentence describing why — e.g., '범위가 여러 팀에 걸쳐 있고, 결과물 정의 자체에 합의가 필요해 보임'}). `write-sdlc-initiative`로 이니셔티브 문서를 먼저 만들고, 거기서 분해된 하위 Request들을 채우는 흐름이 더 적절할 수 있습니다. 그래도 단일 Request로 작성할까요?"

If the user confirms 단일 Request, proceed. If they switch, exit this skill and surface `write-sdlc-initiative`.

### Org context check (one-shot, before drafting)

If the body's 요구사항 will likely touch 보안 / 시크릿 / 인증 / 로그·모니터링 / 컴플라이언스, ask once before advancing to Phase 1:

> "팀에 이미 사용 중인 도구나 책임자가 있나요? (예: 시크릿 관리 — {tool}/없음, 보안 — 전담팀/없음(검토자가 곧 의사결정자), 로그·모니터링 — 도입된 스택/없음)"

Pin the answer in §3 as a stated premise ("현재 팀이 {tool}를 사용 중", "별도 보안팀 없음 — 검토자가 의사결정자"). If the user says "없음", record that explicitly in §3 — never silently assume. This gate exists because retrofitting org context after drafting forces a full redraft.

## Phase 1: Project Resolution (Gate 1)

A Request is normally tied to one Project, but 비개발 카테고리(특히 행정·리서치 일부)에는 Project가 없을 수 있다. Handle both cases without forcing a fake match.

### 1.1 Search projects_db

Use the project name (or closest keyword) the user mentioned. Filter out archived projects server-side:

```bash
query-db.sh projects_db --page-size 5 \
  --filter "$(jq -n --arg k "<keyword>" '{
    and: [
      {property:"아카이브", checkbox:{equals:false}},
      {property:"프로젝트명", title:{contains:$k}}
    ]
  }')"
```

Show numbered candidates using `.results[].properties["프로젝트명"].title[0].plain_text`. Save the chosen page's `id` for the relation.

### 1.2 Resolution outcomes

- **1 match, clearly the right one:** confirm in one line ("프로젝트는 `{name}` 맞나요?"). Save id.
- **Multiple matches:** show numbered list, ask user to pick.
- **No match, but the user did mention a project:** ask whether the project name was different ("`{keyword}`에 일치하는 프로젝트가 없습니다. 정확한 프로젝트명을 알려주거나, '없음'으로 진행하실 수 있습니다.")
- **User did not mention a project at all (typical for some 행정/리서치 요청):** ask once: "Project를 연결할까요? (예: 프로젝트명 / 아니면 '없음')". Accept "없음" and proceed with no `Projects DB` relation.

Never invent a project. If unresolved after one clarification, default to "없음" rather than forcing a false relation.

## Phase 2: Classification (Gate 2)

In one consolidated proposal, the AI presents its 1차 판단 for **티어 / 유형 / 카테고리 / 제목 / 요점**. The user accepts, edits any fields, or rewrites the dump.

### 2.1 Tier judgment

| Tier     | Heuristic                                                                         | Body shape                                            |
| -------- | --------------------------------------------------------------------------------- | ----------------------------------------------------- |
| **간결** | 범위·결과물 명확, 의사결정 포인트 없음, 1–3시간 내 처리 가능                      | 1 paragraph, 80–150 words, **Why 강제**               |
| **보통** | 어느 정도 컨텍스트 필요하지만 목표 분명, 자가검증 가능                            | 3 sections (배경 / 결과물 / 완료 기준), 200–350 words |
| **상세** | 모호하거나 의사결정 포인트 다수, 결과물 정의에 합의 필요, 잘못된 방향으로 갈 위험 | 5 필수 + 2 옵셔널 sections, 400–700 words             |

When borderline, prefer the smaller tier — bloat is the failure mode this skill is designed to prevent. Upgrading later is cheap; deflating later is awkward.

### 2.2 유형 inference

Notion `유형 [select]` accepts one of:

- **개발 카테고리:** `기능 추가` (신규 기능) · `기능 변경` (기존 동작의 계약 변경) · `기능 개선` (성능·UX·리팩터 등 비기능적 품질) · `기능 에러` (버그)
- **비개발 카테고리:** `지원 요청` (운영·고객 지원) · `행정 요청` (인사·계약·내부 행정) · `리서치 요청` (시장·경쟁·기술 조사)

If the dump signals more than one (e.g., 버그 수정 + 새 기능 추가 묶여 있음), present both candidates in the gate and ask which one this Request is about — splitting into two Requests is also a valid answer.

### 2.3 카테고리 inference

Two values only: `개발` / `비개발`. Pair-check with 유형: `기능 *` ⇒ `개발`, `* 요청` ⇒ `비개발`. Never emit a mismatched pair.

### 2.4 제목

Verb-led, concrete, 짧게. Noun-only titles are rejected.

**Good:** "결제 페이지 환불 버튼 추가", "Q4 경쟁사 가격 정책 표 작성", "고객사 A에 신규 SLA 초안 회신"
**Bad:** "결제 환불", "경쟁사 분석", "SLA 처리"

### 2.5 요점 (one-liner)

Single sentence: 누가 · 무엇을 · 왜. This is the seed for the body — if the AI can't write it cleanly, the Request is not yet ready to draft.

### 2.6 Gate 2 presentation

```
이렇게 이해했습니다:

  티어:     보통 (3 섹션)
  유형:     기능 추가
  카테고리: 개발
  제목:     {title}
  요점:     {one-liner}
  프로젝트: {project name | 없음}

맞나요? 수정할 항목이 있으면 알려주세요. (예: "티어 간결로", "유형은 개선이에요", "제목 'X'로")
```

Single confirmation. The user can override any field; re-run the affected inference if needed.

## Phase 3: Drafting

The body is what the 담당자 actually reads. Match the tier exactly — the tier judgment in Phase 2 binds this phase's structure.

The page title in Notion comes from the `이름` property; the body therefore starts at H2 (no top-level H1) and contains no meta header (no `> 담당자:` / `> 우선순위:` block — those are the Notion properties' job, not the body's).

### 3.1 Tier 간결 — 한 단락 + Why-forcing

**Body shape:**

```markdown
{한 단락의 자연스러운 산문. 80–150 words. "왜 — 무엇 — (선택) 어떻게"가 통합된 흐름.}

**완료 시:** {담당자가 자가검증할 한 문장. 자명하면 생략 가능.}
```

No section headers. The Why must be present in the paragraph — not as a separate label, but woven into the text so the 담당자 understands purpose before reading the ask.

**Why-forcing protocol:**

If the AI cannot articulate a clear, specific Why from the user's dump (e.g., dump only says "X 페이지에 Y 추가해줘"), do not write the body. Ask the user:

> "이 작업이 왜 필요한가요? 한 문장으로 부탁드립니다. (예: '월간 리포트에서 Y 데이터가 누락되어', '다음 분기 영업 자료에 들어가야 해서')"

Wait for the answer. Only then draft. If the user resists ("그냥 해줘"), push back once:

> "Why가 없으면 담당자가 우선순위를 못 정합니다. 한 문장이면 됩니다 — 영향 받는 사람이나 후속 작업 하나만 떠올려보셔도 충분해요."

If the user still refuses, surface that the Request will be hard to act on and let them choose to proceed anyway (recorded as their decision) or upgrade tier.

**Good example (illustrative; substitute real context):**

> 분기 영업 자료에 신규 고객사 로고 섹션이 추가되면서, 현재 4개 로고만 들어가는 컴포넌트가 8개를 수용해야 한다. 디자인팀이 새 그리드 시안을 공유했으니, 영업자료팀이 다음 주 월요일까지 슬라이드 마스터를 업데이트해 주면 된다.
>
> **완료 시:** 슬라이드 마스터에서 8개 로고가 정렬되어 보이고, 영업팀 채널에 변경 공지가 올라감.

**Bad example (rejected by Why-forcing):**

> 슬라이드 마스터에 로고 자리 늘려주세요.
> → 왜 늘려야 하는지, 누구에게 영향이 있는지, 무엇이 바뀌어야 하는지 모두 추론 불가.

### 3.2 Tier 보통 — 3 섹션

```markdown
## 1. 배경

{왜 이 작업이 필요한가, 누구에게 영향이 있는가, 어떤 문제를 해결하는가. 1–3 문장.}

## 2. 결과물

{무엇을 산출하는가 — 형식·분량·대상을 명시.}

- {결과물 1}
- {결과물 2}

## 3. 완료 기준

{담당자가 스스로 체크할 수 있는 객관적 조건 1–3개.}

- [ ] {조건 1}
- [ ] {조건 2}
```

200–350 words. 결과물은 형식(파일/페이지/리포트)·분량(슬라이드 N장, 표 N행)·대상(누가 보는 것인지)을 명시한다 — 빠지면 담당자가 추측해야 한다.

### 3.3 Tier 상세 — 5 필수 + 2 옵셔널 섹션

```markdown
## 1. 배경 및 목적

{왜 이 작업을 하는가, 어떤 문제를 해결하는가. 담당자가 독립적으로 판단할 수 있을 만큼 풍부하게.}

## 2. 범위 및 결과물

{무엇을 만들어야 하는가 — 형식·분량·내용을 명확히. 포함과 제외를 명시한다.}

- **포함:** {what's in}
- **제외:** {what's out — 명시적으로 다루지 않을 것}

**결과물 체크리스트:**

- [ ] {결과물 1}
- [ ] {결과물 2}

## 3. 요구사항 및 제약사항

{반드시 충족해야 할 조건. 요청자에게 당연한 것도 담당자에게는 모를 수 있으니 명시화.}

- {요구사항 1}
- {제약사항 — 도구·예산·포맷·보안 등}

### {도메인} — 어디까지 신경 쓸지 _(선택, 깊이 바운더리가 필요할 때만)_

{비기능 요구사항(보안·성능·접근성·호환성 등)이 단독 한 줄 bullet으로 들어가면 담당자가 어디까지 파야 할지 모른다 — 특히 주니어이거나 별도 전담팀이 없는 조직에서는 무한히 깊게 파거나 거꾸로 한 줄로 끝낸다. 깊이를 제어해야 하면 3단으로 구조화.}

**반드시 (이번 검토에서 결론 내야 함):**

- {조건 — yes/no로 답할 수 있게}

**권장 (가능하면 도입, 못하면 사유 기록):**

- {조건}

**이번 범위 외 ({후속 단계명}로 이월):**

- {다루지 않을 항목}

### 보류(kill) 조건 _(선택, 검토·리서치 성격 상세 tier에서 yes-bias 차단용)_

{검토·리서치 Request는 자연히 yes-bias가 생긴다 ("도입 권장"이 안전한 결론). 어떤 발견이 있을 때 No가 정답인지 사전에 박는다.}

다음 중 하나에 해당하면 "보류" 결론이 정답:

- {조건 1}
- {조건 2}

Apply **범위 바운더리** when a non-functional requirement (보안 / 성능 / 접근성 / 호환성) appears as a single bullet — that's a signal the boundary on assignee depth is missing. Apply **보류 조건** whenever the Request is decisional (도입할까 / 어떤 도구가 나은가 / 마이그레이션할까) — yes-bias affects all such cases. Skip both when the Request is purely executional (e.g., "표 만들기") — bureaucratic theater otherwise.

## 4. 중간 체크포인트 _(선택)_

{잘못된 방향으로 가는 것을 막기 위한 의미 있는 중간 단계가 있을 때만 작성.}

| 단계         | 내용 | 확인 방법 |
| ------------ | ---- | --------- |
| Checkpoint 1 | ...  | ...       |

## 5. 완료 기준

{담당자가 자가점검할 수 있는 객관적 조건. "잘 동작한다"는 거절.}

- [ ] {조건 1}
- [ ] {조건 2}

## 6. 선행 조건 및 참고 자료

- **선행 작업:** {없으면 "없음"}
- **참고 자료:** {링크 또는 문서명}
- **문의:** {특정인 또는 "요청자에게 직접"}

## 7. 성공 지표 _(선택)_

{이 업무가 잘 완료됐는지 판단할 정량 지표. 정성 지표만 있다면 이 섹션을 생략.}

- {지표 1}
```

400–700 words. Sections 4와 7은 의미가 있을 때만 포함한다 — 모든 작업에 체크포인트가 필요한 것도, 정량 지표가 가능한 것도 아니다. AI가 판단해서 빈 껍데기 섹션을 만들지 않는다.

## Phase 4: Review (Tier-Differential)

The reviewer's four axes (관점 확장 / 현재성 / 구체성 / 결정 형상) — formerly the standalone `task-reviewer` skill — are now an internal phase whose depth depends on tier.

### 4.1 Skipped — Tier 간결

The body is too short for review to add net value (검토가 본문보다 길어지는 역설). Move directly to Phase 5.

### 4.2 Internal silent revision — Tier 보통

Run all three checks privately, revise the draft if any check finds an issue, and present the revised body in Phase 5 without a 검토 요약 block.

- **관점 확장:** 사용자가 이미 결정한 도구/접근이 진짜 최선인지, 아니면 단지 익숙해서 고른 것인지. 더 적합한 대안이 있다면 본문에 자연스럽게 녹여 담당자가 비교 판단할 수 있게 한다.
- **현재성** — 본문에 특정 도구·기술·라이브러리·방법론이 명시된 경우에만 웹 검색으로 현 시점에서 여전히 유효한지 확인. 도구가 언급되지 않았으면 이 축은 자동 skip (skill must not invent tools to check).
- **구체성:** 담당자가 추가 질문 없이 실행 가능한가. "정리해줘", "조사해줘" 같은 모호한 동사가 있으면 범위/형식/대상을 채워 넣는다.
- **결정 형상 (decision shape):** 본문이 핵심 의사결정 1개를 식별 가능하게 만드는가, 부수 질문이 핵심과 독립인지/종속인지 라벨링되어 있는가, 완료 기준이 "보류(No)" 결론을 허용하는가. 모호하면 §3과 결과물 체크리스트를 재정렬해 핵심을 위로 끌어올린다. 검토·리서치 성격 Request에서 자연 발생하는 yes-bias를 차단하는 축이다.

### 4.3 Explicit review summary — Tier 상세

Run all three checks and produce a short summary. The summary is shown to the user in Phase 5 alongside the body, but is **not included in the body written to Notion** — it's reviewer commentary, not work content.

```markdown
## 검토 요약 _(미리보기 전용 — Notion 본문에 포함되지 않음)_

**관점 확장:** {문제없음 | 수정함 — 한 줄 사유}
**현재성:** {문제없음 | 수정함 — 한 줄 사유 | 해당 없음 (도구 미언급)}
**구체성:** {문제없음 | 수정함 — 한 줄 사유}
**결정 형상:** {문제없음 | 수정함 — 한 줄 사유}
```

If a check is inconclusive (e.g., web search returns nothing definitive), mark "확인 필요" and surface as a suggestion rather than silent edit.

## Phase 5: Final Preview (Gate 3)

Show one consolidated preview:

```
최종 검토. 이대로 Notion Requests DB에 생성합니다.

  제목:     {title}
  유형:     {type}
  카테고리: {category}
  프로젝트: {project name | 없음}

{검토 요약 block — 상세 tier에서만 표시}

---

{full body markdown}

---

이대로 진행할까요? 수정사항 있으면 말씀해주세요.
```

If the user requests changes, apply them and re-show. Do not write until explicit confirm.

## Phase 6: Write to Notion

```bash
properties=$(jq -n \
  --arg title "<title>" \
  --arg type "<유형 select value>" \
  --arg category "<개발|비개발>" \
  --arg pid "<project_id or empty>" \
  '{
    "이름":     {"title":[{"text":{"content":$title}}]},
    "유형":     {"select":{"name":$type}},
    "카테고리": {"select":{"name":$category}}
  } + (if $pid == "" then {} else {"Projects DB":{"relation":[{"id":$pid}]}} end)')

create-page.sh --parent requests_db --properties "$properties" --markdown - <<'EOF'
<full body markdown — Phase 3 output, no 검토 요약>
EOF
```

Do **not** set: `상태`, `우선순위`, `작업 기간`, `요청자`, `담당자`. These are filled in Notion's UI by the requester. Setting them here would silently override the requester's intent.

After successful write, respond:

> Request 생성 완료
> URL: {Notion 페이지 URL}
>
> 다음 단계: Notion에서 우선순위 · 담당자 · 요청자 · 작업 기간을 설정해주세요.

Return the URL in the final message.

## Anti-Patterns (do NOT do these)

- **Do not auto-fill people / date / priority / status properties.** Those belong to the requester's UI workflow.
- **Do not include a meta header in the body** (`> **담당자:**` 등). Properties live on the page object, not in markdown.
- **Do not skip Why-forcing for 간결 tier.** The Why is the one thing that survives even at minimum length.
- **Do not skip explicit review for 상세 tier.** That's the whole reason the user picked 상세.
- **Do not fabricate a project relation.** If unresolved after one clarification, mark "없음".
- **Do not pair `비개발` with `기능 *` 유형.** The category-type pair has only valid combinations.
- **Do not write a body for a Initiative-shaped ask.** Surface the redirect to `write-sdlc-initiative` first.
- **Do not invent tools to satisfy the currency check.** Currency check fires only when the body actually names a specific tool.
- **Do not use Notion templates.** Content is generated fresh.
- **Do not nest bullet lists inside blockquotes (`> -`).** Notion's markdown parser drops the list out of the quote and renders raw `-` characters as body text. For "다음 중 하나에 해당하면…" 같이 한 줄 리드 + 조건 나열 패턴은 리드를 일반 단락으로 두고 그 아래에 일반 bullet을 둘 것. Single-line blockquotes(사용자 발화·인용)는 무방.

## Error Handling

- **`notion-api` precondition failed (exit 2)** → surface the script's stderr hint (missing config, jq not installed, integration not shared) and stop.
- **`projects_db` query fails or returns no match for a project the user clearly named** → ask once for the exact project name; if still unresolved, default to "없음" with the user's confirmation.
- **`유형` ambiguous after one clarification** → ask whether the work should be split into two separate Requests rather than forcing a single bucket.
- **User refuses to provide a Why for 간결 tier** → push back once; if they still refuse, log the decision in the preview and let them proceed; do not silently invent a Why.
- **`create-page.sh` returns non-zero** → surface stderr (Notion error code + message) and offer to retry. Keep the drafted body in memory for the retry.
