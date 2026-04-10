---
name: gh-pipeline-setup
description: Initializes or adds to the AI development pipeline config. Collects org, project name, and repos, creates a GitHub Project with all 7 pipeline stages as a Status field, and saves to ~/.pipeline/config.json. Supports multiple projects in one config. Works from any directory. Use this skill when the user says "setup", "initialize pipeline", "create the project board", "새 프로젝트 추가", "파이프라인 설정", "처음 설정해줘", or when gh-pipeline-push detects that ~/.pipeline/config.json is missing and directs the user here.
---

# gh-pipeline-setup

Initializes the AI development pipeline for a project. Supports multiple projects in a single config — run this once per project, not once per machine.

Saves to `~/.pipeline/config.json` so all skills work from any directory.

---

## Pre-flight Check

Verify `gh` is authenticated:

```bash
gh auth status
```

If not authenticated, stop:

> "Please run `gh auth login` first."

---

## Step 1 — Check existing config

Read `~/.pipeline/config.json` if it exists.

**If config exists and already has projects:** inform the user and ask:

> "Found existing projects: {PROJECT_LIST}
> Would you like to:
>
> 1. Add a new project
> 2. Overwrite an existing project"

**If config does not exist:** proceed to Step 2 (fresh setup).

---

## Step 2 — Get org

Try to detect the org from the current directory's git remote:

```bash
gh repo view --json owner -q '.owner.login' 2>/dev/null
```

If detected, confirm with the user:

> "Detected org: `{ORG}`. Is this correct? (yes / enter different org name)"

If not detected or the user provides a different name, use what the user provides.

---

## Step 3 — Get project name

Ask:

> "What is the project name? (e.g., bingbong-bookie, payments-service)"

This is the logical name for the work unit — not the org name or repo name. It will be used to organize local docs under `~/.pipeline/docs/{project}/` and as the key in config.

If the name already exists in the config and the user chose "Add new project", warn:

> "Project `{NAME}` already exists. Continuing will overwrite it. Proceed? (yes/no)"

---

## Step 4 — Get associated repos

Ask:

> "Which repos should Issues be linked to? Enter repo names separated by commas.
> (e.g., dmk-bingbong-web, dmk-bingbong-api)"

For each repo the user enters, validate it exists in the org:

```bash
gh repo view {ORG}/{REPO} --json name -q '.name' 2>/dev/null
```

If a repo does not exist, ask the user to confirm:

> "Could not find `{ORG}/{REPO}`. Did you mean something else, or skip this one?"

Collect only the validated repos.

---

## Step 5 — Select or create GitHub Project

Ask:

> "Would you like to create a new GitHub Project or link to an existing one?
>
> 1. Create new project
> 2. Use existing project"

### If new project:

Ask:

> "What should the GitHub Project be called?"

Create it:

```bash
gh project create --owner {ORG} --title "{PROJECT_TITLE}" --format json
```

Extract `number` and `id` from the result.

### If existing project:

List the org's projects and extract number + id in one call:

```bash
gh project list --owner {ORG} --format json \
  --jq '.projects[] | "#\(.number) \(.title)"'
```

Show the list and let the user pick. Extract `number` and `id` from the same response:

```bash
gh project list --owner {ORG} --format json \
  --jq '.projects[] | select(.number == {SELECTED_NUMBER}) | {number: .number, id: .id}'
```

---

## Step 6 — Initialize "Pipeline Stage" field

First, check whether the field already exists on the project:

```bash
gh api graphql -f query='
{
  node(id: "{PROJECT_ID}") {
    ... on ProjectV2 {
      fields(first: 20) {
        nodes {
          ... on ProjectV2SingleSelectField {
            id
            name
            options { id name }
          }
        }
      }
    }
  }
}' --jq '.data.node.fields.nodes[] | select(.name == "Pipeline Stage")'
```

**If the field already exists:** extract and reuse its `id` and each option's `id`. Skip creation.

**If the field does not exist:** create it:

```bash
gh api graphql -f query='
mutation {
  createProjectV2Field(input: {
    projectId: "{PROJECT_ID}"
    dataType: SINGLE_SELECT
    name: "Pipeline Stage"
    singleSelectOptions: [
      {name: "Trigger", color: RED, description: ""}
      {name: "Service Planning", color: ORANGE, description: ""}
      {name: "Feature Planning", color: YELLOW, description: ""}
      {name: "Design", color: GREEN, description: ""}
      {name: "Development", color: BLUE, description: ""}
      {name: "Verification", color: PURPLE, description: ""}
      {name: "Deployment", color: GRAY, description: ""}
    ]
  }) {
    projectV2Field {
      ... on ProjectV2SingleSelectField {
        id
        options { id name }
      }
    }
  }
}'
```

Create pipeline labels in each repo:

```bash
for repo in {REPOS}; do
  for stage in "pipeline:trigger" "pipeline:service-planning" "pipeline:feature-planning" \
               "pipeline:design" "pipeline:development" "pipeline:verification" "pipeline:deployment"; do
    gh label create "$stage" --color 0075ca --repo {ORG}/$repo 2>/dev/null || true
  done
done
```

---

## Step 7 — Save config

Read the existing `~/.pipeline/config.json` (or start with `{"projects": {}}`), then add or overwrite the entry for this project:

```json
{
  "projects": {
    "{PROJECT_NAME}": {
      "org": "{ORG}",
      "github_project_number": {NUMBER},
      "github_project_id": "{PROJECT_ID}",
      "status_field_id": "{FIELD_ID}",
      "status_options": {
        "Trigger": "{OPTION_ID}",
        "Service Planning": "{OPTION_ID}",
        "Feature Planning": "{OPTION_ID}",
        "Design": "{OPTION_ID}",
        "Development": "{OPTION_ID}",
        "Verification": "{OPTION_ID}",
        "Deployment": "{OPTION_ID}"
      },
      "repos": ["{REPO_1}", "{REPO_2}"]
    }
  }
}
```

Existing projects in the config are preserved.

---

## Done

> "✅ Pipeline setup complete.
>
> Project: {GITHUB_PROJECT_TITLE} (#{NUMBER})
> Context: {ORG} / {PROJECT_NAME}
> Repos: {REPO_LIST}
> Stages: Trigger → Service Planning → Feature Planning → Design → Development → Verification → Deployment
> Config: ~/.pipeline/config.json
>
> You can now use write-trigger, write-service-planning, write-feature-planning, and gh-pipeline-push."
