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
6. Read `~/.datamktkorea/config.json` and list the available projects by name, then ask: "어느 프로젝트와 관련된 회의인가요? (번호로 선택하거나, 없으면 '없음'이라고 말씀해 주세요)"

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
- **Project** — Read `~/.datamktkorea/config.json` and list the available projects by name. Ask the user: "어느 프로젝트와 관련된 회의인가요? (번호로 선택하거나, 없으면 '없음'이라고 말씀해 주세요)" If the user selects "없음", leave the `프로젝트` property empty. Skip this question only if the user already answered it in Source C.

---

## Phase 3: Write the Meeting Notes

Compose the meeting notes draft using this template. If a section has no content, write "해당 없음." — never omit the section.

Tables (Decisions Made, Action Items) will be rendered as Notion Table blocks in Phase 4.

```markdown
# 회의록: {meeting title or main agenda item}

---

### 1. Meta Information (기본 정보)

- **미팅일시:** {date} {time}
- **참석자:** {(회사명) 이름 외 N명 형식으로, 회사별로 묶어 표기. 마지막에 총 N명 추가. 예: (DMK) 이경준, (AK아이에스) 김민한 차장 외 1명, 총 5명.}
- **아젠다:** {single, clear goal for this meeting}

---

### 2. TL;DR (핵심 요약)

{2–3 sentences. A busy C-level or team member should be able to grasp the outcome in under 10 seconds.}

---

### 3. Decisions Made (의사 결정 사항)

Only include items that were explicitly and unambiguously decided in the meeting.
If a decision is ambiguous, do NOT place it here — place it in Discussion / Context with a `[결정 여부 불명확]` tag.

| 결정 내용  | 이유        |
| ---------- | ----------- |
| {decision} | {reasoning} |

---

### 4. Action Items (액션 아이템) ★

| 할 일           | 담당자               | 기한       |
| --------------- | -------------------- | ---------- |
| {specific task} | {person's full name} | {deadline} |

---

### 5. Discussion / Context (주요 논의 내용)

발언자 이름을 앞에 붙여 출처 명확히. 관련 논의가 여러 줄로 이어질 경우 들여쓰기로 계층 표현.

- **{주제}**: {핵심 요점}
  - {발언자 이름}: {의견/예측/제안}
- `[결정 여부 불명확]` **{주제}**: {내용}

---

### 6. Parking Lot (보류 안건)

- {보류 항목}
```

---

## Phase 4: Publish to Notion

### 4-1. Read config

Read `~/.datamktkorea/config.json` and extract:

- `notion_token`
- `notion_dbs.meeting_notes_db` (Meeting Notes DB ID)
- `notion_dbs.project_db` (Projects DB ID)

If any of these values are missing, stop and tell the user: "~/.datamktkorea/config.json에 `notion_token` 또는 DB ID가 없어요. 값을 확인하고 추가해 주세요."

### 4-2. Resolve Project page ID

**Step 1 — Get the data_source_id for the Projects DB:**

```bash
curl -s "https://api.notion.com/v1/databases/{project_db}" \
  -H "Authorization: Bearer {notion_token}" \
  -H "Notion-Version: 2026-03-11" \
  | jq '.data_sources[0].id'
```

Store the result as `{project_data_source_id}`.

**Step 2 — Query the Projects DB:**

```bash
curl -s -X POST "https://api.notion.com/v1/data_sources/{project_data_source_id}/query" \
  -H "Authorization: Bearer {notion_token}" \
  -H "Notion-Version: 2026-03-11" \
  -H "Content-Type: application/json" \
  -d '{}' | jq '.results[] | {id: .id, name: .properties["[고객사명] 프로젝트명"].title[0].plain_text}'
```

Match by project name and store the page ID.

### 4-3. Create the Notion page

Pass properties and the full meeting notes body as a `markdown` string (see CLAUDE.md for API details). Use a heredoc to write the markdown clearly, then pass it through `jq` so newlines are escaped automatically.

```bash
MARKDOWN=$(cat <<'EOF'
## Goal / Agenda

{goal}

## TL;DR

{tldr}

## Decisions Made (의사 결정 사항)

| 결정 내용 | 이유 |
| --- | --- |
| {decision} | {reasoning} |

## Action Items (액션 아이템) ★

| 할 일 | 담당자 | 기한 |
| --- | --- | --- |
| {task} | {owner} | {deadline} |

## Discussion / Context (주요 논의 내용)

{discussion bullet points}

## Parking Lot (보류 안건)

{parking lot bullet points}
EOF
)

curl -s -X POST "https://api.notion.com/v1/pages" \
  -H "Authorization: Bearer {notion_token}" \
  -H "Notion-Version: 2026-03-11" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg md "$MARKDOWN" \
    --arg title "{meeting title}" \
    --arg date "{YYYY-MM-DDTHH:MM:SS+09:00}" \
    --arg type "{meeting type}" \
    --arg project_id "{project_page_id}" \
    '{
      parent: { database_id: "{meeting_notes_db}" },
      properties: {
        "제목": { title: [{ text: { content: $title } }] },
        "날짜": { date: { start: $date } },
        "회의 유형": { select: { name: $type } },
        "프로젝트": { relation: [{ id: $project_id }] },
        "상태": { select: { name: "Draft" } }
      },
      markdown: $md
    }')"
```

**Markdown authoring rules:**
- Use `##` for section headings (maps to Notion heading_2).
- Tables: standard GFM pipe syntax; include a separator row (`| --- |`).
- Bullet lists: prefix with `- `.
- Bold: `**text**`. Inline code: `` `text` ``.

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

If the user confirms corrections, update the Notion page via the Markdown API rather than recreating the page:

```bash
curl -s -X PATCH "https://api.notion.com/v1/pages/{page_id}/markdown" \
  -H "Authorization: Bearer {notion_token}" \
  -H "Notion-Version: 2026-03-11" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "update_content",
    "update_content": {
      "content_updates": [
        {
          "old_str": "{exact text to find}",
          "new_str": "{replacement text}",
          "replace_all_matches": false
        }
      ]
    }
  }'
```

---

## Rules

**언어 및 형식**

- 전체 한국어로 작성. 섹션 헤더는 템플릿 그대로.
- TL;DR을 제외한 모든 섹션은 마크다운의 장점을 적극 활용해 가독성 우선. 줄글보다 bullet, 중요 단어는 **bold**, 계층이 있으면 들여쓰기 등을 사용.
- 가운데점(·) 사용 자제. 쉼표로 대체 가능하면 쉼표 사용.
- Em dash(—) 사용 금지. 쉼표, 괄호, 문장 분리로 대체.

**내용 기준**

- 엄격한 객관성. 소스에 명시된 내용만 기재, 추론/해석 금지.
- 발언자 귀속. 의견, 예측, 제안은 반드시 "{이름}: ~" 형태로 출처 명시.
- 아젠다는 단 하나. 여러 주제가 논의됐더라도 핵심 목적 한 문장으로.

**섹션별 판단 기준**

- Decisions Made: 회의에서 명시적, 명확하게 결론 난 항목만. 불명확하면 Discussion에 `[결정 여부 불명확]` 태그로.
- DRI는 반드시 개인 이름. "개발팀", "마케팅팀" 금지. 불명확하면 `[담당자 미정]`.
- Absent: 실제 결석자가 있을 때만 포함. 없으면 항목 자체 생략.
- Parking Lot: 참석자가 "나중에 결정", "별도 논의" 등으로 명시적으로 보류한 전략/업무 항목만. 식사, 주차 등 운영 잡담 제외.
- 이름 추론: 이름이 녹취에만 등장할 경우 참석자로 처리하되 `[추론]` 태그 추가.

**발행 오류**

- `~/.datamktkorea/config.json`에 `notion_token` 또는 DB ID 누락 시 즉시 중단. 누락된 필드명을 사용자에게 안내.
