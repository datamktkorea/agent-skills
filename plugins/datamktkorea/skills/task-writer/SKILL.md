---
name: task-writer
description: Writes structured Task/Ticket documents for assigning work to team members, and saves them as Markdown files. Trigger this skill whenever the user wants to create a work assignment, task ticket, or delegation document — including requests like "업무 지시 써줘", "티켓 작성해줘", "팀원한테 전달할 내용 정리해줘", "작업 요청서 만들어줘", "task 문서 만들어줘", or any similar request to formalize a work assignment. Also trigger when the user describes a task they want to hand off, even without explicitly asking for a document.
---

# Task Writer Skill

Produce a structured Markdown task document, save it to `tickets/`, and maintain a project memory in `projects/`.

## Flow Overview

1. Load project context from `.projects/`
2. Ask structured intake questions for missing required fields
3. Write the document (AI infers background, deliverables, DoD)
4. Save to `.tickets/[YYYYMMDD]_[alias]_[작업명].md`
5. Update `.projects/` records

---

## Step 1: Load Project Context

Before asking any questions, check if `.projects/index.json` exists in the current directory.

**If index.json exists:**

- Read it to see if the project the user mentioned (or is likely referring to) already exists
- If found: load `.projects/[alias].md` for project description and history
- Also scan `.tickets/` for files matching the alias prefix — read them to understand what work has already been assigned on this project
- Use all of this as context when inferring background, requirements, and DoD later

**If the project is new or index.json doesn't exist:**

- Note it — you'll create the project record after the ticket is written (Step 5)

---

## Step 2: Gather Required Information

Ask only for information that's missing. If the user already provided something in their first message, don't ask again.

Always collect these four fields. Present missing ones as a numbered list:

```
다음 정보를 알려주세요:

1. **프로젝트명**: (어떤 프로젝트인가요?)
2. **요청자**: (누가 이 업무를 요청하나요?)
3. **담당자**: (누가 이 업무를 맡나요?)
4. **마감일**: (언제까지 완료해야 하나요? 미정이면 "미정"으로 답해주세요)
```

Only ask for the fields that are actually missing — if 2 out of 4 are already known, ask only for the remaining 2.

**What AI infers (do not ask):** 배경/목적, 결과물, 완료 기준, 요구사항 — AI derives these from the user's description, project history, and related tickets.

---

## Step 3: Write the Document

Once all four required fields are collected, produce the full task document in Korean Markdown.

Use the project context and related tickets from Step 1 to make the inferred sections (배경/목적, 결과물, 완료 기준) as accurate and specific as possible.

```markdown
# [업무 제목]

> **담당자:** [이름]
> **요청자:** [이름]
> **우선순위:** 🔴 긴급 / 🟡 높음 / 🟢 보통 / ⚪ 낮음
> **마감일:** [날짜 또는 "미정"]

---

## 1. Context & Why — 배경 및 목적

[왜 이 업무를 하는지, 어떤 문제를 해결하는지 설명한다. 담당자가 독립적으로 판단할 수 있을 만큼 충분히 작성한다.]

---

## 2. Scope & Deliverables — 범위 및 결과물

[무엇을 만들어야 하는지 — 형식, 분량, 내용을 명확히 정의한다.]

**결과물 체크리스트:**

- [ ] [결과물 1]
- [ ] [결과물 2]

---

## 3. Requirements & Constraints — 요구사항 및 제약사항

[반드시 충족해야 할 조건들. 요청자에게는 당연한 것도 담당자에게는 모를 수 있으므로 명시적으로 작성한다.]

- [요구사항 1]
- [제약사항 — 예: 도구, 예산, 포맷, 보안 등]

---

## 4. Milestones & Checkpoints — 중간 체크포인트 _(선택)_

[의미 있는 중간 단계가 있다면 작성. 잘못된 방향으로 진행되는 걸 막기 위해 중요한 지점에서 확인을 받는다.]

| 단계         | 내용                         | 확인 방법                     |
| ------------ | ---------------------------- | ----------------------------- |
| Checkpoint 1 | [예: 문서 개요 작성 후 컨펌] | [예: 요청자에게 공유 후 승인] |

---

## 5. Definition of Done — 완료 기준

[담당자가 스스로 체크할 수 있는 구체적인 완료 조건.]

- [ ] [완료 조건 1]
- [ ] [완료 조건 2]

---

## 6. Dependencies & Resources — 선행 조건 및 참고 자료

[이 업무를 시작하기 전에 필요한 것, 참고할 자료.]

- **선행 작업:** [없으면 "없음"]
- **참고 자료:** [링크 또는 문서명]
- **문의:** [담당자 또는 "요청자에게 직접"]

---

## 7. Success Metrics — 성공 지표 _(선택)_

[이 업무가 잘 완료됐는지 판단할 수 있는 지표. 정량 지표 우선.]

- [지표 1]
```

### Writing Guidelines

- **Why가 가장 중요한 섹션이다.** 담당자가 목적을 이해하면 세세한 지시 없이도 스스로 판단할 수 있다. 배경은 풍부하게 작성한다.
- **DoD는 구체적으로.** "잘 해주세요"는 DoD가 아니다. 담당자가 자가 점검할 수 있어야 한다.
- **요구사항에서 암묵적 지식을 명시화한다.** 요청자에게 당연한 것도 담당자에게는 모를 수 있다.
- **4, 6, 7번 섹션은 선택.** 정보가 없거나 불필요하면 생략한다.
- 한국어 Markdown으로 출력. Microsoft Teams와 Notion 모두에서 잘 렌더링되어야 한다.

---

## Step 4: Save the Ticket File

After writing the document, save it immediately without asking for confirmation.

**File path:** `.tickets/[YYYYMMDD]_[alias]_[작업명].md`

- `YYYYMMDD`: today's date (e.g., `20260409`)
- `alias`: the project alias (see alias rule below)
- `작업명`: a short noun phrase derived from the task title, in Korean, no spaces (e.g., `API설계`, `화면기획`, `데이터마이그레이션`)

Create the `.tickets/` directory if it doesn't exist.

After saving, tell the user the exact file path.

---

## Step 5: Update Project Records

### Alias Generation Rule

Generate a single alias per project using this consistent rule:

1. Identify the 2–3 most meaningful segments of the project name (ignore generic suffixes like 프로젝트, 시스템, 솔루션, 플랫폼, 구축, 개발)
2. For Korean words: keep the most recognizable 2–4 characters
3. For English words and numbers: keep as-is, uppercase
4. Join segments with hyphens — **maximum 2 hyphens** (i.e., 3 segments max)
5. Keep total alias under 20 characters

Examples:

- `인천공항 T2 터미널 AI 기반 자동화 프로젝트` → `인천공항-T2-AI자동화`
- `삼성전자 B2B 고객관리 시스템` → `삼성전자-B2B-고객관리`
- `사내 HR 포털 개편` → `HR포털-개편`
- `모바일 앱 리디자인` → `모바일앱-리디자인`

### New Project

When a project is encountered for the first time:

1. Generate its alias
2. Infer a short description (1–2 sentences) from the ticket content
3. Create `.projects/[alias].md`:

```markdown
# [전체 프로젝트명]

**Alias:** [alias]
**등록일:** [YYYYMMDD]

## 프로젝트 설명

[티켓 내용을 바탕으로 추론한 설명]

## 발급된 티켓

- [YYYYMMDD] [작업명] → `.tickets/[파일명].md`
```

4. Create or update `.projects/index.json`:

```json
{
  "projects": [
    {
      "name": "전체 프로젝트명",
      "alias": "alias",
      "description": "한 줄 설명",
      "registered": "YYYYMMDD",
      "tickets": [".tickets/파일명.md"]
    }
  ]
}
```

### Existing Project

When a project already exists:

1. Add the new ticket entry to `.projects/[alias].md` under "발급된 티켓"
2. Add the ticket filename to the `tickets` array in `.projects/index.json`

---

## Context Awareness

The project memory exists so that each new ticket becomes more accurate than the last. When you load a project's history, use it to:

- Avoid duplicating work already assigned
- Infer consistent terminology and conventions used in this project
- Recognize implicit constraints that appear across multiple tickets
- Make the "Why" section richer by connecting this task to the project's larger goals
