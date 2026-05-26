---
name: format-and-commit
description: Chains Korean code-comment formatting and conventional-commit creation into a single PR-prep flow. Use when the user wants to add comments AND commit in one pass — triggered by "주석 달고 커밋", "PR 준비해줘", "주석 정리하고 커밋", "format and commit", "comment then commit", or any phrasing that pairs commenting with committing on recently changed code. Delegates to `dmk-oneteam:format-code-comments` first, gates on user approval, then delegates to `dmk-oneteam:git-commit`. Never runs `git add .`, `git add -A`, or `git commit -a`.
---

# Format-and-Commit

A thin orchestration skill that runs two existing skills in sequence:

1. `dmk-oneteam:format-code-comments` — adds Korean comments to changed TS/Python code.
2. `dmk-oneteam:git-commit` — writes Conventional Commits + Gitmoji messages for the resulting changes.

This skill itself writes no code and stages no files. It only sequences, bridges, and reports.

## When to use

The user wants both steps in one flow, typically right before opening a PR. Phrases that should trigger this skill rather than either child skill alone:

- "주석 달고 커밋해줘"
- "PR 전에 주석 정리하고 커밋까지"
- "format 후 commit"
- "comment then commit"

If the user only asks for one of the two stages, use the corresponding child skill directly instead.

## Hard rules

- **Never run `git add .`, `git add -A`, or `git commit -a`.** This wrapper inherits the staging discipline of `git-commit`.
- **Never bypass the approval gate.** The Bridge step below must surface the diff and wait for explicit confirmation before invoking `git-commit`.
- **Do not modify files in this skill.** All edits happen inside `format-code-comments`. If the user wants further tweaks, hand control back to them before continuing.
- **Pass the base branch through once.** Ask at the start, reuse for both child skills so the user is not asked twice.

## Workflow

### Step 1: Collect shared inputs

Ask the user once:

```
어느 브랜치 기준으로 변경을 분석하고 커밋까지 진행할까요?
(예: main, develop)
```

Record the answer as `{base_branch}`. If the user also specifies a file/function scope, capture it as `{scope}`.

### Step 2: Stage 1 — delegate to `format-code-comments`

Invoke the child skill via the Skill tool:

- Skill name: `dmk-oneteam:format-code-comments`
- Pass `{base_branch}` and `{scope}` so the child skill skips its own base-branch question.

Let the child skill run its full workflow (scope detection, plan presentation, user approval, file writes). Do not interfere.

When the child skill finishes, capture:

- List of files it modified.
- Summary of comment additions (counts by file if available).

### Step 3: Bridge — confirm before committing

Show the user the post-format state:

```bash
git diff --stat
```

Then ask explicitly:

```
주석 추가가 완료되었습니다. 이 변경을 커밋 흐름으로 넘길까요?
1. 네, 바로 커밋 진행
2. 추가로 직접 수정한 뒤 진행 (수정 끝나면 알려주세요)
3. 아니요, 여기서 종료
```

- Option 1 → continue to Step 4.
- Option 2 → wait for the user's "진행" signal, then continue to Step 4.
- Option 3 → stop. Do not roll back the formatting; leave the working tree as-is.

### Step 4: Stage 2 — delegate to `git-commit`

Invoke the child skill via the Skill tool:

- Skill name: `dmk-oneteam:git-commit`
- Provide the list of files modified in Stage 1 as a suggested grouping hint (e.g., "주석 추가 변경만 한 커밋으로"). Let `git-commit` confirm the grouping with the user — do not pre-stage anything yourself.

`git-commit` handles staging, message drafting, and the commit itself under its own rules.

### Step 5: Final report

After `git-commit` returns, summarize for the user:

- Files commented (count).
- Commit SHA(s) created.
- Suggested next step (e.g., "이어서 `dmk-oneteam:git-pull-request`로 PR을 작성할 수 있습니다").

## Failure handling

- **Stage 1 aborted by user** → stop. No commit happens.
- **Stage 1 made no changes** (nothing to comment) → skip Stage 2 unless the user explicitly asks to commit other pending work. In that case, invoke `git-commit` directly without claiming this wrapper added value.
- **Stage 2 aborted by user** → leave formatted files in the working tree, uncommitted. Report the state clearly so the user knows what is pending.

## Note on examples

Identifiers, branch names, and phrases in this document are illustrative. Substitute the user's actual base branch, file paths, and scope at runtime.
