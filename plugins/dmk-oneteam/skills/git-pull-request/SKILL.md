---
name: git-pull-request
description: Generates a polished Pull Request body by analyzing git commit logs, branch lineage, and diffs against the correct parent branch (develop vs main). Use this skill whenever the user asks to "PR 만들어줘", "PR 내용 정리", "PR 본문 작성", "Create a PR", "Summarize commits", "merge 준비", "릴리스 노트", or wraps up work on `features/*`, `feature/*`, `feat/*`, `hotfix/*`, `release/*`, `fix/*`, or `bugfix/*` branches — even if they don't say the word "PR" explicitly.
---

# Git Pull Request

This skill turns a finished branch into a review-ready Pull Request body. It analyzes commits and diffs, picks the right parent branch, and drafts a structured PR following team conventions.

## Operating principles

1. **Interaction over automation.** The goal is _not_ to one-shot a perfect PR — it is to walk the user through a tight, well-paced loop: detect → confirm → draft → review → save. Whenever the agent is about to make a non-trivial decision (parent branch, scope of commits, whether to trigger sibling skills), pause and confirm. The cost of a wrong PR target is high; the cost of one extra clarifying question is low.
2. **Parent branch accuracy is the top priority.** Targeting `main` when the team uses `develop` (or vice versa) breaks the release flow and is painful to undo. The decision logic in [Step 2](#step-2-determine-the-parent-branch) is the most load-bearing part of this skill — read it carefully, do not shortcut it.
3. **Language policy.** PR title, section headers, and Conventional Commit tokens stay in English. Narrative content (Summary, Review Points, item bullets, checklist labels, Test & Verification) is written in Korean. This mirrors the `git-commit` skill's convention so commit history and PR body read coherently together.
4. **File-based output.** Not every teammate has `gh` CLI installed or authenticated. The skill writes the final PR body to a file (default `PULL_REQUEST.md`) and tells the user the next steps for both `gh` and copy-paste paths.
5. **Respect the repo's own template.** If `.github/PULL_REQUEST_TEMPLATE.md` exists, treat _that_ as the authoritative shape and adapt the skill's content into it. Only fall back to the bundled template when no repo template is present.

## When to trigger

Trigger this skill when the user signals "we're ready to ship" — not just on the literal phrase "PR".

- Direct: "PR 만들어줘", "PR 본문 작성", "PR 내용 정리", "Create a PR", "Generate PR description".
- Indirect: "이거 머지하자", "develop에 올릴 준비", "릴리스 노트 뽑아줘", "이번 작업 정리해줘 (작업 = 브랜치 단위)".
- Implicit: user has finished work on a `features/*`, `feature/*`, `feat/*`, `fix/*`, `bugfix/*`, `hotfix/*`, or `release/*` branch and is asking what comes next.

Do **not** trigger on plain "commit message" requests — that is `git-commit`'s job.

## Workflow

The workflow has 8 steps. Steps 2, 4, and 7 are explicit user-confirmation gates. Do not skip them.

### Step 1: Read repo state (read-only)

Run these in parallel — none of them mutate anything:

- `git branch --show-current` — current branch name
- `git status -sb` — short status (avoid `-uall`; can blow up in monorepos)
- `git log -10 --oneline` — recent commits, to learn the repo's commit-message style
- `git ls-remote --heads origin develop` — does `develop` exist on the remote? (used in Step 2)
- `gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null` — repo's default branch (often `main`, sometimes `master` or `develop`); falls back gracefully if `gh` is unavailable
- `test -f .github/PULL_REQUEST_TEMPLATE.md && cat .github/PULL_REQUEST_TEMPLATE.md` — repo's own template, if present
- `gh pr list --head "$(git branch --show-current)" --json number,url,state 2>/dev/null` — is there already an open PR for this branch?

Cache the answers; subsequent steps reference them.

### Step 2: Determine the parent branch

This is the single most important decision in the skill. Get it wrong and the PR opens against the wrong base, which is painful to fix after reviewers start commenting.

#### 2a. If the user explicitly named a base branch

If the user said something like "PR을 develop으로 올려줘" or "base는 main이야", **use that exactly** and skip auto-detection. Confirm once back: "base는 `develop`으로 진행하겠습니다 — 맞죠?"

#### 2b. Otherwise, apply this mapping

| Current branch pattern                                  | Primary parent          | Fallback if primary missing |
| ------------------------------------------------------- | ----------------------- | --------------------------- |
| `features/*`, `feature/*`, `feat/*`                     | `develop`               | `main` (default branch)     |
| `fix/*`, `bugfix/*`                                     | `develop`               | `main` (default branch)     |
| `hotfix/*`                                              | `main` (default branch) | — (always main)             |
| `release/*`                                             | `main` (default branch) | —                           |
| Anything else (free-form names, e.g. `vincent/cleanup`) | —                       | **Always ask the user**     |

To decide whether `develop` is available as the primary parent, use the `git ls-remote --heads origin develop` output captured in Step 1 — empty output means `develop` does not exist on the remote, so fall through to the fallback column.

#### 2c. Confirm with the user before proceeding

Even when the mapping gives a clean answer, surface the decision so the user can override:

> 현재 브랜치 `features/auth-jwt` → 부모 브랜치는 `develop`으로 잡았습니다.
> (`develop`이 origin에 존재하고, `features/*` 패턴은 develop으로 머지되는 컨벤션입니다.)
> 이대로 진행할까요? 다른 base가 있으면 알려주세요.

If the branch pattern is unmatched (the "Anything else" row), do **not** guess — ask:

> 현재 브랜치 `vincent/cleanup`은 표준 패턴(`features/*`, `hotfix/*` 등)에 해당하지 않아 자동 추정을 하지 않았습니다.
> base 브랜치를 알려주세요. (후보: `develop`, `main`)

Only after the user confirms — explicitly — proceed.

### Step 3: Extract changes

Once the parent is locked in, gather the raw material:

- `git log --oneline <parent>..HEAD` — concise commit list
- `git log --format='%h%x09%s%x09%b%x1f' <parent>..HEAD` — full commit data (subject + body), tab-separated, record-separated
- `git diff --name-status <parent>...HEAD` — files added / modified / deleted (note the **three dots** — diff against the merge base, which is what GitHub itself shows)
- `git diff --stat <parent>...HEAD` — line counts per file
- `git diff <parent>...HEAD` — the actual diff (used for Review Points and the format-code-comments check in Step 4)

If `<parent>..HEAD` is empty, the branch has no unique commits — stop and tell the user. There is nothing to PR.

### Step 4: Comment-cleanup pass (sister-skill integration)

Before drafting the PR body, scan the diff for code-comment issues. The motivation: vibe-coded changes often leave behind English placeholder comments, stale TODOs, or `// TODO: explain later` markers that should not ship.

Look for these signals in the diff:

- New TypeScript / Python functions or classes added without docstring / TSDoc
- Inline comments in English when the team standard is Korean
- Obvious AI-generated boilerplate comments (`// This function does X`, `// Step 1`, `// Step 2`)
- Stale comments that no longer match the surrounding code

If any of these are present, surface a short suggestion **before** drafting the PR body:

> diff 분석 중 주석 정리가 필요해 보이는 지점 N개를 발견했습니다:
>
> - `src/auth/tokenService.ts` — `refreshToken()`에 TSDoc 누락
> - `services/user_service.py` — `get_user_by_email()` 영문 주석
>
> PR 작성 전에 `format-code-comments` 스킬을 먼저 돌리시겠어요?
> (Yes → 그 스킬로 정리 후 PR 작성 / No → 바로 PR 작성)

If the user says yes, hand off to `format-code-comments` and resume here when they return. If no, continue. Do **not** auto-trigger the sibling skill — let the user decide.

### Step 5: Categorize commits

Map each commit to a PR section by parsing its `<gitmoji> <type>(<scope>): <subject>` shape. Use the table in [Gitmoji palette](#gitmoji-palette) below — it is intentionally aligned with the `git-commit` skill so a single commit message classifies cleanly here.

Two parsing rules:

1. **Gitmoji-first.** If the commit starts with a gitmoji, that is the source of truth — even if the type word looks different.
2. **Type as fallback.** If no gitmoji is present (older commits, external contributors), use the `<type>` word.
3. **Both missing.** Bucket as "Others" and flag it for the user during review (Step 7).

The PR body groups commits under section headers — the canonical six are: **Features**, **Fixes**, **Performance**, **Refactoring**, **Documentation**, **Chores**. Add **Tests** or **Style** sections only if commits exist for them. Empty sections must be omitted (see [Output rules](#output-rules)).

### Step 6: Draft the PR body

Build the draft in this order:

1. **Title.** `<gitmoji> <type>(<scope>): <subject>` — pick the dominant change. Single-commit branch → reuse that commit's subject. Multi-commit branch → synthesize a title that captures the umbrella change. Keep ≤ 50 chars on the subject portion.
2. **Apply the template.** If `.github/PULL_REQUEST_TEMPLATE.md` exists, use _its_ section structure and adapt the skill's content into those sections (a repo template can omit sections the bundled template includes, or add ones it doesn't — defer to the repo). Otherwise use [the bundled template](#bundled-pr-template).
3. **Fill content.**
   - **Summary** — one short Korean paragraph explaining the _why_ of this PR (business reason, user impact, or constraint that drove the change). Do not restate the _what_ — the Changes section covers that.
   - **Review Points** — Korean bullets calling out the critical logic, trade-offs, and non-obvious side effects a reviewer must not miss. Surface decisions the diff alone won't make obvious; do not summarize what the diff already shows.
   - **Changes** — Korean bullets grouped by category, each ending with ` (commit-hash)`. Don't transliterate the commit subject — rephrase in one line if needed for readability.
   - **Test & Verification** — split into two sub-sections, **Automated** and **Manual** (English sub-headers, Korean items underneath). _Automated_ covers anything a CI run, test runner, or scripted check can verify on its own (e.g., 단위 테스트, 타입 체크, 린트, 빌드). _Manual_ covers anything a human must drive (e.g., 로컬 시나리오 따라가보기, 스테이징 검증, UI 회귀 확인). Auto-check (`[x]`) items the agent itself ran or that the diff trivially proves; leave `[ ]` for items only the user can confirm. Omit either sub-section entirely if it has no items.
   - **Checklist** — Korean labels. The agent auto-checks (`[x]`) items it actually performed; user-only verifications (e.g., 스크린샷 첨부, 수동 스테이징 검증) stay `[ ]`.
4. **Omit empty sections entirely.** No `N/A`, no empty headers — see [Output rules](#output-rules).

### Step 7: Show the draft and iterate

Print the full draft into the conversation (not into a file yet) and ask:

> 위 내용으로 진행할까요? 수정할 곳 있으면 알려주세요.
>
> - Title / Summary / Review Points / Changes / Test 섹션 중 어느 거든 OK
> - 특정 커밋을 빼거나, 카테고리를 옮기는 것도 가능

Apply revisions inline. Re-print only the changed sections, not the whole draft, to keep the conversation readable. Loop until the user says it's good.

### Step 8: Save and guide

Once approved, write the final body to a file and surface both deployment paths.

#### 8a. Where to save

- Default location: `PULL_REQUEST.md` in the repo root. Easy for the user to find, and `.gitignore`-able if the team prefers.
- If the user prefers an out-of-tree location: `/tmp/PULL_REQUEST-<branch-slug>.md`. Doesn't pollute the working tree but is harder to refer back to.
- If the user already has a file there: ask before overwriting.

#### 8b. Tell the user how to use the file

Always show **both** paths so teammates without `gh` CLI are not stuck:

```
✅ 저장 완료: ./PULL_REQUEST.md

다음 단계는 둘 중 편한 쪽으로:

1) gh CLI 사용 (인증 + 푸시 완료 상태):
   gh pr create --base <parent> --head <current> --title "<title>" --body-file ./PULL_REQUEST.md

2) 웹 UI 사용:
   - 먼저 브랜치를 origin에 푸시: git push -u origin <current>
   - GitHub에서 base=<parent>, compare=<current>로 PR 생성
   - 본문 영역에 PULL_REQUEST.md 내용을 붙여넣기
```

If `gh pr list` from Step 1 found an existing open PR for this branch, do **not** suggest creating a new one — instead:

```
ℹ️ 이 브랜치에는 이미 PR #123이 열려 있습니다: <url>

업데이트 방법:
   gh pr edit 123 --body-file ./PULL_REQUEST.md
```

If the branch is not yet pushed (Step 1 caches enough info to know — or check `git log @{u}.. 2>/dev/null`), warn the user that push is required before creating the PR.

## Parent branch decision logic — extended notes

Why the mapping in Step 2b is structured this way:

- **`features/*` / `feature/*` / `feat/*` → develop first.** GitFlow and most variants treat feature branches as develop-targeted. Only fall through to `main` when there is no `develop` (trunk-based teams).
- **`hotfix/*` → main always.** Hotfixes by definition patch production. Even teams with `develop` cut hotfixes against `main` and back-port.
- **`release/*` → main.** Release branches merge into main on cut.
- **`fix/*` / `bugfix/*` → develop first.** These are usually non-urgent bugs found in the develop line; if the team meant a production hotfix they'd use `hotfix/*`.
- **Free-form names → always ask.** Pattern matching on `vincent/cleanup` or `wip-something` is a guess, and a guess on this decision is exactly what we are trying to avoid.

If the team uses a non-standard parent (e.g., a long-lived `staging` branch), the user will tell us in Step 2c. The skill does not need to enumerate every possible workflow — it just needs to _not_ silently get it wrong.

## Output rules

These rules govern the PR body produced in Step 6.

1. **Headers in English, body in Korean.** Examples:
   - ✓ `## 🎯 Summary` + 한국어 산문
   - ✓ `## ✨ Features` + `- JWT 기반 로그인 추가 (a1b2c3d)`
   - ✗ `## 🎯 요약` (header should be English)
   - ✗ `## ✨ Features` + `- feat(auth): add JWT login (a1b2c3d)` (bullet body should be Korean)
2. **PR title in English** — `<gitmoji> <type>(<scope>): <subject>` shape. Reuses the `git-commit` skill's spec exactly.
3. **No empty sections.** If there are no breaking changes, do not write `## ⚠️ Breaking Changes` followed by "N/A" or an empty bullet — omit the entire header. Same for Screenshots, Related Issues, Tests, etc. Empty headers are noise.
4. **No fabricated content.** Never invent commits, file paths, or test cases that weren't in the diff. If a section can't be filled honestly, omit it.
5. **Auto-check the checklist.** Items the agent verifiably did (`PR 제목 컨벤션 준수`, `커밋 메시지 정합성`) get `[x]`. Items only the user can verify (스크린샷, 테스트 수동 실행) stay `[ ]`.

## Bundled PR template

Use this only when no `.github/PULL_REQUEST_TEMPLATE.md` is present in the repo.

```markdown
# <gitmoji> <type>(<scope>): <subject>

## 🔗 Related Issues

<!-- 섹션 자체를 생략할 것: 연결된 이슈가 없을 때 -->

- Closes #123
- Refs PROJ-456

## 🎯 Summary

<!-- 이 PR이 왜 필요한지 한국어 산문으로. *what*은 적지 말고 *why*만. -->

## ⚠️ Breaking Changes

<!-- 섹션 자체를 생략할 것: 호환성 문제가 없을 때 -->

- 기존 `/api/v1/users` 응답 스키마 변경: ...

## 💡 Review Points

<!-- 검토자가 놓치면 안 되는 핵심 로직, 트레이드오프, 사이드이펙트를 한국어로. -->

- ...

## ✨ Changes

### Features

- JWT 기반 로그인 추가 (a1b2c3d)

### Fixes

- 토큰 만료 시 401 대신 403 반환되던 버그 수정 (e4f5g6h)

### Refactoring

- 토큰 검증 로직을 `TokenValidator` 클래스로 분리 (i7j8k9l)

<!-- 해당 카테고리에 커밋이 없으면 그 sub-header 자체를 생략. -->

## 📸 Screenshots

<!-- 섹션 자체를 생략할 것: UI 변경이 없을 때 -->

## 🛠️ Test & Verification

### Automated

- [x] 단위 테스트 추가 — `tokenService.test.ts`, 11개 케이스
- [x] 타입 체크 통과 (`tsc --noEmit`)

### Manual

- [x] 로컬에서 로그인 → 토큰 갱신 → 로그아웃 플로우 수동 검증
- [ ] 스테이징 환경 검증 (사용자 확인 필요)

<!-- Automated / Manual 둘 중 어느 한쪽에 항목이 없으면 그 sub-header 자체를 생략. -->

## ✅ Checklist

- [x] PR 제목이 `<gitmoji> <type>(<scope>): <subject>` 컨벤션 준수
- [x] 커밋 메시지가 `git-commit` 컨벤션 준수
- [x] 셀프 리뷰 완료
- [x] 관련 테스트 추가/업데이트
- [ ] 문서 업데이트 (해당 시)
- [ ] 스크린샷 첨부 (UI 변경 시)
```

## Gitmoji palette

Aligned with the `git-commit` skill. The `<type>` always comes from this primary table; the gitmoji defaults to the type's emoji but can be swapped for a more specific one when the change has a sharper identity.

### Primary type table

| Gitmoji | Type       | PR section    |
| :-----: | :--------- | :------------ |
|   ✨    | `feat`     | Features      |
|   🐛    | `fix`      | Fixes         |
|   📝    | `docs`     | Documentation |
|   🎨    | `style`    | Style         |
|   ♻️    | `refactor` | Refactoring   |
|   ✅    | `test`     | Tests         |
|   🔧    | `chore`    | Chores        |
|   ⚡️    | `perf`     | Performance   |
|   🔖    | `release`  | Release       |
|   ⏪️    | `revert`   | Revert        |

### Specialized swaps (most common)

When the change has a sharper identity, swap the gitmoji while keeping the same `<type>` and PR section:

- 🚑️ critical hotfix (still `fix`, still under Fixes)
- 🔒️ security fix (still `fix`)
- 🔥 remove code/files (still `refactor`)
- ⚰️ remove dead code (still `refactor`)
- 🚚 rename / move files (still `refactor`)
- ⬆️ / ⬇️ dep upgrade / downgrade (still `chore`)
- ➕ / ➖ add / remove dep (still `chore`)
- 👷 CI changes (still `chore`)
- 💄 UI styling (still `style`)
- 💥 breaking change (combine with `<type>!:`)

For anything not in this list, fetch <https://gitmoji.dev/> at that point. The embedded palette covers ~95% of real commits.

## Examples

### Example 1 — single feature commit on `features/auth-jwt`, parent `develop`

**Commit history:**

```
a1b2c3d ✨ feat(auth): add JWT-based login
```

**Generated PR title:** `✨ feat(auth): add JWT-based login`

**Generated body (excerpt):**

```markdown
## 🎯 Summary

기존 세션 쿠키 기반 인증을 JWT로 전환하기 위한 첫 단계.
모바일 클라이언트에서 동일한 인증 흐름을 재사용할 수 있게 만드는 게 목적.

## 💡 Review Points

- 토큰 만료 시간(15분)은 보안팀과 합의된 값. 늘리지 말 것.
- `JWT_SECRET` 환경변수 누락 시 의도적으로 startup에서 fail-fast 처리 (silent fallback 금지).

## ✨ Changes

### Features

- JWT 기반 로그인 엔드포인트 `/auth/login` 추가 (a1b2c3d)

## 🛠️ Test & Verification

### Automated

- [x] 단위 테스트 추가 — `auth.test.ts`, 8개 케이스

### Manual

- [x] 로컬에서 로그인 → 보호된 엔드포인트 호출까지 수동 검증
- [ ] 스테이징 검증 (사용자 확인 필요)

## ✅ Checklist

- [x] PR 제목이 컨벤션 준수
- [x] 커밋 메시지가 컨벤션 준수
- [x] 셀프 리뷰 완료
- [x] 관련 테스트 추가
```

### Example 2 — multi-type branch on `features/checkout-v2`, parent `develop`

**Commits:** 1 feat + 1 fix + 1 refactor → grouped into three sub-sections under `## ✨ Changes`. PR title takes the dominant change (`feat`) and umbrella scope (`checkout`).

**Generated title:** `✨ feat(checkout): redesign checkout flow with split payments`

### Example 3 — branch with no standard prefix, e.g., `vincent/quick-cleanup`

The skill does **not** auto-pick a parent. It asks. Even if the user has only ever used `develop`, this branch could be a one-off chore intended for `main`. The cost of asking is one message; the cost of guessing wrong is a misrouted PR.

## Constraints

1. **Git repository required.** Skill aborts cleanly if `git rev-parse --git-dir` fails.
2. **Network for `develop` check.** `git ls-remote` requires reaching origin. If offline, fall back to `git for-each-ref refs/remotes/origin/develop` (cached, may be stale) and warn the user.
3. **Never silently rebase, force-push, or close existing PRs.** This skill writes a markdown file; it does not mutate git state or remote state.
4. **Manual review still required.** Always advise the user to read the draft before submitting.
