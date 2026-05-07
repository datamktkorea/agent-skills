---
name: start-spec-implementation
description: Loads the full upward context chain (Spec → Request → Initiative → Project Steering → Repo Steering) for a Notion Spec page, then transitions the Spec to `구현중` status and hands off to a coding session. Trigger when the user says "Spec 구현 시작", "이 Spec 구현", "코딩 세션 시작", "구현 들어갈게", "implement spec", "start spec implementation", or pastes a Notion Specs DB page URL with intent to code. Forces single-Spec-per-session discipline. If no Spec URL is given, the skill induces creation by invoking `/write-sdlc-spec` first.
---

# Start Spec Implementation

This skill is the **Phase 2 entry point** in the SDLC pipeline. Its job is to gather the authoritative context an AI coding agent needs to implement a Spec correctly: the Spec itself, its parent Request, the Initiative bet that birthed it, the Project's time-invariant Steering, and the repo's local conventions (`CLAUDE.md` / `AGENTS.md`).

It does not write code. It loads context, marks the Spec as `구현중`, and exits. The coding agent takes over with the loaded context resident in the conversation.

## When to use

- User has a Notion Spec page URL and intends to start coding it.
- User says "Spec 구현 시작", "이 Spec 구현", "이거 코딩 들어갈게", "implement spec", "start spec implementation", or pastes a Specs DB page URL.
- User asks for a "context dump" of a Spec.

## When NOT to use

- Spec doesn't exist yet → `write-sdlc-spec` first (this skill auto-invokes it as gate-(c) induction).
- 2–6 week Initiative-level scope → `write-sdlc-initiative`.
- Spec complete and PR ready → `record-spec-pr` (separate skill, see PLAN.md).
- Just want to read a Notion page → `notion-api` `fetch-page.sh` directly.

## Note on examples

Every concrete identifier (file paths, repo names, role names, page URLs) in this skill's text is illustrative. When running, substitute real values from the user's input and the fetched Notion content. Never reproduce example identifiers in the user-facing prompt.

## Prerequisites

### 1. `notion-api` skill preconditions

`~/.datamktkorea/config.json` with valid `notion_token` and the `triggers_db`, `requests_db`, `specs_db`, `projects_db` keys in `notion_dbs`. `jq` installed. The Integration shared with all four databases. If any precondition fails, the underlying script exits with code 2 and surfaces a hint.

### 2. cwd is a git repository

The skill reads cwd's git HEAD, dirty state, and `CLAUDE.md` / `AGENTS.md`. If `git rev-parse --git-dir` fails, surface and ask the user to navigate to the repo root.

### 3. Single Spec per session

Hard rule. If the user has already run this skill in the same conversation for a different Spec, ask:

> "이미 다른 Spec(`{prev-title}`)으로 컨텍스트가 로드된 세션입니다. 새 Spec으로 전환하면 기존 컨텍스트가 무력화됩니다. 새 세션을 여는 것을 권장합니다.
> (a) 그래도 전환 / (b) 새 Claude Code 세션 열고 거기서 다시 호출 (권장)"

Do not attempt to "merge" two Specs into one session.

## Scripts used

Shorthand throughout. Full signatures live in `notion-api/SKILL.md`.

| Shorthand | Resolves to |
|---|---|
| `fetch-page.sh` | `${CLAUDE_PLUGIN_ROOT}/skills/notion-api/scripts/fetch-page.sh` |
| `fetch-page-properties.sh` | `${CLAUDE_PLUGIN_ROOT}/skills/notion-api/scripts/fetch-page-properties.sh` |
| `update-page.sh` | `${CLAUDE_PLUGIN_ROOT}/skills/notion-api/scripts/update-page.sh` |

## Workflow Overview

| Phase | What happens |
|---|---|
| 0. Spec resolution | Extract or solicit a Spec URL. Auto-invoke `/write-sdlc-spec` if absent. |
| 1. Walk-up fetch | Spec → Request → Initiative → Project. Always re-fetch (no cache). |
| 2. Repo state | cwd git state. Repo Steering (`CLAUDE.md` + `AGENTS.md`). cwd integrity soft-check vs Spec's pinned ref. |
| 3. Briefing | Render single inline briefing (chat only, no sidecar files). Inject only the *referenced* Steering sections. |
| 4. State transition | `Spec.상태 = 구현중`. Final hand-off message. |

---

## Phase 0: Spec Resolution

### 0.1 Extract or solicit Spec URL

Scan the user's most recent message for a Notion URL matching the Specs DB. Notion page URLs look like `https://www.notion.so/<workspace>/<title>-<32-hex>` or `https://www.notion.so/<32-hex>`.

If found → save as `{SPEC_URL}` and proceed to 0.2.

If not found → ask:

> "구현할 Spec의 노션 페이지 URL을 알려주세요. (예: `https://www.notion.so/...`)
>
> 만약 Spec이 아직 없다면 'Spec 없음'이라고 답해주세요. `/write-sdlc-spec`을 자동으로 실행해 작성을 도와드린 뒤 다시 본 스킬로 돌아옵니다."

If user replies with a URL → save and proceed.

If user replies with 'Spec 없음' (or equivalent) → **gate (c) induction**:

> "Spec이 없으니 먼저 작성하겠습니다. 이제 `/write-sdlc-spec` 스킬로 전환합니다. 작성이 끝나면 그 결과 URL을 가지고 본 스킬을 다시 호출해주세요."

Then invoke `/write-sdlc-spec` (Claude Code skill chaining: instruct Claude to run that skill in the same session). The user is expected to complete write-sdlc-spec and re-invoke this skill manually with the resulting URL. Do not loop back automatically — the boundary is explicit.

### 0.2 Confirm Spec URL is in Specs DB

Fetch properties to verify membership:

```bash
fetch-page-properties.sh "{SPEC_URL}"
```

Check `parent.data_source_id`. It must equal the Specs DB data source ID (registered in `notion-api/SKILL.md` under `specs_db`). If it does not match:

> "이 페이지는 Specs DB 소속이 아닙니다 (parent: `{actual_data_source}`). Specs DB의 페이지 URL이 맞는지 확인해주세요."

and stop.

Save `{SPEC_PAGE_ID}`, `{SPEC_TITLE}`, `{SPEC_PROPERTIES}` (full properties JSON for later access).

---

## Phase 1: Walk-up Fetch

### 1.1 Fetch Spec body

```bash
fetch-page.sh "{SPEC_URL}" --markdown-only
```

Save as `{SPEC_BODY}`.

### 1.2 Extract "관련 Steering 섹션" list

Parse `{SPEC_BODY}` for the section heading `## 9. 관련 Steering 섹션` (or `## 8.` / `## 7.` depending on the template — look for the text "관련 Steering 섹션" in the heading regardless of number).

Extract the bullet list under that heading. Each bullet should be the *exact section heading* as it appears in Project Steering. Save as `{STEERING_SECTIONS} = [...]`.

If the section is absent or empty:

> "이 Spec에 '관련 Steering 섹션' 항목이 없습니다. 이는 본 스킬이 Project Steering에서 무엇을 fetch할지 모른다는 의미입니다.
> (a) Spec을 보강 (`write-sdlc-spec` 흐름의 마지막 섹션 추가) — 권장
> (b) 일단 `Domain Glossary`, `Business Rules`만 default로 fetch하고 진행"

If (b) → set `{STEERING_SECTIONS} = ["Domain Glossary", "Business Rules"]` and continue.

### 1.3 Fetch parent Request

From `{SPEC_PROPERTIES}`, extract `Requests DB` relation's first ID:

```jq
.properties["Requests DB"].relation[0].id
```

Call this `{REQUEST_ID}`. If absent (orphan Spec):

> "이 Spec에 부모 Request 연결이 없습니다. write-sdlc-spec은 Request 없이 Spec을 만들지 않으므로, 비정상 상태입니다. 사용자가 직접 노션에서 연결해주세요."

and stop.

```bash
fetch-page.sh "{REQUEST_ID}" --markdown-only
fetch-page-properties.sh "{REQUEST_ID}"
```

Save `{REQUEST_BODY}`, `{REQUEST_PROPERTIES}`.

### 1.4 Fetch Initiative (if linked)

From `{REQUEST_PROPERTIES}`, extract `Initiatives DB` relation:

```jq
.properties["Initiatives DB"].relation
```

If empty array → this is a Spec-track Request without Initiative parent. Skip Phase 1.4. Set `{INITIATIVE_BODY} = ""`.

If non-empty → take the first ID as `{INITIATIVE_ID}`:

```bash
fetch-page.sh "{INITIATIVE_ID}" --markdown-only
fetch-page-properties.sh "{INITIATIVE_ID}"
```

Save `{INITIATIVE_BODY}`, `{INITIATIVE_PROPERTIES}`.

### 1.5 Fetch Project Steering body

From `{REQUEST_PROPERTIES}`, extract `Projects DB` relation's first ID (cardinality is 1):

```jq
.properties["Projects DB"].relation[0].id
```

Call this `{PROJECT_ID}`. If absent:

> "Request에 Projects DB 연결이 없습니다. Steering을 fetch할 곳이 없으므로 비정상 상태입니다. 사용자가 직접 노션에서 연결해주세요."

and stop.

```bash
fetch-page.sh "{PROJECT_ID}" --markdown-only
fetch-page-properties.sh "{PROJECT_ID}"
```

Save `{PROJECT_BODY}` (full Project Steering body), `{PROJECT_TITLE}`.

### 1.6 Extract referenced Steering sections only

From `{PROJECT_BODY}`, extract only the sections whose headings exactly match items in `{STEERING_SECTIONS}`. Use markdown heading boundaries (`## ` or `# `) to delimit each section: from one matching heading to the next heading of equal or higher level.

Save the concatenation as `{STEERING_EXCERPT}`.

For any item in `{STEERING_SECTIONS}` not found in `{PROJECT_BODY}`:

> "Spec이 참조한 Steering 섹션 `{section_name}`이 Project Steering 본문에서 발견되지 않았습니다. 헤딩 typo이거나, Steering이 아직 그 섹션을 작성하지 않았을 수 있습니다."

(Surface as a warning, not a stop. Continue with the matched subset.)

---

## Phase 2: Repo State

### 2.1 cwd git state

```bash
branch=$(git rev-parse --abbrev-ref HEAD)
sha=$(git rev-parse --short HEAD)
dirty=$(git status --porcelain | wc -l | tr -d ' ')
```

If `dirty > 0`:

> "현재 디렉토리에 uncommitted 변경 {N}개가 있습니다. 본 스킬은 임의로 stash·checkout하지 않습니다. 깨끗한 상태에서 시작하시려면 사용자가 직접 정리해주세요. 그래도 진행하시면 (a)를 누르세요.
> (a) 진행 / (b) 정리 후 다시 호출"

If (b) → stop.

### 2.2 cwd integrity soft-check

Look for a "기준:" or "위치 힌트" pinned ref line in `{SPEC_BODY}` matching the format `{repo_key}: {branch} @ {sha}`. Extract `{spec_repo_key}`.

If `{spec_repo_key}` cannot be parsed → skip the check.

If parsed, compare `{spec_repo_key}` against cwd's repo identity. The simplest signal: cwd's basename (`basename "$(pwd)"`). If they differ enough to be suspicious:

> "Spec의 핀 박힌 repo는 `{spec_repo_key}`인데 현재 cwd basename은 `{cwd_basename}`입니다. 같은 repo가 맞나요?
> (a) 네, 같은 repo (이름만 다름) — 진행
> (b) 다른 repo입니다 — 올바른 디렉토리로 이동 후 재호출"

If (b) → stop. If (a) → proceed.

This is a *soft* check: false positives are acceptable since cwd basename and Spec's recorded repo_key may use different naming conventions. The point is to catch obvious repo mismatches.

### 2.3 Repo Steering

Try in order. Both can coexist:

- `./CLAUDE.md` (Claude Code primary)
- `./AGENTS.md` (cross-tool standard, OpenAI Codex / Cursor / Sourcegraph / Linux Foundation as of 2026)

```bash
[ -f ./CLAUDE.md ] && cat ./CLAUDE.md
[ -f ./AGENTS.md ] && cat ./AGENTS.md
```

Save concatenation as `{REPO_STEERING}`. If both absent:

> "이 repo에 `CLAUDE.md`도 `AGENTS.md`도 없습니다. Repo-level 컨벤션 없이 진행합니다. (Repo Steering 정비는 추후 `update-repo-steering` 스킬에서 — 현재 미구현, PLAN.md B6 참고.)"

Set `{REPO_STEERING} = ""` and continue.

---

## Phase 3: Briefing

Render a single inline briefing in chat. **No sidecar files.** **No injection into `CLAUDE.md`.** Chat-only is by design (per ETH Zurich finding that persistent context files degrade agent performance, and to avoid project-memory pollution).

Format:

```markdown
# 🟢 Spec Implementation Context Loaded

**Project:** {PROJECT_TITLE}
**Initiative:** {INITIATIVE_TITLE if present, else "(없음 — Spec-track Request)"}
**Request:** {REQUEST_TITLE} ({REQUEST_TYPE})
**Spec:** {SPEC_TITLE}

**Repo:** {cwd basename} @ branch `{branch}` (sha `{sha}`, {dirty}개 unstaged)

---

## Project Steering (referenced sections only)

{STEERING_EXCERPT}

---

## Initiative

{INITIATIVE_BODY if present, else omit this section entirely}

---

## Request

{REQUEST_BODY}

---

## Spec (executable target)

{SPEC_BODY}

---

## Repo Steering

{REPO_STEERING if present, else "(없음)"}

---

이 컨텍스트가 본 코딩 세션의 Single Source of Truth입니다.
- Spec 본문에 없는 결정은 위 Steering에서 찾으세요.
- Steering에도 없으면 사용자에게 물어보세요 (절대 추측해서 코드 작성 X).
- 본 Spec의 Acceptance Criteria / Verification Commands가 완료의 기준입니다.
```

The above is *one chat message*. The agent's subsequent turns will reference it as resident context.

---

## Phase 4: State Transition

### 4.1 Set Spec.상태 = 구현중

After the briefing is delivered (Phase 3 completed without error):

```bash
update-page.sh "{SPEC_PAGE_ID}" \
  --properties '{"상태":{"status":{"name":"구현중"}}}'
```

Surface short confirmation:

> "Spec 상태를 `구현중`으로 전이했습니다. 노션의 Spec 페이지에 반영되었습니다."

If the update fails (network, permissions) → surface error but **do not retry blindly** and **do not roll back the briefing**. The user can fix and re-run; the context is already loaded.

### 4.2 Final hand-off

> "컨텍스트 로드 완료. 이제 Spec을 구현하시면 됩니다.
>
> 코딩이 끝나면:
> 1. `git-commit` 스킬로 atomic 커밋 작성
> 2. `git-pull-request` 스킬로 PR 본문 작성·생성
> 3. (예정) `record-spec-pr` 스킬로 PR URL을 노션 Spec 페이지에 기록 + Spec 상태 `완료`로 전이"

End of skill. Coding agent takes over.

---

## Authoring Rules

- **Output language**: Korean by default, technical terms / paths / identifiers in original form.
- **Always re-fetch from Notion** at every invocation (no cache, no `last_edited_time` optimization). Notion is the upstream SSOT and our sessions are short-lived.
- **Never write briefing to disk** — chat only.
- **Never inject Spec context into `CLAUDE.md`** — that is project memory, not session memory.
- **Never auto-stash, auto-commit, or auto-checkout.** The repo state belongs to the user.
- **Never auto-create branches** matching Spec ID — branch naming follows GitFlow per `git-pull-request` skill (`features/*`, `fix/*`, etc.). Spec ID is *not* in the branch name.
- **Single Spec per session.** Do not load a second Spec into the same conversation.
- **Inject only referenced Steering sections.** Full Steering body injection is forbidden — context bloat directly degrades coding agent performance (ETH Zurich 2026 study).

---

## Error Handling

- **No Spec URL in user message and 'Spec 없음' answered** → invoke `/write-sdlc-spec` and exit.
- **Spec URL points to a non-Specs page** → surface and stop at Phase 0.2.
- **Spec body has no '관련 Steering 섹션'** → ask user; on (b) fallback to Glossary + Business Rules defaults.
- **Spec missing Requests DB relation** → surface and stop at Phase 1.3.
- **Request missing Projects DB relation** → surface and stop at Phase 1.5.
- **Steering section name not found in Project body** → warn, proceed with matched subset.
- **cwd not a git repo** → surface and stop at Phase 2.1.
- **cwd dirty** → ask user (a)/(b); on (b) stop.
- **cwd basename mismatches Spec's repo_key (soft check)** → ask user (a)/(b); on (b) stop.
- **Notion update for `상태=구현중` fails** → surface error but do not roll back briefing; user can re-run.
- **Same conversation, second Spec attempted** → surface single-Spec rule and ask for new session.

---

## Anti-Patterns (DO NOT do these)

- **Do not skip the walk-up.** Spec alone is insufficient context — the coding agent needs Initiative bet framing, Project invariants, and Repo conventions to code coherently.
- **Do not inject the full Project Steering body.** Use only the sections the Spec author marked as relevant. Forcing the agent to read 20KB of Steering for a 3-line bug fix is the failure mode this skill exists to prevent.
- **Do not write context to a file.** Chat-only output. The session is the lifetime of the context.
- **Do not infer Spec ID from cwd or branch name.** Always require explicit URL from the user.
- **Do not transition `상태` to `완료` here.** That belongs to `record-spec-pr` — completion happens at PR merge, not at coding-session start.
- **Do not auto-create a `spec/<id>` branch.** Branch naming follows GitFlow (`features/*`, `fix/*`, etc.) per `git-pull-request` convention. Spec→PR linkage happens via PR-URL-on-Notion, not branch-name encoding.
- **Do not retry Notion fetches silently more than once.** If the API fails, surface to user; let them decide. Hidden retry loops mask real outages.
- **Do not load two Specs into one session.** Single-Spec-per-session is the discipline. Multi-Spec sessions blur context boundaries and cause regressions across unrelated work.
