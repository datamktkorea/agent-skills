# Agent Skills Guide

Create/Imporve/Modify skills in this repo.

## Creating a Skill

- Always use `/skill-creator` skill.
- Always write skill content in English, but preserve the original language for proper nouns or domain-specific terms.

### Keep skills generic — no project-specific identifiers in instructions

Skills in this repo are reused across many projects. Concrete identifiers from one project (repo names like `dmk-bingbong-web`, file paths like `src/features/publisher/...`, people like `@김개발`, companies like `미소 병원`, features like `TOC 생성`) must NOT appear in any text the model will utter verbatim at runtime.

**Two places they leak:**

1. **User-facing prompts / asks.** Any string the skill tells the model to say to the user (e.g., `"어느 레포에서 작업하나요? 1. dmk-bingbong-web ..."`). Always use placeholders like `{repo_key}`, `{branch}`, `{role}` and populate at runtime from `code.json` / Projects DB / Request body. Never hardcode real names.
2. **Explanatory prose ("Rationale", "Convention", example one-liners inside instructions).** Abstract to placeholders (`{repo}: {branch} @ {sha}`), not concrete names.

**Where concrete examples ARE allowed:**

- Good/Bad example blocks explicitly labeled as examples (sentence stems, worked illustrations). These teach shape by being concrete.
- `code.json` schema samples — use `<repo-key-1>` / `/absolute/path/to/repo` style placeholders rather than a real org's repo names.

**Mandatory disclaimer.** Any skill or template containing concrete example identifiers MUST carry a "Note on examples" block near the top stating that all identifiers in examples are illustrative and must be substituted with real values at runtime. This signals to the model that example strings are not a lookup table.

**Self-check before committing a skill edit:** `grep -nE "bingbong|bookie|BINGBONG|미소|김영희|dmk-[a-z]+" skills/<skill>/**/*.md` — any hit outside a clearly-labeled example block is a bug.

## Plugin Manifest Rules

This repo distributes multiple plugins from a single repository via `.claude-plugin/marketplace.json`. Follow these rules to avoid broken namespacing.

### Directory structure

Each plugin **must live in its own subdirectory** with its own `.claude-plugin/plugin.json`:

```
plugins/
├── dmk-oneteam/
│   ├── .claude-plugin/
│   │   └── plugin.json   ← plugin identity; name determines skill namespace
│   └── skills/
│       └── <skill-name>/SKILL.md
├── dmk-sdlc/
│   ├── .claude-plugin/
│   │   └── plugin.json
│   └── skills/
└── dmk-stack/
    ├── .claude-plugin/
    │   └── plugin.json
    └── skills/
```

### `plugin.json` schema

```json
{
  "name": "dmk-oneteam",
  "description": "...",
  "version": "1.0.0",
  "author": { "name": "...", "email": "..." }
}
```

- `name` — determines the skill namespace prefix (e.g., `dmk-oneteam:bootstrap`)
- `author` — **must be an object**, not a string. `{ "name": "...", "email": "..." }`

### `marketplace.json` — each plugin must point to its own `source`

```json
{
  "plugins": [
    { "name": "dmk-oneteam", "source": "./plugins/dmk-oneteam" },
    { "name": "dmk-sdlc",    "source": "./plugins/dmk-sdlc" },
    { "name": "dmk-stack",   "source": "./plugins/dmk-stack" }
  ]
}
```

If multiple plugins share `"source": "./"`, Claude Code treats them as one source and collapses **all skills under whichever plugin name loads first**. Separate `source` paths are mandatory.

### Adding a new skill

1. Place `SKILL.md` under the correct plugin's `skills/` directory.
2. No path registration needed — Claude Code auto-discovers `SKILL.md` files under each plugin's `source`.

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
