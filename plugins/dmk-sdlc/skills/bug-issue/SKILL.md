---
name: bug-issue
description: |
  Writes a single, ready-to-work GitHub bug issue in the team's format, filed on whatever repo the fix lands in.
  Triggers on: "버그 이슈 써줘", "이슈 작성/정리", "GitHub issue", "bug report",
  "이거 이슈로", "이 버그 티켓으로", a defect report that has a reproduction scenario,
  or moving a debugging result into a ticket.

  Use when a defect has been (or is being) analyzed and you want to turn it into a self-contained
  ticket that anyone — agent or human — can pick up and start immediately: root cause pinned to
  file:line, reproduction and verification recorded, size / due date / blockers declared.
  To split a large spec into many tickets, use `to-tickets` instead — not this skill.
---

# Bug Issue (team GitHub-issue format)

Write a defect as a **single ticket that anyone — agent or human — can pick up and start immediately.**
Core value = "pin the root cause down to file:line, and leave a reproducible repro + verification."

> **Note on examples.** Every concrete identifier in this skill's examples — repo names, issue numbers,
> file paths, product names — is **illustrative only**. They exist to show the *shape* of a good issue.
> Substitute real values from the target repo at runtime; do not read example strings as a lookup table.

## Target

- **Target repo = the repo where the fix happens** (no hardcoding, no whitelist). **It may differ from the repo you are currently working in** — e.g. you investigated in a frontend repo but the fix is a backend prompt, so the issue is filed on the backend repo. Filing location and ordering follow the fix-repo rules in "Output (filing procedure)" below. Check the repo with `gh repo view --json nameWithOwner`; target a different one with `--repo <owner/repo>`.
- Stack hints for root-causing are informational only — adapt to whatever the fix repo uses (a TS/Next frontend, a Python/FastAPI backend, etc.). The skill works in any repo.
- One single defect. To decompose a large feature or spec into multiple tickets, use `to-tickets`.

## Template (produce this structure)

The section headers below are the team's issue format and stay in Korean — reproduce them verbatim.

**재현 시나리오**
사용자 관점 1~3문장. 무엇을 하다 어디서 막히는지 + **왜 우회 불가한지**(비즈니스 임팩트).

**증상**
관찰된 동작. **인접한 "잘 처리되는" 케이스와 대비**해 무엇만 무방비인지 좁힌다.

- 참고: `<이미 잘 처리되는 케이스>`
- → `<무방비인 케이스만>`

**원인**

- `<파일 경로>:<라인>` `<함수/심볼>` — `<왜 터지는지>`
- (필수: 파일+라인/함수까지. 못 특정하면 "여기부터 파야 함"으로 지점이라도 남긴다.)

**수정 방향**

- `<구체적 방향>`
- `<에러 종류 구분·매핑 — 예: 5xx(재시도 안내) vs 404(재저장 안내)>`
- 안내 메시지 예시: `"<현장/데모에서 사용자가 자가복구 가능한 문구>"`

**검증 상태**

- ⏳/✅ `<검증 항목 1>`
- ⏳/✅ `<검증 항목 2>`

**검증 방법 (재개 시)**

1. `<기준선: 정상 케이스 성공 확인>`
2. `<결함 재현: 조건 강제>`
3. `<수정 후: 기대 결과로 바뀌었는지 확인 — 결함 유형에 맞게 (예: 안내 반환 / 올바른 상태코드 / UI 정상 표시 / 데이터 보존)>`
4. `<원복 후 정상 성공 회귀>`

**메타**

- 크기: XS / S / M / L
- 마감: ~MM/DD
- **의존관계**: Blocked by #N / Blocks #N / 독립(병렬 가능) ← 빈칸 금지 (없으면 "독립" 명시)
- **완료 정의(DoD)**: `<재현 시나리오가 실제로 해소된 지점 — 그 자체로 데모/검증 가능해야 함>`
- 관련: #N (같은 계열·맥락)

## Rules (this is what the skill is worth)

1. **Root cause down to file + line/function.** If it is a guess, mark it "추정" and leave the spot to start digging.
2. **Narrow the scope against the adjacent healthy case** (e.g. "no URL → 400 is fine; only URL-present-but-access-fails leaks a 500"). "무엇만 무방비인지" must be unambiguous.
3. **If the defect needs a user-facing message, include an example message** so people can self-recover on-site or in a demo. Skip it for defects where a message is meaningless (silent data-preservation bugs, pure UI glitches, etc.).
4. **Separate verification into status (⏳/✅) and method (repro steps).**
5. **One line for blockers/dependencies is mandatory.** If there are none, state "독립·병렬 가능" explicitly.
6. **Always state target repo + size + due date.**
7. Tone: neutral, self-contained. No diff narration, no conversational voice (team issue convention).
8. **Vertical slice / DoD** (borrowed from `to-tickets`): a fix is a unit that resolves the reproduction scenario **end-to-end**, not a partial layer. Done = "demoable/verifiable on its own" (e.g. a 500 on export → a guidance message is actually returned).
9. **Wide mechanical changes** (large blast radius) split via **expand–contract**: add the new form → migrate call sites in batches → delete the old form, keeping CI green at every step.

## Output (filing procedure)

1. **Duplicate check (mandatory, before filing)** — look for an existing issue with the same component / root cause (file:line).

   ```bash
   gh issue list --state all --limit 100 --search "<핵심 키워드/파일명>"
   ```

   - If it already exists, **do not create a new one** — report the existing issue number (add a supplementary comment if needed). Compare at file:line granularity.
   - Only create a new issue after stating what makes it a genuinely different defect.

2. Draft the body with the template above.
3. **Filing location = fix repo** — file the issue on **the repo where the fix happens** (its implementation, PR, review, and CODEOWNERS all live there). If the fix spans multiple repos, file on the primary fix repo and name the rest in the body. If a series/epic tracker issue exists, link it.
4. **Assign a title sequence number** — max existing `#N` in **that fix repo** + 1 (a manual sequence, separate from GitHub's auto issue number). If that repo has no `#N` series yet, **start a new series at `#1`**:

   ```bash
   gh issue list --repo <owner/repo> --state all --limit 100 --json title \
     --jq '[.[]|select(.title|test("^#[0-9]+"))|(.title|capture("^#(?<n>[0-9]+)").n|tonumber)]|max'
   ```

5. Create:

   ```bash
   gh issue create --title "#N. [P?] <요약>" --body-file <초안.md>
   ```

6. If there are dependencies, state `Blocked by #N` in the body/comment to wire up the tracker link.

## Good example (illustrative — Python/FastAPI backend, issue #280, P1)

All identifiers below are illustrative (see "Note on examples"). It shows a fully-formed issue in the team format.

> **재현 시나리오**
> 사용자가 책을 다 만들고 마지막으로 "PDF 다운로드" 클릭 → 챕터 원고 파일 중 하나의 저장소 URL 이 죽어 있으면(재생성으로 위치 변경, 파일 정리, 저장소 일시 장애 등) "서버 오류(500)"만 표시. 원인·해결법을 알 수 없고, 다운로드 실패 시 인쇄로 못 이어져 우회 불가. 데모 마지막 단계에서 막히는 시나리오.
>
> **증상**
> export(docx/pdf)에서 원고 HTML 또는 표지 이미지 다운로드 실패 시 의미 있는 안내 대신 500 반환.
>
> - 참고: leaf 에 URL 이 아예 없는 경우는 400 으로 잘 처리됨
> - → "URL 은 있는데 접근이 실패" 하는 경우만 무방비
>
> **원인**
>
> - `app/routes/publishing/application/service.py` `_download_public_html`·`_load_cover_images` — `response.raise_for_status()` 가 던지는 `httpx.HTTPStatusError` 미처리
> - `app/routes/publishing/interface/controller.py` export 핸들러가 `ValueError`/`PdfDependencyError` 만 catch → httpx 예외가 그대로 500 누출
>
> **수정 방향**
>
> - `httpx.HTTPStatusError`/`httpx.RequestError` 를 잡아 사용자 안내 가능한 에러로 매핑
> - 안내에 실패 대상(몇 장 원고인지/표지인지) 포함해 현장 자가복구 가능하게
> - 저장소 일시 장애(5xx) 와 파일 없음(404) 구분 매핑 (재시도 안내 vs 재저장 안내)
> - 예: "3장의 원고 파일을 찾을 수 없습니다. 원고 편집 화면에서 저장을 다시 한 뒤 시도해주세요."
>
> **검증 상태**
>
> - ⏳ 원고 URL 을 깨뜨린 상태에서 export 시 500 대신 안내 에러 반환 확인
> - ⏳ 표지 URL 실패 케이스 동일 확인
> - ⏳ 정상 책 export 회귀(docx/pdf 모두)
>
> **검증 방법 (재개 시)**
>
> 1. 정상 책에서 DOCX/PDF export 성공 확인 (기준선)
> 2. 챕터 하나의 manuscript_url 을 임의로 깨뜨림(없는 경로로 변경)
> 3. export → 500 이 아니라 "몇 장 원고를 찾을 수 없다" 안내가 반환되는지 확인
> 4. 원고 재저장 후 export 정상 성공 확인
>
> **메타**
>
> - 크기: S / 마감: ~7/21
> - 의존관계: 독립(병렬 가능) — 같은 "저장소 실패 처리 부재" 계열
> - 완료 정의(DoD): 원고/표지 URL 이 죽은 책에서 export 시 500 대신 "몇 장 원고 없음" 안내가 반환되고, 재저장 후 export 정상 성공
> - 관련: #N (같은 계열, 데모 마지막 단계 직결)
