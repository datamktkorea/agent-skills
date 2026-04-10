---
name: gh-pipeline-push
description: Publishes locally created pipeline documents (from write-trigger, write-service-planning, write-feature-planning) to GitHub Issues and links them to the GitHub Project pipeline board (Trigger → Service Planning → Feature Planning → Design → Development → Verification → Deployment). Works from any directory. Use this skill whenever the user says things like "깃헙에 올려", "이슈로 올려", "프로젝트에 등록해", "push to github", "publish this", "gh-pipeline-push", "upload to project", "팀이랑 공유하고 싶어", or wants to share a local planning document with the team. If a user has just finished writing a trigger/service/feature planning doc and wants to share it — trigger this skill without waiting to be asked.
---

# gh-pipeline-push

Publishes a local planning document to a GitHub Issue and registers it on the pipeline board.

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

Show the repos from config and let the user choose where to create the Issue:

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

## Step 4 — Link to previous stage Issue (skip for Trigger)

| Publishing stage | Previous stage   |
| ---------------- | ---------------- |
| Service Planning | Trigger          |
| Feature Planning | Service Planning |
| Design           | Feature Planning |
| Development      | Design           |
| Verification     | Development      |
| Deployment       | Verification     |

Fetch recent open Issues from the previous stage in the selected repo:

```bash
gh issue list \
  --repo {ORG}/{REPO} \
  --label "pipeline:{PREV_STAGE_KEBAB}" \
  --state open --limit 10 \
  --json number,title,createdAt \
  --jq '.[] | "#\(.number) \(.title) (\(.createdAt[:10]))"'
```

Show the list and let the user pick:

```
Select the Trigger Issue to link:

1. #12 Asset file upload 10MB limit (2026-04-08)
2. Skip — publish without linking
```

---

## Step 5 — Create GitHub Issue

Extract the title from the MD file using this priority order:

1. First `# Heading` — but skip if it is a generic template heading (e.g., "트리거 문서", "서비스 기획", "Feature Planning", "Service Planning: ...")
2. Second `# Heading` or first `## Heading` — if the first was generic
3. Filename without date prefix and extension, converted to Title Case (e.g., `20260410-asset-file-upload-10mb-limit.md` → `Asset File Upload 10MB Limit`)

Always prepend the stage in brackets: `[Trigger] {title}`, `[Service Planning] {title}`, etc.

Stage label format (kebab-case):

- Trigger → `pipeline:trigger`
- Service Planning → `pipeline:service-planning`
- Feature Planning → `pipeline:feature-planning`
- Design → `pipeline:design`
- Development → `pipeline:development`
- Verification → `pipeline:verification`
- Deployment → `pipeline:deployment`

```bash
gh issue create \
  --repo {ORG}/{REPO} \
  --title "{EXTRACTED_TITLE}" \
  --body "$(cat {FILE_PATH})" \
  --label "pipeline:{STAGE_KEBAB}"
```

Save the resulting Issue URL and number.

---

## Step 6 — Add to Project and set stage

Add the Issue to the Project:

```bash
ITEM_ID=$(gh project item-add {GITHUB_PROJECT_NUMBER} \
  --owner {ORG} \
  --url {ISSUE_URL} \
  --format json \
  --jq '.id')
```

Set the Pipeline Stage field:

```bash
gh api graphql -f query='
  mutation {
    updateProjectV2ItemFieldValue(input: {
      projectId: "{GITHUB_PROJECT_ID}"
      itemId: "{ITEM_ID}"
      fieldId: "{STATUS_FIELD_ID}"
      value: { singleSelectOptionId: "{OPTION_ID}" }
    }) { projectV2Item { id } }
  }
'
```

---

## Step 7 — Record parent link

If the user selected a parent Issue, add a comment to the new Issue:

```bash
gh issue comment {NEW_ISSUE_NUMBER} \
  --repo {ORG}/{REPO} \
  --body "**Pipeline link:** Relates to #{PARENT_ISSUE_NUMBER}"
```

---

## Done

```
✅ GitHub Issue created

Issue:   #{NUMBER} {TITLE}
URL:     {ISSUE_URL}
Repo:    {ORG}/{REPO}
Project: {GITHUB_PROJECT_TITLE} → {STAGE}
Linked:  #{PARENT_NUMBER} (if applicable)
```

---

## Error Handling

| Situation            | Response                                                        |
| -------------------- | --------------------------------------------------------------- |
| `gh` not installed   | "GitHub CLI is required: `brew install gh`"                     |
| Not authenticated    | "Please run `gh auth login`."                                   |
| Config missing       | Trigger `gh-pipeline-setup`                                     |
| No MD files found    | "No documents found. Use a write-\* skill to create one first." |
| Repo not found       | Ask user to confirm repo name                                   |
| Issue creation fails | Print the error as-is and stop                                  |
