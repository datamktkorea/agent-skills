---
name: git-commit
description: Create atomic Git commits from the intended staged or working-tree changes. Use when the user asks to commit, split or organize changes, or when another skill delegates exact paths to commit. Inspect before staging, use exact paths or hunks, write concise Conventional Commit messages with Gitmoji, and proceed without routine confirmation when the scope is clear.
---

# Git Commit

Commit exactly the intended change. Default to atomic commits, a light or omitted body, hunk-level staging only when needed, and automatic execution once the scope is clear.

## Contract

- A commit request authorizes staging and committing changes within its clear scope. Do not add a routine approval step.
- Explicit paths, exclusions, grouping, and message instructions from the user or caller take precedence.
- If another skill delegates exact paths, treat them as a hard boundary. Never include adjacent working-tree changes.
- Existing staged changes are intentional scope unless the user asks to reorganize them. Do not silently add unstaged files to that commit.
- If an exact-path request conflicts with unrelated changes already in the index, do not commit the unrelated changes or rewrite the index silently. Ask how to preserve the staged work.
- When nothing is staged, infer the intended scope from the request, conversation, and diff. Ask one focused question only when unrelated work or mixed intent makes the boundary materially ambiguous.
- Repository-enforced commit rules take precedence over this skill's fallback convention.

## Inspect

Before mutating the index, inspect:

```text
git status --short
git diff --cached
git diff
git log -5 --oneline
```

Also read relevant repository instructions or commit tooling when present. Do not stage secrets, local credentials, editor state, debug artifacts, or unrelated generated files merely because they are untracked.

If there is nothing to commit, report that and stop. Do not create an empty commit unless explicitly requested.

## Form atomic groups

Create the smallest useful sequence of commits, not the largest possible number.

- One commit should express one reversible concern.
- Keep tests with the behavior they verify.
- Keep required schema, migration, generated output, or lockfile changes with the change that requires them.
- Order prerequisites before their consumers when several commits are necessary.
- Use file-level groups by default. Use hunk-level staging when a file contains independent concerns that belong in different commits.
- Do not rewrite file contents merely to make staging easier.

Proceed automatically when the grouping is clear. Show the proposed groups and ask once only when changing an existing staged selection or choosing among materially different groupings.

## Stage precisely

Stage named paths with `git add -- <paths>`. Never use `git add .`, `git add -A`, wildcard expansion, or `git commit -a`.

For mixed files, stage only the selected hunks with a non-interactive cached patch such as `git apply --cached`, then verify both sides of the split. Do not use a broad staging command and then try to repair the index afterward.

Before each commit, inspect the complete staged diff and run:

```text
git diff --cached --check
git diff --cached --stat
```

Confirm that the staged diff matches exactly one planned concern and contains no accidental files or sensitive data.

## Write the message

Follow repository-specific conventions when they exist. Otherwise use:

```text
<gitmoji> <type>(<optional-scope>): <subject>

<optional body>

<optional footer>
```

Use the conventional type and its default Gitmoji:

| Type | Gitmoji |
| --- | --- |
| `feat` | ✨ |
| `fix` | 🐛 |
| `docs` | 📝 |
| `style` | 🎨 |
| `refactor` | ♻️ |
| `test` | ✅ |
| `chore` | 🔧 |
| `perf` | ⚡️ |
| `revert` | ⏪️ |

A more specific Gitmoji is acceptable when it clearly improves the signal. Use `🔖 chore(release): ...` for version or release metadata; `release` is not a commit type.

- Write the subject in concise imperative English, with no trailing period.
- Omit the body when the subject and diff are sufficient.
- When context is not visible from the diff, add only the essential reason or tradeoff. Prefer one to three short bullets, in Korean by default unless the repository uses another language.
- For breaking changes, use `type(scope)!:` and a `BREAKING CHANGE:` footer.
- Never add AI attribution or `Co-Authored-By` trailers for an assistant.

## Commit and verify

Commit each group in order. Never use `--no-verify`. Do not amend or rewrite history unless the user explicitly requests it.

If a hook fails, preserve its output, inspect any files it changed, and fix the underlying problem only when that fix is within scope. Re-check the staged diff before retrying; never bypass the hook.

After each commit, record its SHA and verify the remaining index and working tree. At the end, report:

- the commits created, in order;
- any changes intentionally left staged, unstaged, or untracked;
- any hook or validation that did not pass.

Do not push. Network publication belongs to the caller or a pull-request workflow.
