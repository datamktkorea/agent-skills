---
name: format-and-commit
description: Chains Korean code-comment formatting and conventional-commit creation into a single PR-prep flow. Use when the user wants to add comments AND commit in one pass — triggered by "주석 달고 커밋", "PR 준비해줘", "주석 정리하고 커밋", "format and commit", "comment then commit", or any phrasing that pairs commenting with committing on recently changed code. Delegates to `dmk-oneteam:format-code-comments` first, gates on user approval, then delegates to `dmk-oneteam:git-commit`. Never runs `git add .`, `git add -A`, or `git commit -a`.
---

# Format-and-Commit

Runs two existing skills back-to-back so the user doesn't invoke them separately before a PR. This skill only sequences — it writes no code and stages no files itself.

## Workflow

1. **Ask base branch once.** `어느 브랜치 기준으로 분석하고 커밋할까요? (예: main, develop)` — reuse the answer for both stages so the user isn't asked twice. Capture any file/function scope too.

2. **Stage 1 — `dmk-oneteam:format-code-comments`.** Invoke via the Skill tool, passing the base branch and scope. Let it run its full approval-and-write flow untouched.

3. **Gate.** Show `git diff --stat`, then ask: `주석 추가 완료. 커밋을 진행할까요? (진행 / 직접 수정 후 진행 / 종료)`. On "종료", stop without rolling back the formatting.

4. **Stage 2 — `dmk-oneteam:git-commit`.** Invoke via the Skill tool. It owns staging, message drafting, and the commit under its own rules. Suggest grouping the formatted files together, but never pre-stage anything yourself.

5. **Report.** Summarize files commented and the resulting commit SHA(s).

## Inherited rules

- Never run `git add .`, `git add -A`, or `git commit -a` — staging discipline comes from `git-commit`.
- If Stage 1 produced no changes, skip Stage 2 unless the user explicitly wants to commit other pending work.

## Note on examples

Branch names and prompts here are illustrative — substitute the user's actual values at runtime.
