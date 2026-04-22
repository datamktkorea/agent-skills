---
name: bootstrap
description: Initializes or adds to the DMK workflow config. Collects org, project name, repos, team, Notion integration, and GitHub Project for task tracking. Saves to ~/.datamktkorea/config.json. Supports multiple projects in one config. Works from any directory. Use this skill when the user says "setup", "initialize pipeline", "create the project board", "새 프로젝트 추가", "파이프라인 설정", "처음 설정해줘", or when other dmk-pipeline skills detect that ~/.datamktkorea/config.json is missing and direct the user here.
---

# gh-pipeline-setup

Initializes the DMK workflow for a project. Architecture: **Notion = 문서 SSOT, GitHub = 작업 실행 레이어**. Supports multiple projects in a single config.

Saves to `~/.datamktkorea/config.json` so all skills work from any directory.

---

## Pre-flight Check

Verify `gh` is authenticated:

```bash
gh auth status
```

If not authenticated, stop:

> "Please run `gh auth login` first."

Also inform the user:

> "이 셋업은 Notion Integration 토큰도 필요합니다.
> 준비하려면: https://www.notion.so/my-integrations → New integration → Internal → Submit
> 생성 후 Internal Integration Secret(`secret_...`) 를 복사해두세요.
> 준비되셨나요? (y/n)"

If **n**, stop and guide the user to prepare.

---

## Step 1 — Check existing config

Read `~/.datamktkorea/config.json` if it exists.

**If config exists and already has projects:** inform the user and ask:

> "Found existing projects: {PROJECT_LIST}
> Would you like to:
>
> 1. Add a new project
> 2. Overwrite an existing project
> 3. Update (fields only) an existing project"

**If config does not exist:** proceed to Step 2 (fresh setup).

---

## Step 2 — Get org

Try to detect the org from the current directory's git remote:

```bash
gh repo view --json owner -q '.owner.login' 2>/dev/null
```

If detected, confirm:

> "Detected org: `{ORG}`. Is this correct? (yes / enter different org name)"

---

## Step 3 — Get project name

Ask:

> "What is the project name? (e.g., bingbong-bookie, payments-service)
> This is the logical work unit — not the org name or repo name."

If the name already exists in the config and the user chose "Add new project", warn:

> "Project `{NAME}` already exists. Continuing will overwrite it. Proceed? (yes/no)"

---

## Step 4 — Get associated repos

Ask:

> "Which repos should tasks be created in? Enter repo names separated by commas.
> (e.g., dmk-bingbong-web, dmk-bingbong-api)"

Validate each:

```bash
gh repo view {ORG}/{REPO} --json name -q '.name' 2>/dev/null
```

If a repo does not exist:

> "Could not find `{ORG}/{REPO}`. Did you mean something else, or skip this one?"

Collect only the validated repos.

### Step 4b — Get local code paths (strongly recommended)

For each validated repo, try to auto-detect the local path:

```bash
# If current directory's git remote matches this repo, suggest it
gh repo view --json name -q '.name' 2>/dev/null
```

If matched:

> "로컬 코드 경로를 감지했습니다: `{CURRENT_DIR}` → `{REPO_NAME}`
> 이 경로를 사용할까요? (y / 다른 경로 입력 / skip)"

For remaining repos:

> "각 레포의 로컬 코드 경로를 입력해주세요. (없으면 Enter로 건너뜀)
>
> ⚠️ 로컬 경로가 있으면 AI가 코드를 읽어 피쳐 기획의 정확도가 크게 올라갑니다. 권장합니다.
>
> {REPO_1} local path: "
> {REPO_2} local path: "

Validate existence: `test -d {PATH} && echo exists`

If path does not exist: "경로를 찾을 수 없습니다. 그래도 저장할까요? (y/n)"

### Step 4c — Designate primary repo

If multiple repos were collected:

> "Task 배정이 애매할 때 기본으로 사용할 레포를 선택해주세요. (보통 프론트엔드 레포 권장)
>
> {REPO_LIST 번호로 표시}"

If only one repo, skip and use it automatically. Save as `{PRIMARY_REPO}`.

---

## Step 5 — Register team members

Ask:

> "이 프로젝트에 참여하는 팀원들을 등록할까요? (y/n)
> 등록하면 Task 배정 시 번호로 선택할 수 있습니다."

If **y**, collect one per line until empty line:

> "팀원을 입력해주세요. 형식: 이름 GitHub아이디 역할 (예: 토미 tommy-dmk fullstack)
> (빈 줄로 완료)"

Validate each GitHub user:

```bash
gh api users/{github} -q '.login' 2>/dev/null
```

If validation fails: "GitHub 계정 `{github}`를 찾을 수 없습니다. 그래도 저장할까요? (y/n)"

If **n**, skip — `team` field will be `[]`.

---

## Step 6 — Set up Notion integration

### Step 6a — Collect the token

Ask:

> "준비하신 Notion Integration 토큰을 붙여주세요. (secret_로 시작)"

Validate the token by calling Notion API:

```bash
curl -s https://api.notion.com/v1/users/me \
  -H "Authorization: Bearer {NOTION_TOKEN}" \
  -H "Notion-Version: 2022-06-28" | jq -r '.type'
```

If the response is not `bot`, warn and ask to re-enter.

### Step 6b — Guide the user through DB setup

Explain what needs to be created in Notion:

> "Notion에 3개의 데이터베이스가 필요합니다. 이미 있으면 해당 ID만 알려주시고, 없으면 제가 안내해드릴게요.
>
> **DB 1: 개발 요청** — 비개발자가 자유롭게 요청을 작성하는 곳 (팀 기존 DB 사용)
>    필수 속성: 이름(Title), 유형(Select), 화면(Multi-select), 담당자(People), 상태(Status — Notion 네이티브), 프로젝트(Select)
>    유형 옵션: 기능 에러, 기능 추가, 기능 개선 및 변경
>    상태: Notion 네이티브 Status 그룹 사용 (Select 아님) — 옵션: 요청사항 / 진행중 / 반려 / 해결
>    상세 설명은 페이지 본문에 작성
>
> **DB 2: 트리거** — write-trigger가 저장하는 곳
>    필수 속성: 이름(Title), 유형(Select), 우선순위(Select), 프로젝트(Select),
>              요청원본(Relation → DB 1), 상태(Select), 작성일(Date)
>    유형 옵션: Fix, Build, Improve, Strategy
>    우선순위 옵션: P0, P1, P2, P3
>    상태 옵션: 작성완료, 기획중, 완료
>    ⚠️ Problem Statement, 배경 및 맥락, 기대 결과는 속성이 아닌 페이지 본문(body)에 heading_2 + paragraph 블록으로 저장
>
> **DB 3: 피쳐 기획** — write-feature-planning이 저장하는 곳
>    필수 속성: 이름(Title), GitHub Tasks(URL — 단일 URL), Trigger(Relation → DB 2),
>              프로젝트(Select), 상태(Select), 작성일(Date)
>    상태 옵션: 작성완료, 개발중, 완료
>    ⚠️ 경험 브리프는 DB 속성 없음 — 페이지 본문 첫 번째 섹션(heading_2 + paragraph)으로 저장
>
> 3개 DB 모두 생성한 후, 각 DB의 `... → Add connections`에서 방금 만든 Integration을 추가해주세요.
> 완료되셨나요? (y/n)"

If **n**, pause and wait.

### Step 6c — Collect the 3 DB IDs

For each DB, ask:

> "**{DB_NAME}**의 URL 또는 ID를 붙여주세요.
> (URL 형식: https://notion.so/workspace/DB_NAME-{ID}?v=...)"

Extract the 32-char hex ID from either the URL or the raw ID. Validate each by calling the Notion API:

```bash
curl -s -X POST https://api.notion.com/v1/databases/{DB_ID}/query \
  -H "Authorization: Bearer {NOTION_TOKEN}" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{"page_size": 1}' | jq -r '.object'
```

If response object is not `list`, the Integration does not have access. Show:

> "⚠️ Integration이 이 DB에 연결되지 않았습니다. Notion에서 DB → `...` → Add connections → 방금 만든 Integration을 추가해주세요. 다시 시도할까요? (y/n)"

Save as `{REQUEST_DB_ID}`, `{TRIGGER_DB_ID}`, `{FEATURE_DB_ID}`.

---

## Step 7 — Select or create GitHub Project

Ask:

> "Would you like to create a new GitHub Project for task tracking or link to an existing one?
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

Extract `number` and `id`.

### If existing project:

```bash
gh project list --owner {ORG} --format json \
  --jq '.projects[] | "#\(.number) \(.title)"'
```

Show list, let user pick, extract number + id.

---

## Step 8 — Create task label

Create the `pipeline:task` label in each repo:

```bash
for repo in {REPOS}; do
  gh label create "pipeline:task" --color "0e8a16" --repo {ORG}/$repo 2>/dev/null || true
done
```

This is the only label created. Task Issues use this label; nothing else needs a pipeline-specific label.

---

## Step 9 — Save config

Read existing `~/.datamktkorea/config.json` (or start with `{"projects": {}}`), then add or overwrite:

```json
{
  "notion_token": "{NOTION_TOKEN}",
  "notion_dbs": {
    "request_db": "{REQUEST_DB_ID}",
    "trigger_db": "{TRIGGER_DB_ID}",
    "feature_db": "{FEATURE_DB_ID}"
  },
  "projects": {
    "{PROJECT_NAME}": {
      "org": "{ORG}",
      "github_project_number": {NUMBER},
      "github_project_id": "{PROJECT_ID}",
      "primary_repo": "{PRIMARY_REPO}",
      "repos": [
        {"name": "{REPO_1}", "local_path": "{/absolute/path/to/repo1}"},
        {"name": "{REPO_2}"}
      ],
      "team": [
        {"name": "토미",   "github": "tommy-dmk",   "role": "fullstack"},
        {"name": "키위",   "github": "kiwi-dmk",    "role": "backend"}
      ]
    }
  }
}
```

Notes:
- `notion_token` is stored at the root level (shared across projects).
- `notion_dbs` is at the root level (shared across projects) — NOT nested under each project.
- Existing projects in the config are preserved.
- No more `status_field_id` / `status_options` — GitHub's native Status field is used directly.

---

## Step 10 — Create default board view

Create a single task board view on the GitHub Project:

```bash
gh api graphql -f query='
mutation {
  createProjectV2View(input: {
    projectId: "{PROJECT_ID}"
    name: "Tasks"
    layout: BOARD_LAYOUT
  }) {
    projectV2View { id }
  }
}'
```

This view should be configured (manually in the GitHub web UI) with:
- Filter: `label:pipeline:task`
- Group by: Status

If view creation fails, show:

> "⚠️ Board 뷰 자동 생성에 실패했습니다. GitHub Project에서 수동으로 뷰를 추가해주세요:
> - 이름: Tasks
> - 레이아웃: Board
> - 필터: label:pipeline:task
> - 그룹: Status"

Optional additional views the user can create manually:
- **"내 작업"** — Board, filter `assignee:@me`, group Status
- **"단계별 현황"** — (Same as Tasks with extra filters)

---

## Done

> "✅ DMK workflow setup complete.
>
> Project:      {PROJECT_NAME}
> Org:          {ORG}
> Primary repo: {PRIMARY_REPO}
> Repos:        {REPO_LIST}
> Team:         {TEAM_COUNT} members
> Notion:       ✓ Request DB / Trigger DB / Feature DB 연결됨
> GitHub:       Project #{NUMBER} | pipeline:task 라벨 생성됨
> Config:       ~/.datamktkorea/config.json
>
> 다음 단계:
> 1. 비개발자에게 Notion 개발 요청 DB 공유하기
> 2. write-trigger 실행 → 요청을 트리거로 구조화
> 3. write-feature-planning 실행 → 에이전트 레디 스펙 생성
> 4. gh-pipeline-push 실행 → GitHub Task 생성"
