---
name: notion-api
description: Read, query, and write Notion pages and databases via the Notion API (version 2026-03-11) using bundled bash + curl scripts. Use this skill whenever the task touches Notion in any way — reading an arbitrary page to gather development context, looking up a page by title, listing items from a team database, creating a new page, updating properties or content, moving a page to trash. Prefer these scripts over any MCP or ad-hoc curl so behavior stays consistent across the datamktkorea team. Requires `~/.datamktkorea/config.json` (with `notion_token` and `notion_dbs` map) and `jq`.
---

# notion-api

## Purpose

This skill is the shared Notion API layer for the datamktkorea team. It wraps Notion's REST API (version **2026-03-11**) as a handful of bash + curl scripts so every team member — and every other skill in this plugin — calls Notion the same way. Use it when the user asks you to read a Notion page for context, find a record by title, create or update pages in team databases (Requests, Triggers, Specs, Projects, Memos), or do anything else that hits the Notion API. Prefer invoking these scripts over writing one-off curl calls, because they handle auth, version headers, retries, and config resolution uniformly.

## Preconditions

Before using any script, make sure these are in place:

1. **`~/.datamktkorea/config.json`** exists and contains:

   ```json
   {
     "notion_token": "ntn_...",
     "notion_dbs": { "requests_db": "<database_id>", ... }
   }
   ```

   Each team member keeps their own Integration token here. The file must never be committed.

2. **`jq`** is installed (`brew install jq` on macOS).

3. The **Notion Integration** named in the token must be shared with every database you intend to access. A `404 object_not_found` error from the API almost always means the integration hasn't been granted access to that page/database in Notion's UI.

If any precondition is missing, scripts exit with code `2` and a message explaining what to fix.

## Environment

All scripts honor these environment variables:

| Variable         | Default                   | Purpose                                                     |
| ---------------- | ------------------------- | ----------------------------------------------------------- |
| `NOTION_TOKEN`   | loaded from `config.json` | Override the integration token                              |
| `NOTION_VERSION` | `2026-03-11`              | Override the API version header (rarely needed)             |
| `NOTION_DEBUG`   | unset                     | Set to `1` to log request URLs and retry attempts to stderr |

## Script contract

Every script follows the same conventions:

- **stdin**: not used.
- **stdout**: raw Notion API JSON response (passthrough). Parse with `jq` on the caller side.
- **stderr**: error messages, retry notices when `NOTION_DEBUG=1`.
- **exit 0**: success.
- **exit 1**: Notion API error (4xx/5xx after retries exhausted, network failure).
- **exit 2**: precondition failure (missing `jq`, missing/invalid config, empty token).
- **Retries**: On HTTP `429` or any `5xx`, retry up to 3 times. If the response has a `Retry-After` header, sleep for that many seconds; otherwise back off `1s, 2s, 4s`. `401`/`403` do not retry — they indicate an auth or permissions issue you must fix manually.

## Scripts reference

Each script lives at `skills/notion-api/scripts/`. Resolve the path using `${CLAUDE_PLUGIN_ROOT}` when invoking from another skill, e.g. `${CLAUDE_PLUGIN_ROOT}/skills/notion-api/scripts/fetch-page.sh <id>`. During local development without the plugin environment, run them with a direct relative path.

### `fetch-page.sh`

```
fetch-page.sh <page_id_or_url> [--markdown-only] [--include-transcript]
```

Retrieves the page content as Notion-flavored markdown via `GET /v1/pages/{id}/markdown`. Accepts a bare page ID (with or without dashes) or a full Notion URL; the ID is extracted automatically. With `--markdown-only`, outputs only the `.markdown` field as plain text (useful when feeding page content back to Claude as context). `--include-transcript` sets the `include_transcript=true` query param for meeting-note pages.

```bash
fetch-page.sh https://www.notion.so/workspace/Page-Title-abc123... --markdown-only
```

### `fetch-page-properties.sh`

```
fetch-page-properties.sh <page_id_or_url>
```

Retrieves the page object (properties, parent, timestamps) via `GET /v1/pages/{id}`. Use this when you need property values (status, relation, date, etc.) rather than body content.

```bash
fetch-page-properties.sh abc123... | jq '.properties["상태"]'
```

### `query-db.sh`

```
query-db.sh <db_key_or_database_id> [--filter <json>] [--sorts <json>] [--page-size N] [--start-cursor <uuid>] [--all]
```

Queries a data source. Accepts either a config key (e.g. `requests_db`) or a raw `database_id`; internally resolves `database_id → data_source_id` via `GET /v1/databases/{id}` before calling `POST /v1/data_sources/{ds}/query`. `--filter` and `--sorts` take raw Notion filter/sort JSON (see Notion docs). `--all` follows `next_cursor` until `has_more: false` and emits a single merged response.

```bash
query-db.sh requests_db --filter '{"property":"상태","status":{"equals":"진행중"}}' --page-size 10
```

### `create-page.sh`

```
create-page.sh --parent <db_key_or_data_source_id> --properties <json> [--markdown <file_or_-> | --markdown-text <string>]
```

Creates a page via `POST /v1/pages`. `--parent` accepts a config key (auto-resolved to `data_source_id`) or a raw `data_source_id`. `--properties` is the Notion `properties` JSON — the script passes it through unchanged, so the caller is responsible for matching the target schema. Body is passed as Notion-flavored markdown from either a file path (use `-` for stdin) or an inline string. `markdown` and `properties` compose; omit `--markdown*` to create a properties-only page.

```bash
create-page.sh \
  --parent triggers_db \
  --properties '{"이름":{"title":[{"text":{"content":"API 인증 개선"}}]}}' \
  --markdown-text "# Goal\n\n..."
```

### `update-page.sh`

```
update-page.sh <page_id_or_url> --properties <json>
update-page.sh <page_id_or_url> --trash
update-page.sh <page_id_or_url> --restore
```

Patches a page via `PATCH /v1/pages/{id}`. Use `--properties` to update one or more property values. `--trash` sends `{"in_trash": true}`; `--restore` sends `{"in_trash": false}`. Exactly one mode per invocation.

```bash
update-page.sh abc123... --properties '{"상태":{"status":{"name":"완료"}}}'
```

### `update-content.sh`

```
update-content.sh <page_id_or_url> replace --markdown <file_or_->
update-content.sh <page_id_or_url> update --replacements <json>
```

Patches page body via `PATCH /v1/pages/{id}/markdown`. `replace` rewrites the entire body from the given markdown. `update` runs search-and-replace operations; `--replacements` takes a JSON array like `[{"old_str":"...","new_str":"...","replace_all_matches":true}]` (max 100 entries per request).

```bash
update-content.sh abc123... update --replacements '[{"old_str":"TODO","new_str":"Done","replace_all_matches":true}]'
```

## Common patterns

### Find a page by title, then read its content

Pipe `query-db.sh` into `jq` to extract the first match's ID, then fetch the markdown:

```bash
query-db.sh requests_db --filter '{"property":"이름","title":{"contains":"API 인증"}}' \
  | jq -r '.results[0].id' \
  | xargs -I {} fetch-page.sh {} --markdown-only
```

### Create a Trigger page linked to an existing Request

`Triggers DB.Requests DB` is a relation property; set it to the Request's page ID:

```bash
REQUEST_ID=abc123...
create-page.sh \
  --parent triggers_db \
  --properties "$(jq -n --arg rid "$REQUEST_ID" '{
    "이름":      {"title":[{"text":{"content":"Trigger for API auth"}}]},
    "Requests DB": {"relation":[{"id":$rid}]},
    "상태":      {"select":{"name":"대기"}}
  }')" \
  --markdown-text "# Background\n\n..."
```

### Change a page's status property

```bash
update-page.sh abc123... --properties '{"상태":{"status":{"name":"진행중"}}}'
```

Note: `status` and `select` have different JSON shapes in Notion — consult the schema registry below to pick the right one for each property.

## Error handling

| Exit code | Meaning                 | Typical cause                                             | Action                                                                                         |
| --------- | ----------------------- | --------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| 0         | Success                 | —                                                         | —                                                                                              |
| 1         | API error after retries | Bad request body, `object_not_found`, 5xx loop            | Check the stderr message (`code` + `message` from Notion's error response) and fix the request |
| 2         | Precondition failure    | `jq` missing, `config.json` missing, `notion_token` empty | Follow the printed hint                                                                        |

When stderr shows `status: 401 unauthorized` → token is invalid or has been rotated; update `~/.datamktkorea/config.json`. When it shows `status: 404 object_not_found` with a `Make sure the relevant pages and databases are shared with your integration` hint → add the integration to that database in Notion. `429` is handled automatically but repeated hits mean you should reduce parallelism.

## Development tips

- **Running from outside the plugin cache**: When Claude Code installs the plugin, scripts live under `${CLAUDE_PLUGIN_ROOT}/skills/notion-api/scripts/`. When developing locally (before install or via `claude --plugin-dir ./`), invoke them with a relative path like `./skills/notion-api/scripts/fetch-page.sh`. `lib.sh` is sourced via `$(dirname "${BASH_SOURCE[0]}")` so it works either way.
- **Debugging a request**: set `NOTION_DEBUG=1` to see the full URL, HTTP status, and retry decisions on stderr. Token is never logged.
- **Testing against real DBs**: the `requests_db` and read-only queries on `projects_db` are safe to exercise freely. For write tests, create a temp page and delete it with `update-page.sh <id> --trash` afterward.
- **When something looks wrong at the API level**: consult `https://developers.notion.com/llms.txt` to check whether the Notion API version or endpoint surface has changed. Do **not** fetch this routinely during normal script usage — it wastes context. The scripts pin `Notion-Version: 2026-03-11`, and the root `AGENTS.md` already requires checking `llms.txt` whenever this skill is edited.

---

## Database schema registry

> **If a database's properties change in Notion (field added, renamed, or removed), update this section immediately.** Other skills in this plugin rely on these exact property names and types when composing `--properties` payloads.

Each entry lists the config key → title → `data_source_id`, then every property as `이름 [type]`.

### `projects_db` → Projects

`data_source_id: d47fc205-0235-4dc6-b156-843e80a928e7`

- 프로젝트명 [title]
- 프로젝트 유형 [select]
- 엔티티 약어 [select]
- 상태 [select]
- PM [people]
- 엔지니어 [people]
- 프로젝트 별칭 [formula]
- 프로젝트 약어 [rich_text]
- 아카이브 [checkbox]
- 생성일자 [created_time]
- 최근 수정일자 [last_edited_time]
- 생성자 [created_by]
- 최근 수정자 [last_edited_by]

### `requests_db` → Requests

`data_source_id: 33ecd014-3f6e-80c0-b177-000b3e08ac88`

- 이름 [title]
- 상태 [status]
- 우선순위 [select]
- 카테고리 [select]
- 유형 [select]
- 작업 기간 [date]
- 요청자 [people]
- 담당자 [people]
- Triggers DB [relation] → `triggers_db`
- Projects DB [relation] → `projects_db`
- 프로젝트 현황 [rollup]
- 프로젝트 별칭 [rollup]
- 생성 일시 [created_time]
- 최근 수정 일시 [last_edited_time]
- 생성자 [created_by]
- 최근 수정자 [last_edited_by]

### `memos_db` → Memos

`data_source_id: f8b4207b-0330-4d9d-81cf-2604a1c71451`

- 태스크명 [title]
- 종류 [select]
- 완료 여부 [checkbox]
- 담당자 [people]
- Requests [relation] → `requests_db`
- Projects [relation] → `projects_db`
- ID [unique_id]
- 작업 소요일 (삭제 예정) [formula]
- 작업 시작일 (삭제 예정) [date]
- 작업 완료일 (삭제 예정) [date]
- 생성일자 [created_time]
- 최신 수정일자 [last_edited_time]
- 생성자 [created_by]
- 최신 수정자 [last_edited_by]

### `triggers_db` → Triggers

`data_source_id: 33fcd014-3f6e-8092-a585-000b407693e7`

- 이름 [title]
- 상태 [select]
- 유형 [select]
- 우선순위 [select]
- 출처 [select]
- 허용 기간 [select]
- 담당자 [formula]
- 담당자(숨김) [rollup]
- 프로젝트명 [rollup]
- 요청일시 [rollup]
- Requests DB [relation] → `requests_db`
- Projects DB [relation] → `projects_db`
- 후속 트리거 [relation] → `triggers_db`
- 생성 일시 [created_time]
- 최종 편집 일시 [last_edited_time]
- 생성자 [created_by]
- 최종 편집자 [last_edited_by]

### `specs_db` → Specs

`data_source_id: 33fcd014-3f6e-80d9-9ad9-000b760cd632`

- 이름 [title]
- 담당자 [formula]
- 우선순위 [rollup]
- 유형 [rollup]
- Requests DB [relation] → `requests_db`
- Projects DB [relation] → `projects_db`
- 생성 일시 [created_time]
- 최종 편집 일시 [last_edited_time]
- 생성자 [created_by]
- 최종 편집자 [last_edited_by]

### `meetings_db` → Meeting

`data_source_id: 47d70174-84ff-40e3-8782-e66e57953fe0`

- Name [title]
- Participants [people]
- Projects [relation] → `projects_db`
- 인수인계 [rich_text]
- 회의일자 [date]

> Note: property keys here are English (`Name`, `Participants`, `Projects`), unlike most other DBs in this registry — match the casing exactly when composing `--properties` payloads.
