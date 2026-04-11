# Agent Skills Guide

Create/Imporve/Modify skills in this repo.

## Creating a Skill

- Always use `/skill-creator` skill.
- Always write skill content in English, but preserve the original language for proper nouns or domain-specific terms.

## Creating a Plugin

A plugin groups related skills under a shared namespace (e.g., `/dmk-pipeline:write-trigger`).

### Structure

```text
{plugin-name}/
├── .claude-plugin/
│   └── plugin.json     # name, description, version, author
└── skills/
    └── {skill-name}/
        └── SKILL.md
```

### Key Points

1. **`plugin.json` `name` field = namespace prefix** — choose carefully, it can't change without breaking existing users.
2. **Skills stay in `skills/` at the plugin root** — never inside `.claude-plugin/`.
3. **Register in `marketplace.json`** — add an entry to `.claude-plugin/marketplace.json` at the repo root so the plugin is discoverable via `/plugin install`.
4. **Test locally before pushing** — use `claude --plugin-dir ./{plugin-name}` to verify skills work as expected.
