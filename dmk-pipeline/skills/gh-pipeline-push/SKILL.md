---
name: gh-pipeline-push
description: Publishes locally created pipeline documents (from write-trigger, write-service-planning, write-feature-planning) to GitHub Issues and links them to the GitHub Project pipeline board (Trigger → Service Planning → Feature Planning → Design → Development → Verification → Deployment). Works from any directory. Use this skill whenever the user says things like "깃헙에 올려", "이슈로 올려", "프로젝트에 등록해", "push to github", "publish this", "gh-pipeline-push", "upload to project", "팀이랑 공유하고 싶어", or wants to share a local planning document with the team. If a user has just finished writing a trigger/service/feature planning doc and wants to share it — trigger this skill without waiting to be asked.
---

# gh-pipeline-push

Publishes a local pipeline document to GitHub and registers it on the pipeline board.

**Core model — Epic + Sub-issues:**

| Stage | Action |
|---|---|
| Trigger | Create a new parent Issue (the Epic). One Issue per feature/bug, tracked end-to-end. |
| Service Planning / Feature Planning / Design | Create a sub-issue under the parent. Update Pipeline Stage on the parent. |
| Development / Verification / Deployment | Create a sub-issue under the parent. Update Pipeline Stage on the parent. |

Works from any directory — reads config from `~/.pipeline/config.json` and docs from `~/.pipeline/docs/{project}/`.

---

## Pre-flight Check

### 1. Verify `gh` authentication

```bash
gh auth status
```

If not authenticated, stop:

> "Please run `gh auth login` first."

### 2. Verify pipeline config

Check whether `~/.pipeline/config.json` exists.

If it does **not** exist, stop and tell the user:

> "Pipeline is not set up yet. Starting `gh-pipeline-setup` now..."

Then trigger the `gh-pipeline-setup` skill immediately — do not wait for the user to ask.

---

## Step 1 — Load config and detect project

Read `~/.pipeline/config.json` and resolve which project to use:

1. Count projects in `config.projects`:
   - **1 project** → use it automatically.
   - **Multiple projects** → go to step 2.

2. Try to detect from the current git remote:
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

Extract the resolved project's fields: `org`, `github_project_number`, `github_project_id`, `status_field_id`, `status_options`, `repos`.

---

## Step 2 — Select document to publish

Scan for MD files matching `YYYYMMDD-*.md` under `~/.pipeline/docs/{project}/`, sorted by most recently modified:

| Directory                              | Pipeline Stage   |
| -------------------------------------- | ---------------- |
| `~/.pipeline/docs/{project}/trigger/`  | Trigger          |
| `~/.pipeline/docs/{project}/planning/` | Service Planning |
| `~/.pipeline/docs/{project}/feature/`  | Feature Planning |
| `~/.pipeline/docs/{project}/design/`   | Design           |
| `~/.pipeline/docs/{project}/dev/`      | Development      |
| `~/.pipeline/docs/{project}/qa/`       | Verification     |
| `~/.pipeline/docs/{project}/deploy/`   | Deployment       |

Present the list and let the user choose:

```
Which document would you like to publish?

1. ~/.pipeline/docs/bookie/trigger/20260410-asset-upload.md     [Trigger]
2. ~/.pipeline/docs/bookie/planning/20260410-asset-upload.md    [Service Planning]
```

If only one file exists, proceed without asking.

If no files are found, stop:

> "No documents found. Use a write-\* skill to create one first."

---

## Step 3 — Select target repo

Show the repos from config and let the user choose:

```
Which repo should this Issue be created in?

1. dmk-bookie-web
2. dmk-bookie-api
```

Validate the selected repo exists:

```bash
gh repo view {ORG}/{REPO} --json name -q '.name' 2>/dev/null
```

If validation fails, ask the user to confirm or pick again.

---

## Step 4 — Find parent Issue (all stages except Trigger)

**Skip this step for Trigger** — Trigger creates the parent Issue itself.

For all other stages, find the parent Epic Issue:

```bash
gh issue list \
  --repo {ORG}/{REPO} \
  --label "pipeline:epic" \
  --state open --limit 10 \
  --json number,title,createdAt \
  --jq '.[] | "#\(.number) \(.title) (\(.createdAt[:10]))"'
```

Show the list and ask the user to select the parent:

```
Select the parent Trigger Issue:

1. #12 Asset file upload 10MB limit (2026-04-08)
2. #9 TOC generation stuck on navigation (2026-04-07)
```

Save the selected parent Issue number and repo.

---

## Step 5 — Publish the document

### A. Trigger stage → Create parent Issue

Extract the title from the MD file using this priority order:

1. First `# Heading` — skip if it is a generic template heading (e.g., "트리거 문서", "서비스 기획", "Feature Planning", "Service Planning: ...")
2. Second `# Heading` or first `## Heading` — if the first was generic
3. Filename without date prefix and extension, converted to Title Case (e.g., `20260410-asset-file-upload-10mb-limit.md` → `Asset File Upload 10MB Limit`)

```bash
gh issue create \
  --repo {ORG}/{REPO} \
  --title "{title}" \
  --body "$(cat {FILE_PATH})" \
  --label "pipeline:epic"
```

Save the resulting Issue URL and number.

### B. Service Planning / Feature Planning / Design → Create sub-issue

Create a sub-issue and link it to the parent Issue:

```bash
# 1. Create sub-issue
gh issue create \
  --repo {ORG}/{REPO} \
  --title "[{STAGE_NAME}] {PARENT_TITLE}" \
  --body "$(cat {FILE_PATH})" \
  --label "pipeline:{stage-kebab}"
```

Save the resulting sub-issue number. Then get the sub-issue's database ID and link it to the parent Issue:

```bash
# 2. Get database ID of the new sub-issue (required by the API — not the issue number)
SUB_DB_ID=$(gh api graphql -f query="query { repository(owner: \"{ORG}\", name: \"{REPO}\") { issue(number: {SUB_ISSUE_NUMBER}) { databaseId } } }" \
  -q '.data.repository.issue.databaseId')

# 3. Link to parent
gh api --method POST \
  /repos/{ORG}/{REPO}/issues/{PARENT_ISSUE_NUMBER}/sub_issues \
  -F sub_issue_id=$SUB_DB_ID
```

Stage label and title prefix mapping:
- Service Planning → label `pipeline:service-planning`, title prefix `[Service Planning]`
- Feature Planning → label `pipeline:feature-planning`, title prefix `[Feature Planning]`
- Design → label `pipeline:design`, title prefix `[Design]`

### C. Development / Verification / Deployment → Create sub-issue

Extract the title using the same priority order as Trigger.

Stage label format (kebab-case):
- Development → `pipeline:development`
- Verification → `pipeline:verification`
- Deployment → `pipeline:deployment`

```bash
# 1. Create the sub-issue
gh issue create \
  --repo {ORG}/{REPO} \
  --title "{title}" \
  --body "$(cat {FILE_PATH})" \
  --label "pipeline:{STAGE_KEBAB}"
```

Save the sub-issue number. Then get the database ID and link it to the parent Issue:

```bash
# 2. Get database ID (required by the API — not the issue number)
SUB_DB_ID=$(gh api graphql -f query="query { repository(owner: \"{ORG}\", name: \"{REPO}\") { issue(number: {SUB_ISSUE_NUMBER}) { databaseId } } }" \
  -q '.data.repository.issue.databaseId')

# 3. Add sub-issue to parent
gh api --method POST \
  /repos/{ORG}/{REPO}/issues/{PARENT_ISSUE_NUMBER}/sub_issues \
  -F sub_issue_id=$SUB_DB_ID
```

---

## Step 6 — Add to Project and update Pipeline Stage

**Status rules** — always update Status alongside Pipeline Stage:

| Pipeline Stage | Status to set |
|---|---|
| Trigger | Todo |
| Service Planning, Feature Planning, Design, Development, Verification | In Progress |
| Deployment | Done |

The `status_field_id` and option IDs for Status come from the project's Status field (separate from Pipeline Stage). Fetch them at runtime if not cached:

```bash
gh api graphql -f query='
  query {
    node(id: "{GITHUB_PROJECT_ID}") {
      ... on ProjectV2 {
        fields(first: 20) {
          nodes {
            ... on ProjectV2SingleSelectField { id name options { id name } }
          }
        }
      }
    }
  }
' --jq '.data.node.fields.nodes[] | select(.name == "Status" or .name == "Pipeline Stage")'
```

### For Trigger stage (new parent Issue)

Add the Issue to the Project, set Pipeline Stage to Trigger, and set Status to **Todo**:

```bash
ITEM_ID=$(gh project item-add {GITHUB_PROJECT_NUMBER} \
  --owner {ORG} \
  --url {ISSUE_URL} \
  --format json \
  --jq '.id')
```

```bash
# Set Pipeline Stage
gh api graphql -f query='
  mutation {
    updateProjectV2ItemFieldValue(input: {
      projectId: "{GITHUB_PROJECT_ID}"
      itemId: "{ITEM_ID}"
      fieldId: "{PIPELINE_STAGE_FIELD_ID}"
      value: { singleSelectOptionId: "{PIPELINE_STAGE_OPTION_ID}" }
    }) { projectV2Item { id } }
  }
'

# Set Status → Todo
gh api graphql -f query='
  mutation {
    updateProjectV2ItemFieldValue(input: {
      projectId: "{GITHUB_PROJECT_ID}"
      itemId: "{ITEM_ID}"
      fieldId: "{STATUS_FIELD_ID}"
      value: { singleSelectOptionId: "{STATUS_OPTION_ID_TODO}" }
    }) { projectV2Item { id } }
  }
'
```

### For all stages except Trigger (sub-issue)

Sub-issues are automatically added to the Project when created (because the repo is connected to the Project). Leave sub-issues in the Project — they are visible on the board and can be filtered out by the user as needed.

Update Pipeline Stage and Status on the **parent Epic's** project item.

Status by stage:
- Service Planning, Feature Planning, Design, Development, Verification → **In Progress**
- Deployment → **Done**

For **Deployment** stage only — after updating Status to Done, also close the parent Issue:

```bash
gh issue close {PARENT_ISSUE_NUMBER} \
  --repo {ORG}/{REPO} \
  --comment "Deployment complete. Closing Epic."
```

---

## Done

**Trigger:**
```
✅ Parent Issue created

Issue:   #{NUMBER} {TITLE}
URL:     {ISSUE_URL}
Repo:    {ORG}/{REPO}
Project: Pipeline Stage → Trigger | Status → Todo
```

**Service Planning / Feature Planning / Design:**
```
✅ Sub-issue created

Sub-issue: #{NUMBER} {TITLE}
Parent:    #{PARENT_NUMBER} {PARENT_TITLE}
Project:   Pipeline Stage → {STAGE} | Status → In Progress
```

**Development / Verification:**
```
✅ Sub-issue created

Sub-issue: #{NUMBER} {TITLE}
Parent:    #{PARENT_NUMBER} {PARENT_TITLE}
Project:   Pipeline Stage → {STAGE} | Status → In Progress
```

**Deployment:**
```
✅ Sub-issue created. Epic closed.

Sub-issue: #{NUMBER} {TITLE}
Parent:    #{PARENT_NUMBER} {PARENT_TITLE} (closed)
Project:   Pipeline Stage → Deployment | Status → Done
```

---

## Error Handling

| Situation              | Response                                                        |
| ---------------------- | --------------------------------------------------------------- |
| `gh` not installed     | "GitHub CLI is required: `brew install gh`"                     |
| Not authenticated      | "Please run `gh auth login`."                                   |
| Config missing         | Trigger `gh-pipeline-setup`                                     |
| No MD files found      | "No documents found. Use a write-\* skill to create one first." |
| Repo not found         | Ask user to confirm repo name                                   |
| Parent Issue not found | Ask user to provide the parent Issue number manually            |
| Issue creation fails   | Print the error as-is and stop                                  |
| Sub-issue link fails   | Warn the user and provide the manual linking command            |
