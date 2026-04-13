---
name: write-meeting-notes
description: Writes structured meeting notes for team meetings. Use this skill whenever the user provides meeting content — a transcript, script, audio file path, or rough notes — and wants it turned into a proper meeting record. Trigger on phrases like "회의록 써줘", "미팅 노트 정리해줘", "회의 내용 정리", "write meeting notes", or when a user pastes a meeting transcript and says "이거 회의록으로 만들어줘". Also trigger when the user shares a meeting recording or file and asks to summarize or document it.
---

# Meeting Notes Skill

Structure meeting content into a standardized format and publish it to the team's Notion Meeting Notes DB as the single source of truth.

---

## Phase 1: Resolve Input Source

Meeting content can arrive in three ways. Check in priority order.

### Source A — Pasted transcript or notes (primary)

If the user's message contains a conversation transcript, bullet-point notes, or any block of meeting content:

- Use it directly as the source.
- Announce: "회의 내용을 기반으로 회의록을 작성할게요."

### Source B — File path

If the user provides a file path (`.md`, `.txt`, `.docx`, etc.):

- Read the file and use its content as the source.
- Audio/video files: respond with "죄송합니다, 오디오 파일은 직접 읽을 수 없어요. 텍스트로 변환된 녹취록을 붙여주시면 회의록을 작성해드릴게요."

### Source C — Interactive Q&A (fallback)

If no source is available, ask in sequence:

1. "회의 날짜와 시간이 언제였나요?"
2. "참석자는 누가 있었나요? (결석자도 알려주시면 좋아요)"
3. "이 회의의 목표가 무엇이었나요? (단 하나의 목표)"
4. "회의에서 어떤 내용들이 논의되었나요? 자유롭게 말씀해 주세요."
5. "이 회의의 유형은 무엇인가요? (기획 / 의사결정 / 스탠드업 / 회고 / 브레인스토밍)"
6. Read `~/.dmk-workflow/config.json` and list the available projects by name, then ask: "어느 프로젝트와 관련된 회의인가요? (번호로 선택하거나, 없으면 '없음'이라고 말씀해 주세요)"

---

## Phase 2: Extract Key Information

From the source, extract the following:

- Date and time
- Attendees (full names, roles if available)
- Absentees (if mentioned)
- Meeting goal / agenda
- Decisions made (what was decided + why)
- Action items (task, owner, due date)
- Main discussion threads — for opinions, predictions, or proposals, note the speaker's name so the source of the claim is clear
- Deferred or unresolved topics
- **Meeting Type** — infer from the content (기획 / 의사결정 / 스탠드업 / 회고 / 브레인스토밍). If it cannot be confidently inferred, ask the user: "이 회의의 유형이 어떻게 되나요? (기획 / 의사결정 / 스탠드업 / 회고 / 브레인스토밍)"
- **Project** — Read `~/.dmk-workflow/config.json` and list the available projects by name. Ask the user: "어느 프로젝트와 관련된 회의인가요? (번호로 선택하거나, 없으면 '없음'이라고 말씀해 주세요)" If the user selects "없음", leave the `프로젝트` property empty. Skip this question only if the user already answered it in Source C.

---

## Phase 3: Write the Meeting Notes

Compose the meeting notes draft using this template. If a section has no content, write "해당 없음." — never omit the section.

```markdown
# 회의록: {meeting title or main agenda item}

---

### 1. Meta Information (기본 정보)

- **Date & Time:** {date} {time}
- **Attendees:** {attendee list}
- **Absent:** {absentees, or 해당 없음}
- **Goal / Agenda:** {single, clear goal for this meeting}

---

### 2. TL;DR (핵심 요약)

{2–3 sentences. A busy C-level or team member should be able to grasp the outcome in under 10 seconds.}

---

### 3. Decisions Made (의사 결정 사항)

| 결정 내용  | 이유        |
| ---------- | ----------- |
| {decision} | {reasoning} |

---

### 4. Action Items (액션 아이템) ★

| Task            | DRI                  | Due Date   |
| --------------- | -------------------- | ---------- |
| {specific task} | {person's full name} | {deadline} |

---

### 5. Discussion / Context (주요 논의 내용)

- {key discussion point}
- {speaker name}: {opinion, prediction, or proposal attributed to that person}

---

### 6. Parking Lot (보류 안건)

- {deferred topic or idea}
```

---

## Phase 4: Publish to Notion

### 4-1. Read config

Read `~/.dmk-workflow/config.json` and extract:

- `notion_token`
- `notion_dbs.meeting_notes_db` (Meeting Notes DB ID)
- `notion_dbs.project_db` (Projects DB ID)

If any of these values are missing, stop and tell the user: "~/.dmk-workflow/config.json에 `notion_token` 또는 DB ID가 없어요. 값을 확인하고 추가해 주세요."

### 4-2. Resolve Project page ID

Query the Projects DB to find the page ID matching the project the user selected:

```bash
curl -s -X POST "https://api.notion.com/v1/databases/{project_db}/query" \
  -H "Authorization: Bearer {notion_token}" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{}' | jq '.results[] | {id: .id, name: .properties["[고객사명] 프로젝트명"].title[0].plain_text}'
```

Match by project name and store the page ID.

### 4-3. Create the Notion page

Call the Notion Pages API to create a new page in the Meeting Notes DB:

```bash
curl -s -X POST "https://api.notion.com/v1/pages" \
  -H "Authorization: Bearer {notion_token}" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{
    "parent": { "database_id": "{meeting_notes_db}" },
    "properties": {
      "제목": { "title": [{ "text": { "content": "{meeting title}" } }] },
      "날짜": { "date": { "start": "{YYYY-MM-DDTHH:MM:SS+09:00}" } },
      "회의 유형": { "select": { "name": "{meeting type}" } },
      "프로젝트": { "relation": [{ "id": "{project_page_id}" }] },
      "상태": { "select": { "name": "Draft" } }
    },
    "children": [
      {
        "object": "block", "type": "heading_2",
        "heading_2": { "rich_text": [{ "text": { "content": "Goal / Agenda" } }] }
      },
      {
        "object": "block", "type": "paragraph",
        "paragraph": { "rich_text": [{ "text": { "content": "{goal}" } }] }
      },
      {
        "object": "block", "type": "heading_2",
        "heading_2": { "rich_text": [{ "text": { "content": "TL;DR" } }] }
      },
      {
        "object": "block", "type": "paragraph",
        "paragraph": { "rich_text": [{ "text": { "content": "{tldr}" } }] }
      },
      {
        "object": "block", "type": "heading_2",
        "heading_2": { "rich_text": [{ "text": { "content": "Decisions Made (의사 결정 사항)" } }] }
      },
      ... (decisions as bulleted_list_item blocks)
      {
        "object": "block", "type": "heading_2",
        "heading_2": { "rich_text": [{ "text": { "content": "Action Items (액션 아이템) ★" } }] }
      },
      ... (action items as bulleted_list_item blocks: "Task | DRI | Due Date" format)
      {
        "object": "block", "type": "heading_2",
        "heading_2": { "rich_text": [{ "text": { "content": "Discussion / Context (주요 논의 내용)" } }] }
      },
      ... (discussion points as bulleted_list_item blocks)
      {
        "object": "block", "type": "heading_2",
        "heading_2": { "rich_text": [{ "text": { "content": "Parking Lot (보류 안건)" } }] }
      },
      ... (parking lot items as bulleted_list_item blocks)
    ]
  }'
```

### 4-4. Report result

After successful creation, output:

- "노션에 회의록이 생성됐어요: {notion_page_url}"

The page URL format is: `https://www.notion.so/{page_id_without_hyphens}`

---

## Phase 5: Quality Check

After publishing, automatically flag any of the following and prompt the user to resolve them:

- Action items with no due date → "기한이 정해지지 않은 액션 아이템이 {N}건 있어요. 기한을 추가하시겠어요?"
- Action items with no named DRI → "담당자가 불분명한 액션 아이템이 {N}건 있어요. 담당자를 지정해 주시면 업데이트할게요."
- TL;DR longer than 3 sentences → compress automatically before publishing.

If the user confirms corrections, update the Notion page via the Blocks API (`PATCH /v1/blocks/{block_id}`) rather than recreating the page.

---

## Rules

- **Output language is always Korean.** Write the entire meeting notes document in Korean, regardless of what language the source material is in. Section headers follow the template exactly, and all content inside each section must be in Korean.
- **Strict objectivity.** Do not add your own interpretation or logical leaps. Only write what was explicitly stated in the source.
- **Attribute opinions to speakers.** A participant's claim or prediction is not a fact. Write it as "{이름}: ~할 것으로 예상" rather than stating it as an established truth.
- **One goal.** Even if multiple topics were discussed, the meeting goal is a single sentence capturing the primary intended outcome. If the user gives multiple goals, ask which one was the primary purpose.
- **Decisions vs. discussion.** "We talked about X" belongs in Discussion / Context. "We decided on X" belongs in Decisions Made. Don't mix them.
- **DRI must be a person's name.** Never write "개발팀" or "마케팅팀" as a DRI. If the owner is genuinely unclear, write `[담당자 미정]`.
- **Infer, but tag it.** If attendees aren't listed but names appear in the transcript, treat them as attendees and mark with `[추론]`.
- **Config errors stop the flow.** If `~/.dmk-workflow/config.json` is missing or incomplete, do not proceed to publishing. Inform the user of the exact missing field.
