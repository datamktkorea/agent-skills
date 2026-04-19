# Agent Skills Guide

Create/Imporve/Modify skills in this repo.

## Creating a Skill

- Always use `/skill-creator` skill.
- Always write skill content in English, but preserve the original language for proper nouns or domain-specific terms.

## Notion API Usage

Whenever writing or updating any skill that calls the Notion API, always fetch `https://developers.notion.com/llms.txt` first and use the latest endpoint URLs, version headers, and request formats found there. Never rely on memorized or previously seen Notion API details — they may be outdated.

### Current version: `2026-03-11`

Use `Notion-Version: 2026-03-11` for all API calls.

### Key changes from legacy API

**Database querying** — `POST /v1/databases/{id}/query` is removed in `2026-03-11`.
The replacement is a two-step flow:

1. Retrieve the `data_source_id` from the database:

   ```bash
   GET /v1/databases/{database_id}
   # → .data_sources[0].id
   ```

2. Query using that ID:

   ```bash
   POST /v1/data_sources/{data_source_id}/query
   ```

   Note: `database_id` ≠ `data_source_id` — they are different values.

**Page content creation** — `children` block JSON is replaced by a `markdown` string parameter in `POST /v1/pages`. The two are mutually exclusive.

**Page content update** — `PATCH /v1/blocks/{block_id}` is replaced by:

```bash
PATCH /v1/pages/{page_id}/markdown
```

Use `update_content` (search-and-replace) or `replace_content` (full rewrite).

**Trash field** — `archived: true` is replaced by `in_trash: true`.
