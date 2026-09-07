---
name: changeset
description: Prepare branch-local Changesets for repositories that use `.changeset/config.json`. Use when asked to add, repair, or review a Changeset, when release intent must be recorded before a feature PR, or when a repository Changeset check fails. Determine release units from repository facts and policy, write concise release intent, and return the changed files without committing, versioning, publishing, or deploying.
---

# Changeset

Translate the branch diff into release intent. Let code establish repository facts and policy; use judgment only for the release meaning that code cannot decide.

## Boundaries

- This skill may create or repair branch-local `.changeset/*.md` files.
- It never runs `changeset version`, `changeset publish`, or deployment workflows.
- It never edits package versions, changelogs, `.changeset/config.json`, or release automation.
- It never stages, commits, pushes, or invokes `git-commit`. Return exact changed paths so the caller can decide what happens next.
- A repository without `.changeset/config.json` does not use this workflow. Report that fact and stop without changing files.

## Collect facts first

From the target repository, run the read-only inspector located beside this file:

```text
node <this-skill-directory>/scripts/inspect.mjs [--base <ref>] [--head <ref>]
```

Use a base supplied by the caller or user. Otherwise use the config's `baseBranch`; prefer its refreshed remote-tracking ref when available. Do not silently substitute an unrelated branch.

The inspector reports Git state, package manifests, repository topology, existing branch Changesets, package manager, and the exact `check:changesets` script contract. Treat that output as facts, not as release decisions.

If `.changeset/config.json` exists but the root package does not expose `check:changesets`, stop and report an incomplete integration. Do not search for vaguely similar scripts or weaken the gate with an improvised fallback.

Run the repository check with the selected base and head. Pass script arguments according to the detected package manager:

```text
npm run check:changesets -- --base <base> --head <head>
pnpm run check:changesets -- --base <base> --head <head>
yarn run check:changesets --base <base> --head <head>
bun run check:changesets --base <base> --head <head>
```

The repository checker owns mechanical release policy: whether a Changeset is required, valid release-unit names, empty Changesets, file cardinality, ignored units, and Version PR rules. Preserve its output and exit code. Do not recreate those rules in the skill.

## Determine release intent

Inspect the complete diff and any Changesets this branch already added. Repair a branch-owned file when it represents the same change; do not stack a duplicate on top of it.

Determine release-unit candidates in this order:

1. Explicit repository policy and checker output.
2. The root package name for a single-package repository.
3. Changed workspace package names for a workspace repository, adjusted by `fixed`, `linked`, `ignore`, private-package settings, and dependency relationships.
4. Repository-provided affected or deployment tooling when custom release units differ from workspace packages.

An affected graph produces candidates, not product truth. Shared files and internal packages may affect several release units, one unit, or none depending on repository policy. Never assume that a monorepo has an app allow-list, that `apps/*` is deployable, or that one Changeset may name only one package.

Choose the bump from the consumer-visible contract:

- `major`: an incompatible change that requires consumers to adapt.
- `minor`: a backward-compatible capability consumers can use.
- `patch`: a backward-compatible fix or improvement to existing behavior.
- empty: only when repository policy permits a no-release marker and the diff has no release-worthy effect.

Commit labels and changed paths are evidence, not the decision. Read the implementation, tests, public interfaces, and repository precedent. Ask one focused question only when genuine product or compatibility ambiguity would change the release units, bump, or whether the Changeset should be empty. Never resolve ambiguity by choosing the lower bump or collapsing several releases into an empty Changeset.

## Write the file

Proceed without a routine approval step when the release intent is clear. Match the language and level of detail used by recent Changesets in the repository.

Use Changesets' standard format:

```text
---
"<package-name>": <patch|minor|major>
---

<consumer-visible summary>
```

A standard Changeset may contain several package entries. Split files only when the repository policy requires separate entries or when the changes deserve independent changelog records. An empty Changeset is exactly:

```text
---
---
```

Use exact package names from repository facts. Write a concise summary that explains what changed for consumers and any action required for a breaking change. Avoid file names, implementation inventories, commit hashes, and claims the diff does not support.

Choose a unique `.changeset/<slug>.md` path and never overwrite an unrelated existing file. Modify only Changesets added by the current branch unless the user explicitly scopes a repair differently.

## Verify and return

Re-run the same repository check after writing. Some checkers validate file contents from the working tree but count required Changesets only from committed history. In that case, report that final branch validation is pending a commit; do not commit merely to make the check pass.

Return:

- each created or repaired path;
- release units and bump types, or `empty`;
- the final summary;
- the exact checker command, exit code, and remaining diagnostics;
- whether a commit is required before the checker can make its final branch-level decision.

When called from a pull-request workflow, return control after this report. The caller owns exact-path commit, checker re-run, push, and PR creation or update.
