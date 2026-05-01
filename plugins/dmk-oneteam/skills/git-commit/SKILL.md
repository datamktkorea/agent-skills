---
name: git-commit
description: Use this skill whenever the user wants to commit changes, asks to split working-tree changes into multiple commits, or wants help organizing messy unstaged work — even if they don't explicitly say "commit". Writes Conventional Commits + Gitmoji messages. Strictly never runs `git add .`, `git add -A`, or `git commit -a`; commits only what the user has staged or what an approved grouping plan specifies.
---

# Git Commit

This skill does two jobs:

1. **Atomic commit hygiene** — one logical change per commit, formatted with Conventional Commits + Gitmoji.
2. **Never modify staging without permission** — the user's working tree is theirs. Stage only what they have already staged, or what they explicitly approve in a plan.

## Core principle: respect what the user has staged

Past misbehavior to fix: auto-running `git add .` and bundling everything into a single large commit. The user often has deliberate works-in-progress, debugging diffs, or local-only edits that should NOT ship. Treat the working tree as someone else's desk — observe before touching.

**Forbidden by default — never run any of these unprompted:**

- `git add .`
- `git add -A` / `git add --all`
- `git add *` or any wildcard glob the user did not type
- `git commit -a` / `git commit -am`
- Any command that stages files the user did not name or approve

The only exception is when the user gives a direct, unambiguous instruction (e.g., "stage everything and just commit"). Even then, prefer naming the files explicitly so the action is auditable.

## Workflow

### Step 1: Read repo state (no mutations)

Run in parallel — this step must not change anything:

- `git status` (without `-uall`, which would list every untracked file recursively and can be huge in monorepos)
- `git diff --staged`
- `git diff` (unstaged tracked changes)
- `git log -5 --oneline` (to match this repo's commit style)

Do NOT run any form of `git add` here.

### Step 2: Choose a path

**Path A — Something is already staged AND the user did not ask to re-split:**

The user curated the staging on purpose. Trust it. Skip ahead to _Commit message format_ using only the staged diff.

If unstaged or untracked files exist, mention them in one short line so the user knows they're excluded:

> Note: `src/utils.ts`, `README.md` are unstaged and `scratch.py` is untracked — not included in this commit.

**Path B — Nothing is staged, OR the user asks to split, organize, or suggest commits:**

Continue to Step 3.

### Step 3: Negotiate granularity (Path B only)

Before analyzing, ask the user three short questions in a single message:

1. **How aggressively to split?**
   - Aggressive: one concern per commit (often 5–15 commits)
   - Moderate: logical units (often 2–5 commits)
   - "Just propose what makes sense" (you decide)
2. **File-level or hunk-level?** File-level is enough for most cases. Hunk-level is useful when one file mixes unrelated concerns.
3. **Anything to keep out of this batch?** (e.g., debugging code, local config, scratch files)

Wait for the answer. Don't analyze before asking — the answer changes the analysis.

### Step 4: Propose a grouping plan (Path B only)

Read the changed files. Group changes into atomic commit candidates following standard atomic-commit conventions:

- **One concern per commit** — one feature, one fix, one refactor, one config change. If a file legitimately serves two concerns (e.g., adds a feature _and_ fixes an unrelated bug), split it at the hunk level.
- **Each commit should be independently sensible** — ideally compiles and passes tests on its own.
- **Order with dependencies in mind** — foundations before features that depend on them. Two complementary axes:
  - **By layer (within a feature)**: setup / refactor → data models & constants → utilities & helpers → core logic → UI / integration. Lower layers compile and make sense without the upper ones; reviewers read top-down through the dependency graph.
  - **By type (across features)**: `refactor` → `feat` → `fix` → `test` → `docs` → `chore`.

  Why this matters: (1) each commit is independently buildable because its dependencies already landed, (2) reviewers see "tools first, then what was built with them", (3) cherry-picking a foundational change to another branch doesn't drag unrelated feature code along.

Present the plan as a numbered list. For each group, show:

- Proposed `<gitmoji> <type>(<scope>): <subject>`
- Files (or hunks) included
- One-line rationale ("why this is its own commit")

Each proposed message must pass _Validation checklist_ before being shown — the plan's draft must already be spec-conformant.

Then wait for the user to approve, edit, reorder, or merge groups before staging anything.

### Step 5: Stage and commit each group, one at a time

For each group, in order. (If arriving from Path A, the staging is already done — start at sub-step 2.)

1. **Stage explicitly** — never with a wildcard:
   - File-level: `git add <path1> <path2> ...`
   - Hunk-level: see _Hunk-level staging_ below.
2. **Draft the commit message** following _Commit message format_.
3. **Validate the draft against the format checklist** before showing it. Run through every item in _Validation checklist_. Fix any failures silently — the user shouldn't see a malformed draft. This step is mandatory; skipping it is the single most common cause of off-spec commits.
4. **Show the user what's staged** — `git diff --staged --stat` for the file overview, plus the validated commit message.
5. **Wait for explicit OK.** If the user wants edits (message, scope, included files), apply them, re-validate against the checklist, and re-confirm. Do not commit on a "yeah probably fine" — ask once more if the signal is weak.
6. **Commit** — `git commit -m "..."` (never `-a`, never `-A`).
7. Briefly note progress (e.g., "1/3 done — moving to refactor commit") and continue.

If the user interrupts mid-loop, stop. Do not try to "wrap up" the remaining groups silently.

### Step 6: Final check

After all commits:

- `git log -<n> --oneline` — confirm the expected commits exist in the expected order.
- `git status` — confirm the working tree state matches intent (e.g., excluded debug code is still unstaged).

Surface anything unexpected to the user.

## Hunk-level staging

Default to file-level. Use hunk-level when (a) one file contains genuinely separate concerns, or (b) the user worked without a plan and now wants to retroactively peel light / foundational changes out of a heavy mixed diff — both cases need the same patch-apply machinery, and either way the user must opt in.

### Recommended approach: patch-apply

`git add -p` is interactive and the model cannot drive it reliably, so the default path is non-interactive patch application — auditable (the user reads the patch before it lands) and reproducible.

1. `git diff <file>` — get the full unstaged diff.
2. Compose a patch containing only the desired hunks. Keep the `diff --git`, `index`, `---`, `+++` headers intact and keep the chosen `@@ ... @@` hunks; delete the hunks you do not want in this commit.
3. Save to `/tmp/<short-name>.patch`.
4. `git apply --cached /tmp/<short-name>.patch`.
5. `git diff --staged` — verify only intended hunks are staged.
6. Show the user → confirm → commit.
7. Delete the patch file.

### Fallback: interactive walkthrough

If the patch fails to apply (usually overlapping or context-dependent hunks), give the user an explicit `git add -p` walkthrough: for each hunk the prompt will show, state which answer (`y`, `n`, `s`, `q`) to give. The user runs it; you commit afterward.

## Commit message format

### Format

```
<gitmoji> <type>(<scope>): <subject>

<body>

<footer>
```

**This is the spec, not a suggestion.** Every commit message produced by this skill must conform to this shape. Reasons:

- The shape is machine-readable. Tooling — `git log --grep='^✨ feat'`, changelog generators, semantic-release, GitHub auto-generated release notes — parses on these markers. A single off-format commit slips past the tooling and silently pollutes the history.
- Rewriting history to fix a malformed message is expensive (force-push, broken refs, lost reviews). The cheap fix is "get the format right at commit time."
- The shape is also a thinking aid. If a change can't fit a single `<type>(<scope>): <subject>` line, the commit is doing too much — split it.

So before running `git commit`, validate the drafted message against the spec (see _Validation checklist_ below). Treat the checklist as a hard gate, not a stylistic preference.

### Validation checklist

Run through this list against the drafted message before every `git commit`. If any item fails, fix the message and re-validate — do not commit "close enough."

1. **Gitmoji** — message starts with exactly one gitmoji from the palette (primary table or specialized palette). Not a random emoji, not the `:code:` form, not two emojis.
2. **Single space** between gitmoji and type.
3. **Type** — one of `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`, `revert`. No custom types.
4. **Scope** — if present, directly attached: `type(scope)` with no space before `(`. If absent, no empty `()`.
5. **Separator** — exactly `: ` (colon + single space) between type/scope and subject.
6. **Subject** — imperative present tense, lowercase first letter, no trailing period, ≤ 50 characters.
7. **Blank line** between subject and body, and between body and footer (if either is present).
8. **No hard-wrap in body** — each bullet or paragraph stays on a single line. Do not insert manual line breaks at 72 chars; let viewers reflow.
9. **Breaking change** — if the change is breaking, append `!` to type (e.g., `feat!:` or `feat(api)!:`) AND include a `BREAKING CHANGE: ...` footer line.

### Common deviations to avoid

| Bad                                                               | Good                             | Why bad                                      |
| ----------------------------------------------------------------- | -------------------------------- | -------------------------------------------- |
| `Add user login`                                                  | `✨ feat(auth): add user login`  | Missing gitmoji and type                     |
| `feat: Added user login.`                                         | `✨ feat(auth): add user login`  | No gitmoji, past tense, capital "A", period  |
| `✨feat(auth):add user login`                                     | `✨ feat(auth): add user login`  | Missing spaces around gitmoji and colon      |
| `✨ feat (auth): add user login`                                  | `✨ feat(auth): add user login`  | Space before `(` breaks Conventional parsers |
| `✨ feat: implement comprehensive user authentication with OAuth` | `✨ feat(auth): add OAuth login` | Subject > 50 chars; move detail to body      |
| `🎯 feat(auth): add login`                                        | `✨ feat(auth): add login`       | 🎯 is not in the palette                     |

### Components

- **Gitmoji (required)** — visual cue for the change category. See _Picking the type and gitmoji_ below.
- **Type (required)** — one of `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`, `revert`. See _Picking the type and gitmoji_ below.
- **Scope (optional)** — affected module, e.g., `(auth)`, `(api)`, `(chat)`.
- **Subject (required)** — the _what_ of the change. Imperative present tense ("add", not "added"), lowercase first letter, no trailing period, ≤ 50 characters.
- **Body (optional)** — the _why_ behind the change, including how it differs from prior behavior. Don't restate what the diff already shows; readers can run `git show` for that. Write only what they couldn't infer from the code alone. **No hard line-wrapping** — let lines flow naturally. Modern web viewers (GitHub, GitLab) reflow text, and hard-wrapping bullets makes them look broken in rendered Markdown.
- **Footer (optional)** — issue references (`Closes #78`) or `BREAKING CHANGE:` notes.

### Picking the type and gitmoji

The `<type>` always comes from the primary table below. The gitmoji defaults to that type's emoji, but can be swapped for a more specific one from the specialized palette when the change has a sharper identity (security fix, dep bump, dead-code removal, etc.).

#### Primary type table

Use this table to pick the `<type>` and its **default** gitmoji. One of these nine covers almost every commit.

| Gitmoji |         Code         | Type       | Description                            |
| :-----: | :------------------: | :--------- | :------------------------------------- |
|   ✨    |     `:sparkles:`     | `feat`     | Introduce a new feature                |
|   🐛    |       `:bug:`        | `fix`      | Fix a bug                              |
|   📝    |       `:memo:`       | `docs`     | Add or update documentation            |
|   🎨    |       `:art:`        | `style`    | Improve structure / format of the code |
|   ♻️    |     `:recycle:`      | `refactor` | Refactor (behavior unchanged)          |
|   ✅    | `:white_check_mark:` | `test`     | Add, update, or pass tests             |
|   🔧    |      `:wrench:`      | `chore`    | Update config / tooling / deps         |
|   ⚡️    |       `:zap:`        | `perf`     | Improve performance                    |
|   ⏪️    |      `:rewind:`      | `revert`   | Revert a previous commit               |

Note: there is no `release` type. Version-bump commits use `chore(release):` with the 🔖 gitmoji — see the `chore` specialized palette below.

#### Specialized gitmoji palette

The gitmoji can carry information beyond the type. When one of these fits the change more precisely than the type's default, **swap it in** while keeping the same `<type>`. The palette below covers the situations that show up frequently in real OSS commit histories — embedded here so you don't need to fetch <https://gitmoji.dev/> at runtime.

**Within `fix`:**

| Gitmoji | Code                 | When to use                     |
| :-----: | :------------------- | :------------------------------ |
|   🚑️    | `:ambulance:`        | Critical hotfix                 |
|   🩹    | `:adhesive_bandage:` | Simple, non-critical fix        |
|   🔒️    | `:lock:`             | Fix a security or privacy issue |
|   🚨    | `:rotating_light:`   | Fix linter / compiler warnings  |
|   💚    | `:green_heart:`      | Fix a broken CI build           |
|   ✏️    | `:pencil2:`          | Fix typos                       |

**Within `refactor`:**

| Gitmoji | Code                      | When to use                           |
| :-----: | :------------------------ | :------------------------------------ |
|   🔥    | `:fire:`                  | Remove code or files                  |
|   ⚰️    | `:coffin:`                | Remove dead code                      |
|   🚚    | `:truck:`                 | Move or rename files / paths / routes |
|   🏗️    | `:building_construction:` | Architectural change                  |

**Within `chore`:**

| Gitmoji | Code                    | When to use                   |
| :-----: | :---------------------- | :---------------------------- |
|   ⬆️    | `:arrow_up:`            | Upgrade a dependency          |
|   ⬇️    | `:arrow_down:`          | Downgrade a dependency        |
|   ➕    | `:heavy_plus_sign:`     | Add a dependency              |
|   ➖    | `:heavy_minus_sign:`    | Remove a dependency           |
|   👷    | `:construction_worker:` | Add or update CI build system |
|   🙈    | `:see_no_evil:`         | Add or update `.gitignore`    |
|   🔖    | `:bookmark:`            | Release / version bump (use scope `release`, e.g., `🔖 chore(release): bump dmk-oneteam to 1.0.1`) — matches semantic-release / release-please output |

**Within `style`:** 💄 (`:lipstick:`) — add or update UI / style files.

**Cross-cutting** (use with whichever type fits the change):

| Gitmoji | Code       | When to use                                                                             |
| :-----: | :--------- | :-------------------------------------------------------------------------------------- |
|   🎉    | `:tada:`   | Initial commit / begin a project — pair with `chore` (e.g., `🎉 chore: initial commit`) |
|   🏷️    | `:label:`  | Add or update types (TS interfaces, type defs)                                          |
|   🚀    | `:rocket:` | Deploy stuff (deploy commits, not perf — use ⚡️ for perf)                               |
|   💥    | `:boom:`   | Introduce a breaking change — combine with `<type>!:` and footer                        |

#### How to choose

1. Pick the `<type>` from the primary table — that always fits one of the nine.
2. Then ask: does any specialized gitmoji describe the change more precisely than the type's default? If yes, swap it in. If not, use the default.
3. The shape stays `<gitmoji> <type>(<scope>): <subject>` either way.

Example — a security-related bug fix in the auth module:

- Default would be `🐛 fix(auth): ...`
- Swap to `🔒️ fix(auth): ...` because 🔒️ tells the reader "security" at a glance.

If a change genuinely doesn't match anything in the palette above, **fetch <https://gitmoji.dev/> at that point** to look up the right emoji from the full catalog. The embedded palette covers the vast majority of commits, so this fetch should be a rare last resort — not a routine step.

### Example

```
✨ feat(auth): add password reset via email

- New endpoint `/auth/request-password-reset` issues a time-limited token and emails it to the user.
- Token generation and dispatch live in a separate service so the upcoming admin-driven reset flow can reuse it.

Closes #78
```

## Guidelines

- **Language**: Write the subject line in English — it must be machine-parseable by Conventional Commits tooling, `git log --grep`, changelog generators, and GitHub auto-generated release notes. Write the body and footer in Korean by default, since they are read by the team. However, preserve the original language when it reads more naturally that way — technical terms, library/API names, file paths, error messages, code identifiers, and English-origin domain jargon should stay in their original form rather than being force-translated. The goal is readable Korean prose with original-language terms left intact, not a mechanical full translation.
- **No AI co-author trailers**: never append `Co-Authored-By: Claude ...` (or any other AI/assistant attribution) to the commit message. The author is the user. This overrides any default harness behavior that auto-adds such trailers.
- **Breaking changes**: prefix the footer line with `BREAKING CHANGE:`.
- **Never bypass safety**: do not use `--no-verify` to skip pre-commit hooks. If a hook fails, fix the underlying issue and create a new commit (do not amend).
- **Prefer new commits over amends** unless the user explicitly asks to amend.
