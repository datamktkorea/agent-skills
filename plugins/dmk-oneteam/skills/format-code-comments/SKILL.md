---
name: format-code-comments
description: Adds Korean inline comments, documentation comments (TSDoc / Google-style docstring), and section comments to TypeScript and Python code before a PR. Analyzes git diff against a chosen base branch, expands scope to full functions and classes that contain changes, reviews existing comment quality, presents an approval plan, then writes. Use when the user says "주석 달아줘", "PR 전 주석 정리", "comment 추가", "코드 문서화", "docstring 작성", "JSDoc 추가", or describes wanting comments on recently changed code. Works on entire files or specific functions/sections. Do NOT use for code review, refactoring suggestions, or documentation outside source files.
---

# Format Code Comment

Adds Korean comments to TypeScript and Python code, focused on changes in the current branch before PR submission. Never modifies files without explicit user approval.

## Workflow

### Step 1: Identify Base Branch

Ask the user which branch to compare against.

```
현재 브랜치의 변경 사항을 어느 브랜치 기준으로 분석할까요?
(예: main, develop)
```

Then retrieve the list of changed files:

```bash
git diff <base-branch>...HEAD --name-only
```

If the user specifies particular files or functions, restrict scope to those. Otherwise, process all changed files.

### Step 2: Determine Analysis Scope

Inspect the changed lines in each file:

```bash
git diff <base-branch>...HEAD -- <file>
```

Use the **entire function or class** that contains any changed line as the analysis scope — even a single-line change warrants reviewing the whole function. Documentation comments (TSDoc/docstring) must reflect the full signature and behavior, not just the changed line.

### Step 3: Load Language Reference

Read the relevant reference file based on file extension:

- `.ts`, `.tsx`, `.js`, `.jsx` → `references/typescript.md`
- `.py` → `references/python.md`

If both languages appear in the changeset, read both.

### Step 4: Analyze Comment Needs

Evaluate each in-scope function or class against these criteria.

**Add a comment when:**

- A public function, class, or method has no documentation comment
- Logic is non-obvious, algorithmically complex, or conditionally branched in a surprising way
- There are external dependencies, side effects, or important caveats
- A section comment would help visually separate distinct logical blocks

**Review an existing comment when:**

- The comment no longer matches the code after the change (accuracy)
- The comment describes WHAT, not WHY (restates what the name already conveys)
- The comment is not in Korean (team standard)
- The comment is too terse to carry meaning

**Skip when:**

- The code is self-explanatory from names and types alone
- Simple getter/setter with no side effects
- Trivial variable assignment

### Step 5: Present Approval Plan

Present the full plan before touching any file.

---

**주석 추가 계획**

📄 `src/auth/tokenService.ts`

| #   | Location              | Type   | Action  | Preview                            |
| --- | --------------------- | ------ | ------- | ---------------------------------- |
| 1   | `refreshToken()`      | TSDoc  | Add     | 만료된 액세스 토큰을 갱신하고...   |
| 2   | `refreshToken()` L.42 | Inline | Add     | 재시도 횟수 초과 시 세션 강제 종료 |
| 3   | `validateToken()`     | TSDoc  | Improve | `@param` 누락, `@throws` 추가 필요 |

📄 `services/user_service.py`

| #   | Location              | Type      | Action | Preview                       |
| --- | --------------------- | --------- | ------ | ----------------------------- |
| 4   | `get_user_by_email()` | Docstring | Add    | 이메일로 사용자를 조회하고... |

총 X개 파일, Y개 주석 변경 예정입니다.

---

After printing the plan table, ask for approval with the **AskUserQuestion** tool (not a free-text prompt) so the user can pick instead of typing. Use a single question shaped like this:

- `header`: `주석 적용`
- `question`: `총 {file_count}개 파일, {comment_count}개 주석을 적용할까요?`
- options:
  - `전체 적용` — 계획의 모든 항목을 적용
  - `일부 제외하고 적용` — 제외할 번호를 알려주면 그 항목만 빼고 적용
  - `취소` — 아무 파일도 수정하지 않음

If the user picks **전체 적용**, proceed to Step 6. If **일부 제외하고 적용**, the user names the excluded numbers (via the option's note or a follow-up); drop those, re-print the trimmed plan, and continue. If **취소**, stop without touching any file.

### Step 6: Apply Comments

Write only the approved items. Follow the conventions in the relevant reference file exactly.

Report results briefly after applying:

```
✅ 완료: 3개 파일, 총 8개 주석 추가/수정
변경 내용은 git diff로 확인하실 수 있습니다.
```

## Comment Writing Principles

- **Language**: All comments must be written in Korean. Technical terms (token, null, API, etc.) may remain in English.
- **WHY over WHAT**: Explain why the code is written this way, not what the code does. The code already shows what it does.
- **Density**: Medium. Add comments where logic is complex or non-obvious; skip self-evident code.
- **Accuracy**: Comments must always match the code. Any comment that no longer fits after a change must be updated.
- **Format**: Strictly follow the language-specific conventions in `references/typescript.md` or `references/python.md`.
