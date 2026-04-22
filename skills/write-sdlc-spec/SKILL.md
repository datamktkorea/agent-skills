---
name: write-sdlc-spec
description: Writes an executable Spec document in Notion "Specs" DB through interactive Q&A, linked to a parent Request in "Requests" DB. Handles 4 Request 유형 (기능 에러 / 기능 추가 / 기능 변경 / 기능 개선), each with its own template-driven Q&A flow that forces substantive writing (sentence stems, good/bad examples, self-checks). Reads the user's codebase (via ~/.datamktkorea/code.json) before writing so the Spec contains real file:line references, not generic text. Use when the user says "스펙 써줘", "write spec", "기능 추가 명세 작성", "버그 수정 스펙", "이 요청 Spec으로 만들어줘", or wants to turn a Request into an agent-ready implementation spec. Do NOT use for Initiative-level bets (use write-sdlc-trigger for those) or for non-development requests (지원 요청, 행정 요청).
---

# Write SDLC Spec

A Spec is the **executable unit** handed to an AI coding agent (Claude Code). It answers "what exactly to build, where in the code, how to verify." Spec quality directly determines code quality: the skill's core job is to force substantive writing via structural constraints, then ground the output in the actual codebase via pre-authoring code reading.

The deliverable is a new page in Notion **Specs DB** linked to a parent Request, with category-specific body structure (derived from the Request's `유형`).

## When to Use

- User has a Request in Notion Requests DB that needs to be turned into an actionable Spec.
- User says "스펙 써줘", "이 요청 Spec으로 만들어줘", "버그 수정 명세", "기능 추가 spec", "write spec".
- The Request's `유형` is one of: 기능 에러 / 기능 추가 / 기능 변경 / 기능 개선.

## When NOT to Use

- Initiative-level bet (2–6 weeks, strategic) → use **write-sdlc-trigger**.
- Request 유형 is 지원 요청 / 행정 요청 / 리서치 요청 → not development work, handle separately.
- Request 유형 is 기능 배포 → should not exist (deprecated); if seen, ask user to re-classify the Request.

## Prerequisites

### 1. `notion-api` skill preconditions met

All Notion access goes through the `notion-api` skill's bash scripts. Its preconditions apply verbatim: `~/.datamktkorea/config.json` with `notion_token` + `notion_dbs` map, `jq` installed, the Integration shared with the relevant databases (`requests_db`, `specs_db`, `projects_db`). If any script exits with code 2 (precondition failure), surface its stderr hint to the user and stop.

### 2. `~/.datamktkorea/code.json` exists

Format:

```json
{
  "repo-name-in-projects-db": "/absolute/path/to/repo",
  "dmk-bingbong-web": "/Users/vincent/WorkHard/dmk-bingbong-project/dmk-bingbong-web",
  "dmk-bingbong-api": "/Users/vincent/WorkHard/dmk-bingbong-project/dmk-bingbong-api"
}
```

Check existence:

```bash
test -f ~/.datamktkorea/code.json && cat ~/.datamktkorea/code.json
```

If missing, stop immediately:

> "`~/.datamktkorea/code.json` 파일이 필요합니다. 이 파일이 없으면 코드 분석 없이 Spec을 쓸 수 없고, 코드 분석 없는 Spec은 이 스킬의 핵심 가치를 잃습니다. 팀 설정 가이드를 따라 code.json을 먼저 생성해주세요."

Do NOT fall back to interactive path entry or git-remote detection. Code.json is the single source of truth for repo paths.

### 3. Do NOT use Notion templates

The skill writes page content directly via `create-page.sh`. Any legacy Notion template in Specs DB is ignored. All content structure comes from `templates/*.md` in this skill.

## Scripts used

Shorthand used throughout this skill. Full signatures and behavior live in `notion-api/SKILL.md`.

| Shorthand | Resolves to |
|---|---|
| `query-db.sh` | `${CLAUDE_PLUGIN_ROOT}/skills/notion-api/scripts/query-db.sh` |
| `fetch-page.sh` | `${CLAUDE_PLUGIN_ROOT}/skills/notion-api/scripts/fetch-page.sh` |
| `fetch-page-properties.sh` | `${CLAUDE_PLUGIN_ROOT}/skills/notion-api/scripts/fetch-page-properties.sh` |
| `create-page.sh` | `${CLAUDE_PLUGIN_ROOT}/skills/notion-api/scripts/create-page.sh` |
| `update-page.sh` | `${CLAUDE_PLUGIN_ROOT}/skills/notion-api/scripts/update-page.sh` |

DB references use config keys: `requests_db`, `specs_db`, `projects_db`. Raw UUIDs live only in `~/.datamktkorea/config.json` and the authoritative schema in `notion-api/SKILL.md`.

## Core Principle: Forcing Functions + Grounded Code

Two pillars:

1. **Every section has a forcing function**: sentence stem, good example, bad example, self-check. If the user writes vague content ("UX improvement", "bug fix"), push back with a specific probe. Do not advance until self-check passes.

2. **Every concrete detail must be grounded in actual code**: file:line references, real function/constant names, real error messages. Writing a Spec before reading the code produces generic text the AI coding agent can't act on.

## Workflow Overview

| Phase                     | What happens                                                                 |
| ------------------------- | ---------------------------------------------------------------------------- |
| 0. Input resolution       | Pick a Request from Requests DB, inherit Project, detect category from 유형  |
| 1. Code reading           | Load code.json, map Request → target repo, build Implementation Map          |
| 2. Template load          | Read `templates/{category}.md` matching the Request's 유형                   |
| 3. Section-by-section Q&A | Execute the template's forcing-function flow, grounded in Implementation Map |
| 4. Review & write         | Compile final body, create Notion page in Specs DB                           |
| 5. Update Request         | Set Request status to 할당 and link bidirectionally                          |

## Phase 0: Input Resolution

### 0.1 Pick a Request

Ask:

> "어떤 Request로 Spec을 작성하나요?
> (a) 미할당 Requests 목록에서 선택
> (b) 특정 Request URL/ID 지정
> (c) 키워드로 검색"

**If (a)**: query Requests DB with a server-side filter for open Spec-eligible items:

```bash
query-db.sh requests_db --page-size 15 --filter '{
  "and": [
    {"or": [
      {"property":"상태","status":{"equals":"미할당"}},
      {"property":"상태","status":{"equals":"할당"}}
    ]},
    {"or": [
      {"property":"유형","select":{"equals":"기능 에러"}},
      {"property":"유형","select":{"equals":"기능 추가"}},
      {"property":"유형","select":{"equals":"기능 변경"}},
      {"property":"유형","select":{"equals":"기능 개선"}}
    ]}
  ]
}'
```

Show up to 10 results with title (`.properties["이름"].title[0].plain_text`), 유형 (`.properties["유형"].select.name`), 우선순위, and 요청자.

**If (b)**: fetch directly with `fetch-page-properties.sh <page_id_or_url>` plus `fetch-page.sh <...> --markdown-only` when body is needed.

**If (c)**: run the same query with an added title filter:

```bash
query-db.sh requests_db --page-size 10 --filter "$(jq -n --arg k "<keyword>" '{
  and: [
    {property:"이름", title:{contains:$k}},
    {or: [
      {property:"유형", select:{equals:"기능 에러"}},
      {property:"유형", select:{equals:"기능 추가"}},
      {property:"유형", select:{equals:"기능 변경"}},
      {property:"유형", select:{equals:"기능 개선"}}
    ]}
  ]
}')"
```

Save the selected Request's `id`, title, 유형, 우선순위, and Project relation (first item in `.properties["Projects DB"].relation`).

### 0.2 Derive Category

Map Request `유형` → category template:

| Request 유형 | Template file                  |
| ------------ | ------------------------------ |
| 기능 에러    | `templates/feature-error.md`   |
| 기능 추가    | `templates/feature-add.md`     |
| 기능 변경    | `templates/feature-change.md`  |
| 기능 개선    | `templates/feature-improve.md` |

If `유형` is missing or not in this list:

> "이 Request의 유형이 Spec 작성 대상이 아닙니다 (현재 값: {유형}). 유형을 먼저 [기능 에러 / 기능 추가 / 기능 변경 / 기능 개선] 중 하나로 수정해주세요."

and stop.

### 0.3 Inherit Project

Read `프로젝트` relation from the Request. If empty:

> "이 Request에 프로젝트가 연결되어 있지 않습니다. Request에 프로젝트를 먼저 연결해주세요."

and stop.

Save Project page URL and fetch Project's `엔티티 약어` + `프로젝트 약어`: these will be used to find the repo in code.json.

### 0.4 Fetch Request body

```bash
fetch-page.sh "<request-page-id-or-url>" --markdown-only
```

Save the markdown as `{REQUEST_CONTEXT}`: this is the raw intake that the user wrote. It will seed the Q&A and help pre-fill answers.

## Phase 1: Code Reading (Non-Negotiable)

### 1.1 Identify target repo

From the Project's `엔티티 약어` + `프로젝트 약어`, construct the repo key. Example: Project `[BINGBONG] 부키(출판) 에이전트` has 엔티티=`bingbong`, 약어=`bookie`. Convention: try `{엔티티}-{약어}` → `bingbong-bookie`, then `dmk-{엔티티}-{role}` → `dmk-bingbong-web` / `dmk-bingbong-api`.

Ask the user if multiple repos match:

> "이 프로젝트에 여러 레포가 연결됩니다:
>
> 1. dmk-bingbong-web (frontend)
> 2. dmk-bingbong-api (backend)
>    어느 레포에서 주로 작업하게 되나요? (복수 선택 가능)"

Look up absolute paths in code.json. Verify each path exists:

```bash
test -d "{PATH}" && echo "OK" || echo "MISSING"
```

If any is MISSING: tell user to fix code.json and stop.

### 1.1a Verify the repo state being read

The skill reads files from the user's local working tree. **Do not `git checkout`, `git stash`, or mutate state** — the user owns their workspace. The only job here is to make the state explicit so the Spec's file:line references are pinned to a known commit.

For each target repo, run:

```bash
cd "{repo_path}"
branch=$(git rev-parse --abbrev-ref HEAD)
sha=$(git rev-parse --short HEAD)
dirty=$(git status --porcelain | wc -l | tr -d ' ')
ahead_behind=$(git rev-list --left-right --count "@{u}...HEAD" 2>/dev/null || echo "no-upstream")
```

Show the user a single confirmation block per repo:

> "**{repo_name}** 현재 상태:
> - 브랜치: `{branch}` @ `{sha}`
> - 변경사항: {dirty}개 파일 (uncommitted)
> - 원격 대비: {ahead_behind} (left=behind, right=ahead)
>
> 이 상태로 코드 읽고 Spec 작성할까요?
> - (a) 네, 이대로 진행
> - (b) 다른 브랜치/상태에서 읽고 싶음 → 직접 `git checkout` 후 다시 시작해주세요"

If (b) → stop and let the user switch themselves. If (a) → proceed.

**Record per repo** for use in the Spec body: `{repo_name}: {branch} @ {sha}` + `(working tree clean)` or `(N uncommitted changes)`. This string goes into the Spec's "위치 힌트" section header so every file:line reference below it is pinned to that commit — months later someone can reproduce the exact state read.

Rationale: a Spec that says `src/foo.ts:L42` without a commit is ambiguous once the file changes. A Spec that says `{repo_key}: {branch} @ {sha} — src/foo.ts:L42` is reproducible forever.

### 1.2 Build Implementation Map

Based on category + Request body, find the relevant code. Read up to **15 files**. Depth over breadth.

**Category-specific reading strategy** (enforced: template will require it):

- **기능 에러 (Bug)**: start from error message or suspected file; follow imports/callers; read Zustand stores and React Query hooks involved in the failing flow; read adjacent tests.
- **기능 추가 (Feature Add)**: find the nearest similar feature; read its hooks/components/schemas as the pattern to mimic; read the extension point (schema/store/routing) where the new feature will attach.
- **기능 변경 (Feature Change)**: read the target function/component; then grep all callers; read the original introducing commit via git log/blame (for Chesterton's Fence section); read impacted tests.
- **기능 개선 (Feature Improvement)**: read the hot-path code; read existing instrumentation/logging; check if baseline metric is currently tracked; read similar past optimization PRs via git log.

Produce an Implementation Map (internal, used for Q&A pre-fill):

```
IMPLEMENTATION MAP: {request title}

Target repo: {repo name} ({abs path})

Entry point (user-facing):
  - {file:line}: {function/component}: {what it does, as observed in code}

Call chain:
  - {file:line} → {file:line} ({what is passed})
  - {file:line} → {external: API/DB/service} ({request shape})

Current behavior (from code, verbatim):
  - {actual logic with hardcoded values}
  - e.g., `f.size > 10485760` at src/features/publisher/upload.tsx:L84

Data model:
  - {schema/type name}: {relevant fields and types}
  - {JSONB structure from Zod schema if applicable}

Change/investigation candidates:
  - {file:line}: {why this matters for the Spec}

Git context (for Feature Change only):
  - Original commit introducing current behavior: {hash}: {one-line message}
  - Related past PRs: {list}

AI-discovered related issues (if any):
  - {file:line}: {issue}: flag for user, do not silently expand scope
```

Report to user:

> "코드 분석 완료: {REPO} ({branch} @ {sha}): 파일 {N}개 읽음, 변경 후보 {M}곳, 호출 체인 {K}단계."

**Pinned ref carryover:** the branch/sha recorded in 1.1a MUST appear once in the Spec body, near the top of whichever section first cites file:line (for most templates this is "위치 힌트" or "관련 코드"). Render as a single line like:

> 기준: `{repo_key}` @ `{branch}` (sha `{short_sha}`, working tree clean)

This is non-negotiable — a Spec without a pinned ref produces ambiguous file:line references once the code moves on.

### 1.3 Announce Category & Template

> "Request 유형이 **{유형}**이므로 **{category template name}**으로 Spec을 작성합니다."

## Phase 2: Load Category Template

Read the appropriate file from `templates/`:

```
Read: skills/write-sdlc-spec/templates/{feature-error|feature-add|feature-change|feature-improve}.md
```

Each template file defines:

- **Section list**: ordered Spec sections for that category.
- **Per-section Q&A block**: the `이 섹션의 역할`, `Ask (stem)`, `Good example`, `Bad example`, `Self-check`, `Pushback probes`, `Length`.
- **Per-section grounding rule**: what from the Implementation Map this section must cite (file:line, real constants, etc.).
- **Final body format**: how compiled answers are rendered to Notion markdown.

## Phase 3: Section-by-Section Q&A

For each section in the loaded template, in order:

1. **Pre-fill attempt**: draft a candidate answer based on:
   - Request body (`{REQUEST_CONTEXT}`)
   - Implementation Map
   - Known workspace context (Projects DB, CLAUDE.md if accessible)

2. **Present the section framing** to the user:
   - The stem (literal, formatted)
   - If a pre-fill exists: show it and ask "이 초안에서 수정/보강할 부분?"
   - If no pre-fill: ask the stem directly.

3. **Evaluate answer against self-check**:
   - If all self-check items pass → advance.
   - If any fail → push back with the template's probing question matching that failure mode.
   - **Do not advance after 3 failed attempts on the same section** → offer to save as `[DRAFT]` and return later.

4. **Ground the answer in the Implementation Map**:
   - If the user writes a file reference that isn't in the Map → flag and ask if they want to re-read that file.
   - If the user writes "구현 완료", "개선됨" without real values from code → reject (same as self-check fail).

5. **Save the section's accepted content** into the working draft.

## Phase 4: Review & Write

### 4.1 Preview

Compile the final body per the template's "final body format". Show the user a preview with:

- Proposed title (generated from Request title + category, e.g., `[버그] TOC 로딩 스피너 멈춤: /agent/bookie 언마운트 후 재마운트`)
- All sections rendered
- A "사용된 file:line 참조 {N}개" count (evidence of grounding)

Ask:

> "이 내용으로 Specs DB에 저장할게요. 수정할 부분 있으면 말씀해주세요."

### 4.2 Write to Notion

Compose the properties with `jq` and call `create-page.sh`, piping the compiled body via stdin:

```bash
properties=$(jq -n \
  --arg title "<generated title>" \
  --arg req "<request_id>" \
  --arg proj "<project_id>" \
  '{
    "이름":        {"title":[{"text":{"content":$title}}]},
    "Requests DB": {"relation":[{"id":$req}]},
    "Projects DB": {"relation":[{"id":$proj}]}
  }')

create-page.sh --parent specs_db --properties "$properties" --markdown - <<'EOF'
<compiled markdown body from template>
EOF
```

Do NOT set `유형` or `우선순위` directly: these are rollups from the Request and populate automatically via the `Requests DB` relation.

### 4.3 Update Request status

Mark the parent Request as `할당`:

```bash
update-page.sh "<request_id>" \
  --properties '{"상태":{"status":{"name":"할당"}}}'
```

### 4.4 Report

> "Spec 생성 완료:
>
> - 제목: {title}
> - URL: {notion url}
> - Request: {request title} (상태: 할당으로 변경)
> - 레포: {repo name}
> - 코드 참조: file:line 총 {N}개
>
> 다음 단계: 개발자가 이 Spec을 Claude Code에 전달하여 구현 시작."

Return the created page URL.

## Error Handling

- **notion-api precondition failed (exit 2)** → surface the script's stderr hint (missing config, jq, integration access) and stop.
- **code.json missing** → stop at Prerequisites (do NOT fall back).
- **Request 유형이 지원 대상 아님** → stop at Phase 0.2.
- **Project relation empty on Request** → stop at Phase 0.3.
- **code.json에 해당 레포 경로 없음 or invalid** → stop at Phase 1.1, ask user to fix code.json.
- **Implementation Map이 0 files** (코드 못 찾음) → push back to user: "이 Request가 어느 코드 영역과 관련된지 힌트를 주세요 (파일/함수/에러 메시지)".
- **3 failed self-checks on same section** → save as `[DRAFT]` with incomplete markers, exit gracefully.
- **Notion API write fails** → show full error, keep the draft in memory, offer retry. Do NOT silently lose content.

## Anti-Patterns (do NOT do these)

- **Do not skip code reading.** Every section must reference actual file:line or real values from the Implementation Map. A Spec without grounded references has no value over a generic PRD.
- **Do not combine sections into one mega-question.** Each section's forcing function depends on isolation.
- **Do not let the user paste a wall of text and auto-split.** The Q&A is the point: it's where vague thinking gets caught.
- **Do not add sections the template doesn't define.** The templates are deliberately tight.
- **Do not silently expand scope.** If code reading reveals related issues outside the Request, call them out explicitly as "AI-discovered related issues" for the user to decide.
- **Do not set 유형 / 우선순위 on the Spec directly.** Let them rollup from the Request.
- **Do not skip Update Request Status (Phase 4.3).** Orphan Requests (still in 미할당 after Spec is written) break the pipeline view.

## Template File Contract

Each `templates/*.md` file MUST contain:

1. **Front matter**: category identifier, Request 유형 it handles.
2. **Section list**: ordered sections in the final Notion body.
3. **Per-section blocks** with: `이 섹션의 역할`, `Ask (stem)`, `Good example`, `Bad example`, `Self-check`, `Pushback probes`, `Length`, `Grounding requirement`.
4. **Final body format**: a markdown skeleton showing how compiled answers are rendered.

SKILL.md does NOT contain category-specific Q&A. Everything category-specific lives in the template files. This keeps SKILL.md small (orchestration only) and templates editable without touching the skill's main logic.
