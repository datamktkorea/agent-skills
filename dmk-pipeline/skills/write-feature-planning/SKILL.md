---
name: write-feature-planning
description: Writes a feature planning document (case list + requirements) through an interactive Q&A session. Always activate on '/write-feature-planning'. Also use this skill whenever the user asks to write feature requirements, define development scope, list edge cases, create a requirements doc, or plan out what needs to be built for a feature — even without explicitly mentioning '/write-feature-planning'. This skill is the step after service planning (write-service-planning). It reads the service planning document, extracts features from the TO-BE flow, and produces a case list and requirements summary. Apply this skill any time a service planning doc already exists and the user wants to move to the next planning phase.
---

# Write Feature Planning

Read the service planning document, extract features from the TO-BE flow, then produce a single feature planning document containing all features as numbered tasks. Save to `docs/feature/`.

---

## Project Detection (Autonomous)

Before doing anything else, resolve which project to use:

1. Read `~/.pipeline/config.json`.
   - If it does not exist → stop: "파이프라인 설정이 필요합니다. 먼저 `gh-pipeline-setup`을 실행해주세요."

2. Count projects in `config.projects`:
   - **1 project** → use it automatically.
   - **Multiple projects** → go to step 3.

3. Try to detect from the current git remote:
   ```bash
   gh repo view --json name -q '.name' 2>/dev/null
   ```
   Match the repo name against each project's `repos` list in the config.
   - **Match found** → confirm: "Using project `{PROJECT}` (detected from current repo). Correct?"
   - **No match** → show list and ask:
     ```
     Which project are you working on?
     1. bingbong-bookie
     2. bingbong-payments
     ```

Save the resolved `{PROJECT}` — all paths below use `~/.pipeline/docs/{project}/`.

---

## Phase 1: Source Check (Autonomous)

Before asking the user anything, load the service planning document using the steps below.

### Source: GitHub Issues (primary)

1. Verify `gh` authentication:

   ```bash
   gh auth status
   ```

   If this fails, skip to **Source: Local File (fallback)**.

2. Resolve the target repo from the project config (`repos` list). If multiple repos exist, ask the user to select one.

3. Query the GitHub Project for Epics currently at **"Service Planning"** Pipeline Stage:

   ```bash
   gh api graphql -f query='
     query($org: String!, $num: Int!) {
       organization(login: $org) {
         projectV2(number: $num) {
           items(first: 50) {
             nodes {
               fieldValueByName(name: "Pipeline Stage") {
                 ... on ProjectV2ItemFieldSingleSelectValue { name }
               }
               content {
                 ... on Issue { number title repository { name } }
               }
             }
           }
         }
       }
     }
   ' -f org="{ORG}" -F num={GITHUB_PROJECT_NUMBER} \
   --jq '[.data.organization.projectV2.items.nodes[]
     | select(.fieldValueByName.name == "Service Planning")
     | select(.content != null)
     | {number: .content.number, title: .content.title, repo: .content.repository.name}]'
   ```

4. Present the results:
   - **One issue found** → use it automatically.
   - **Multiple found** → ask:
     > "어떤 Epic 이슈의 피쳐 기획을 작성할까요?
     >
     > 1. #12 Asset file upload 10MB limit
     > 2. #9 TOC generation stuck on navigation
     > 3. 다른 이슈 선택 (전체 Epic 보기)"
   - **None found** → skip directly to step 5.

5. If the user selects "0" or no results were found in step 3, fetch all open Epics sorted by most recently updated:

   ```bash
   gh issue list \
     --repo {ORG}/{REPO} \
     --label "pipeline:epic" \
     --state open \
     --limit 30 \
     --json number,title,updatedAt \
     --jq '.[] | "#\(.number) \(.title) (\(.updatedAt[:10]))"'
   ```

   If no issues are returned here either, skip to **Source: Local File (fallback)**.
   Ask the user to select one.

6. Fetch sub-issues of the selected Epic:

   ```bash
   gh api /repos/{ORG}/{REPO}/issues/{EPIC_NUMBER}/sub_issues \
     --jq '.[] | {number: .number, title: .title, labels: [.labels[].name]}'
   ```

7. Find the sub-issue with label `pipeline:service-planning`. If not found, skip to **Source: Local File (fallback)**.

8. Read the service planning sub-issue body:
   ```bash
   gh issue view {SUB_NUMBER} --repo {ORG}/{REPO} --json body,title -q '{title: .title, body: .body}'
   ```

### Source: Local File (fallback)

Read the most recently modified file from `~/.pipeline/docs/{project}/planning/`.

If the directory does not exist or is empty, stop and output:

> "서비스 기획 문서를 찾을 수 없습니다. 먼저 `/write-service-planning` 으로 서비스 기획 문서를 작성해주세요."

Once loaded, extract:

- **TO-BE flow nodes** — every step, branch point, and system process in the TO-BE Mermaid flowchart
- **Scope Summary** — "Key changes" and "Affected screens"
- **AI feature flag** — whether "Includes AI feature: Yes"
- **Dependencies** — any APIs or services mentioned

---

## Phase 2: Feature Scope Extraction

Group the TO-BE nodes into logical features. Keep names short and concrete.

Present the extracted features to the user, then immediately proceed to Phase 3 without waiting for confirmation:

> "🔍 **서비스 기획 문서 분석 완료**
>
> 아래 피쳐들을 추출했습니다:
>
> 1. **{Feature Name}** — {one-line description}
> 2. **{Feature Name}** — {one-line description}
>
> 모든 피쳐에 대해 케이스 초안 작성을 시작합니다."

Do not wait for a response — proceed directly to Phase 3.

---

## Phase 3: Case Draft + Focused Q&A

For each confirmed feature, do the following **before asking the user anything**:

### Step A — Draft Cases Autonomously

Using the service planning doc and your knowledge of industry-standard patterns, draft the full case list for the feature. Cover:

- **✅ Happy Path** — the normal successful flow
- **⚠️ Edge Cases** — boundary conditions, repeated actions, concurrent use
- **❌ Error Cases** — network failure, auth expiry, server errors, invalid input

When presenting the draft to the user, use this format:

> 📌 **Task {N}: {Feature Name}**
>
> **✅ Happy Path**
>
> - {case}
>
> **⚠️ Edge Cases**
>
> - {case}
>
> **❌ Error Cases**
>
> - {case}

For each case, apply the appropriate standard handling pattern:

| Situation                         | Industry Standard Default                                  |
| --------------------------------- | ---------------------------------------------------------- |
| Network disconnects mid-operation | Show error with retry option                               |
| Auth session expires              | Redirect to login, preserve return URL                     |
| Server / storage error            | Show error message, allow retry                            |
| Empty / no input                  | Disable action button until valid input exists             |
| Duplicate submission              | Debounce or disable button after first click               |
| Input exceeds size limit          | Validate immediately on selection, block before submission |
| AI no response / timeout          | Show timeout message, offer retry or manual fallback       |
| AI empty response                 | Treat as failure, prompt retry                             |

Only deviate from these defaults when the service planning doc or product context gives a clear reason to.

### Step B — Ask Only What You Cannot Infer

After drafting, identify the cases where the correct behavior is a **product decision** that cannot be reasonably assumed — things like:

- A specific numeric threshold not stated in the planning doc (e.g., file size limit, retry count)
- A duplicate handling policy with real UX consequences (block silently? warn? overwrite?)
- A specific error message copy the team cares about

Ask only those questions, numbered, in a single message. Do not ask about standard error handling patterns you already covered in Step A.

> "✋ **확인이 필요한 항목**
>
> 1. {specific product decision}
> 2. {specific product decision}"

If there is nothing genuinely unclear, skip this step entirely and proceed to Phase 4.

### Step C — Priority Table

After confirming cases, classify each by priority:

- **P0** — must ship; blocking the core flow
- **P1** — important; should ship this sprint if time allows
- **P2** — nice to have; document but defer

Propose the priority for each case. P2 items stay in the document but are marked as deferred.

---

## Phase 4: Requirements Q&A

Ask requirements as a single grouped message. Pre-fill every field you can infer from the service planning doc — only leave blank what you genuinely do not know.

> "📋 **요구사항 초안** — 빈칸이나 수정이 필요한 항목만 알려주세요:
>
> - **목표:** {pre-filled or blank}
> - **대상 유저:** {pre-filled or blank}
> - **성공 기준:** {pre-filled or blank}
> - **IN Scope:** {pre-filled list}
> - **OUT of Scope:** {pre-filled list}
> - **데이터 요구사항:** {pre-filled or "없음"}
> - **의존성:** {pre-filled from planning doc or blank}
> - **목표 마감일:** {blank}"

If data requirements are left blank without a clear reason, flag once:

> "⚠️ 데이터 요구사항을 지금 확인해두지 않으면 개발 완료 후 DB 구조를 처음부터 다시 설계해야 할 수 있어요. 새로 저장해야 하는 데이터가 있을까요?"

---

## Phase 5: Document Generation and Save

Generate a **single Markdown file** for the whole planning session. Each feature becomes a numbered task within the document.

```markdown
# 피쳐 기획: {기획 문서 제목}

**작성일:** YYYY-MM-DD
**출처:** docs/planning/{source-filename}

---

## Task 1: {기능명}

### 케이스 목록

#### ✅ 정상 흐름 (Happy Path)

- {케이스}

#### ⚠️ 엣지 케이스

- {케이스}

#### ❌ 오류 케이스

- {케이스}

### 우선순위 테이블

| 케이스    | 우선순위 | 이번 포함 여부 |
| --------- | -------- | -------------- |
| 정상 흐름 | P0       | 예             |
| {케이스}  | {P1/P2}  | {예/아니오}    |

### 요구사항

**목표:** {한 문장 목표}
**대상 유저:** {역할}
**성공 기준:** {측정 가능한 기준}

**IN Scope:**

- {항목}

**OUT of Scope:**

- {항목}

**데이터 요구사항:** {무엇을, 어디에 — 또는 "없음"}
**의존성:** {목록 — 또는 "없음"}
**목표 마감일:** {날짜 또는 미정}

---

## Task 2: {기능명}

{동일한 구조}
```

### Save Path

`~/.pipeline/docs/{project}/feature/YYYYMMDD-{kebab-case-from-planning-title}.md`

`{project}` is read from `~/.pipeline/config.json`. Derive the filename from the planning document's title. Create the directory automatically if it does not exist.

### Document Language

Write all output document content in Korean.

### After Saving

> "✅ **Feature planning document saved:** `docs/feature/YYYYMMDD-{name}.md`
> Next step is design. Review the case list and requirements with your tech lead before moving to implementation."

Then immediately ask:

> "지금 바로 GitHub에 올릴까요? (y/n)"

- **y** → trigger the `gh-pipeline-push` skill immediately for the saved file.
- **n** → end here.
