---
name: write-sdlc-initiative
description: Writes a 이니셔티브 document in Notion "Triggers" DB through interactive Q&A. Conducts section-by-section dialogue with the user following a 7-section bet structure: TL;DR, Problem, DIBB, Fat Marker Sketch, Appetite, Rabbit Holes/No-gos, Success/Kill Criteria. Each section has sentence stems, good/bad examples, and self-check questions that structurally prevent vague or performative writing ("AI will be useful" is literally unwriteable here). Use when the user says "이니셔티브 써줘", "이니셔티브 작성", "write initiative", "베팅 문서 만들자", or wants to document a large bet that requires 2–6 weeks of team time. Do NOT use for small feature additions, bug fixes, or chores: those are Specs, not Initiatives.
---

# Write Initiative Document

A 이니셔티브 is a **bet**, not a spec. It asks the team to stake 2–6 weeks on a specific hypothesis about a specific user's problem. This skill forces substantive writing by making generic claims (e.g., "AI will be useful") structurally unwriteable.

The deliverable is a new page in Notion **Triggers DB** with all 7 sections filled, linked to a Project and (optionally) a parent Request.

## When to Use

- User wants to document a strategic/large bet that spans 2–6 weeks.
- User has a Request in Notion Requests DB that looks big enough to need Initiative-level framing.
- User says "이니셔티브 써줘", "이니셔티브 문서 만들자", "큰 건 하나 기획해야 해", "write initiative", "write initiative".

## When NOT to Use

- Small bug fix → use Spec · 버그 instead.
- Small feature addition (< 2 weeks) → use Spec · 기능 instead.
- Tech debt / compliance / support → use Spec · 기타 instead.
- User has no concrete problem or user yet: redirect to do customer interviews first.

## Prerequisites

All Notion access goes through the `notion-api` skill's bash scripts. Its preconditions apply verbatim: `~/.datamktkorea/config.json` with `notion_token` + `notion_dbs` map, `jq` installed, the Integration shared with the relevant databases. If any `notion-api` script exits with code 2 (precondition failure), surface the printed hint to the user and stop.

Templates in Notion are NOT used by this skill — all content is generated here and written directly via `create-page.sh`.

## Scripts used

Shorthand used throughout this skill. Full signatures and behavior live in `notion-api/SKILL.md`.

| Shorthand | Resolves to |
|---|---|
| `query-db.sh` | `${CLAUDE_PLUGIN_ROOT}/skills/notion-api/scripts/query-db.sh` |
| `fetch-page.sh` | `${CLAUDE_PLUGIN_ROOT}/skills/notion-api/scripts/fetch-page.sh` |
| `fetch-page-properties.sh` | `${CLAUDE_PLUGIN_ROOT}/skills/notion-api/scripts/fetch-page-properties.sh` |
| `create-page.sh` | `${CLAUDE_PLUGIN_ROOT}/skills/notion-api/scripts/create-page.sh` |

DB references use config keys: `requests_db`, `triggers_db`, `projects_db`. Raw UUIDs live only in `~/.datamktkorea/config.json` and the authoritative schema in `notion-api/SKILL.md`.

## Core Principle: Every Section Has a Forcing Function

The failure mode this skill prevents: writers filling section headers with generic corporate-speak ("AI 에이전트가 유용할 것이다", "사용자 만족도 향상", "지속적 모니터링").

Each section therefore has:

- **Sentence stem**: a grammatical structure that makes vague answers impossible.
- **Good example**: a concrete, specific real-world sample.
- **Bad example**: the lazy version, clearly labeled as wrong.
- **Self-check**: 3–4 yes/no questions the answer must pass before moving on.

If the user writes something that fails self-check, **do not advance**. Push back with a specific probe ("실명 or 페르소나가 없네요. 이 사용자의 이름이나 역할을 구체적으로 쓸 수 있나요?").

### Note on examples

Every concrete identifier in this skill's Good/Bad examples (user names, company names, domain terms like "치과"·"미소 병원"·"김영희 실장", metrics, team members like "@김개발") is illustrative only — drawn from a single running example (dental-clinic chart automation) for clarity. When running the skill, never copy these identifiers into the user-facing prompt or the Initiative body. Substitute real values from the user's context.

## Workflow Overview

| Phase                    | What happens                                                     |
| ------------------------ | ---------------------------------------------------------------- |
| 0. Input resolution      | Link to existing Request (optional), pick Project, pick 출처     |
| 1. TL;DR                 | One paragraph committing to user + problem + timeframe + metric  |
| 2. Problem               | Named user hitting a specific wall + current workaround          |
| 3. DIBB                  | Data → Insight → Belief → Bet chain                              |
| 4. Fat Marker Sketch     | User-visible flow in 3–5 steps + riskiest interaction            |
| 5. Appetite              | 2 weeks OR 6 weeks, no extension clause                          |
| 6. Rabbit Holes & No-gos | Pre-declared scope-creep defenses                                |
| 7. Success / Kill        | Numeric success threshold + numeric kill threshold + named owner |
| 8. Review & Write        | Compile full body, set properties, create Notion page            |

## Phase 0: Input Resolution

### 0.1 Link to existing Request (optional)

Ask:

> "이 이니셔티브가 Notion Requests DB의 기존 요청에 연결되나요?  
> (a) 네: **페이지 제목 또는 URL**을 알려주세요  
> (b) 아니요: 새로 시작하겠습니다"

If (a):

- **URL 또는 32자 페이지 ID를 받은 경우**: 바로 fetch.
  ```bash
  fetch-page-properties.sh "<url-or-id>"
  fetch-page.sh "<url-or-id>" --markdown-only
  ```
  URL 형태면 `fetch-page.sh` 내부에서 ID를 파싱합니다. 가져온 properties의 `parent.data_source_id`가 `requests_db`의 data source와 일치하는지 확인 (Requests DB 소속 페이지인지 검증). 아니면 사용자에게 "이 페이지는 Requests DB 소속이 아닙니다"라고 알리고 다시 물어봅니다.

- **제목 키워드만 받은 경우**: 검색 후 선택.
  ```bash
  query-db.sh requests_db \
    --filter "$(jq -n --arg k "<keyword>" '{property:"이름", title:{contains:$k}}')" \
    --page-size 5
  ```
  `.results[]`에서 title (`.properties["이름"].title[0].plain_text`), 유형 (`.properties["유형"].select.name`), 생성 일시를 보여주고 번호로 선택받습니다.

- 어느 경로든: Request의 `id`를 저장 (이후 새 Initiative의 `Requests DB` relation 값이 됨).

If (b):

- Proceed. No Request relation.

### 0.2 Pick Project

Ask:

> "이 이니셔티브는 어느 프로젝트 아래에 들어가나요?"

Query Projects DB, filtering out archived entries server-side:

```bash
query-db.sh projects_db \
  --filter '{"property":"아카이브","checkbox":{"equals":false}}' \
  --page-size 25
```

Show a numbered list of `.results[]` using `.properties["프로젝트명"].title[0].plain_text`. Let the user pick by number. Save the Project's `id` (for the `Projects DB` relation).

### 0.3 Pick 출처 (Source)

Ask:

> "이 이니셔티브의 출처는 무엇인가요?
>
> 1. Strategic: 경영진/창업자 지시 (OKR, 전략 테마)
> 2. Customer: 고객사/영업 요구 (계약, SLA)
> 3. Ops: 운영/컴플라이언스 (규제, 장애 회고)
> 4. Product: 내부 PM 로드맵 (사용자 지표 기반)"

Save the choice. This sets the `출처` select property.

### 0.4 Pick 우선순위 and 허용 기간 (initial)

Ask:

> "우선순위는? P0(긴급) / P1(높음) / P2(보통) / P3(낮음)"
> "예상 허용 기간은? 1주 / 2주 / 6주 / 3개월 / 6개월+
> (Phase 5에서 최종 확정하지만 지금은 대략)"

Save both.

## Phase 1: TL;DR (한 문단 요약)

**Why this section exists:** If the writer can't explain the bet in one paragraph, they don't understand it yet. This is the Linear "summary-first" and Amazon "press release headline" principle.

**Ask:**

> "한 문단 요약을 써주세요. 다음 형식을 반드시 지켜주세요:
>
> 우리는 **[구체적 사용자/상황]**이 **[구체적 문제]**를 겪고 있다고 본다.
> **[N주]** 안에 **[구체적 해결책]**을 만들어 **[측정 가능한 지표]**를 **[숫자]** 만큼 움직이는 데 베팅한다.
>
> 3~5문장, 80단어 이내로."

**Good example:**

> 치과 원장들이 신환 상담 후 차트 작성에 하루 평균 90분을 쓰고 있다. 6주 안에 음성-to-차트 자동화 MVP를 만들어 상담 차트 작성 시간을 주당 3시간 이상 줄이는 데 베팅한다.

**Bad example (reject this kind):**

> AI를 활용해 치과 업무 효율을 개선하는 이니셔티브.
> → 사용자 없음, 지표 없음, 기한 없음

**Self-check (do not advance until all pass):**

- [ ] 이 한 문단만 읽고 동료가 "무엇에 얼마만큼 언제까지"를 말할 수 있는가
- [ ] 사용자, 문제, 기간, 지표가 모두 한 문장에 있는가
- [ ] 숫자가 최소 2개 이상인가 (기간 + 지표)

**Probing pushback if answer fails:**

- "사용자가 추상적이에요. 구체적으로 누구인가요? (역할/업종/규모)"
- "지표에 숫자가 없어요. 어떤 숫자를 어디까지 움직이고 싶나요?"
- "기간이 없어요. 2주 or 6주 중 지금 감은 어느 쪽인가요?"

## Phase 2: Problem (문제)

**Why this section exists:** Abstract problems produce abstract solutions. Shape Up Ch.6 is explicit: the problem must be "a specific story about someone hitting a specific wall."

**Ask:**

> "문제를 다음 5가지로 쪼개서 써주세요:
>
> 1. **누가**: 실명 or 구체적 페르소나 (역할, 경력, 규모)
> 2. **언제**: 문제가 발생하는 트리거 순간
> 3. **무엇을 하려다**: 그들이 달성하려는 작업
> 4. **무엇이 막혀서**: 지금 벽에 부딪히는 지점
> 5. **그래서 어떻게 버티고 있나**: 현재 workaround (이게 있어야 진짜 문제)"

**Good example:**

- **누가:** 미소 병원 김영희 실장 (15년차, 3개 지점 관리)
- **언제:** 매주 금요일 오후, 3개 지점 매출 리포트를 이사회에 올려야 할 때
- **무엇을 하려다:** 지점별 신환/재진/매출 데이터를 엑셀로 합산
- **무엇이 막혀서:** 각 지점이 다른 포맷으로 제출. 수기 정리에 4시간
- **그래서 어떻게 버티고 있나:** 금요일 야근 or 토요일 출근. 작년 10월부터 이직 고려 중

**Bad example:**

> 병원 관리자들이 리포팅에 시간을 많이 쓴다.
> → 누가? 언제? workaround는? 없으면 가짜 문제

**Self-check:**

- [ ] 사용자가 실명 or 구체적 페르소나인가 ("users" 금지)
- [ ] 트리거 순간이 명시됐는가
- [ ] 현재 workaround가 적혀있는가
- [ ] 고객 인용구 or 실제 데이터 포인트가 있는가

**Probing pushback:**

- "'사용자가'로 시작하면 통과 못 해요. 누군가 한 명을 특정해주세요."
- "현재 이 사람이 어떻게 버티고 있나요? workaround 없으면 그 문제는 실제로 아프지 않다는 뜻이에요."

## Phase 3: DIBB (Data → Insight → Belief → Bet)

**Why this section exists:** This is the structural cure for "AI가 유용할 것이다" type claims. Spotify's DIBB requires a chain: no Belief without an Insight, no Insight without Data. Belief has to be derivable and falsifiable.

**Ask:**

> "4단계를 순서대로 써주세요:
>
> 1. **Data**: 관찰된 사실. 숫자/인용/로그/설문. '많다/자주/대부분' 같은 말은 금지
> 2. **Insight**: 데이터가 드러내는 패턴. '즉, X가 Y인 이유는…'
> 3. **Belief**: 인사이트로부터 도출한, **틀릴 수 있는** 주장
> 4. **Bet**: 이 믿음이 맞다면 해야 할 구체적 작업"

**Good example:**

- **Data:** 최근 3개월 미소 병원 고객 12곳 인터뷰에서 9곳이 "차트 작성이 1일 업무의 30% 이상"이라고 답함. 실제 로그 측정 결과 평균 94분/일
- **Insight:** 차트의 70%는 상담 중 구두로 이미 말한 내용의 재작성. 즉 정보는 존재하고 단지 '옮겨 적는' 행위가 병목이다
- **Belief:** 상담 음성을 구조화된 차트로 자동 변환하면 94분의 60% 이상 제거 가능
- **Bet:** 음성→차트 MVP 6주 + 3개 병원 베타 테스트

**Bad example:**

- Data: 고객들이 바쁘다
- Insight: AI가 도와줄 수 있다
- Belief: AI 에이전트가 유용할 것이다
  > → Data는 숫자 없음, Belief는 반증 불가능. 완전한 공허

**Self-check:**

- [ ] Data에 숫자 or 직접 인용이 있는가
- [ ] Insight가 Data로부터 추론된 것인가 (Data 없는 의견이면 Insight 아님)
- [ ] Belief가 **틀릴 수 있는가** (반증 불가능하면 슬로건이지 믿음이 아님)
- [ ] Data가 2차 자료/추측이면 "추정" 명시했는가

**Probing pushback:**

- "Data에 숫자가 없어요. '많다/대부분'은 쓸 수 없어요. 몇 명 중 몇 명, 혹은 몇 분/건 이런 형태로요."
- "Belief가 '유용할 것이다' 식이면 반증이 불가능해요. 어떤 숫자/조건이 맞으면 믿음이 틀렸다고 인정할까요?"
- "Data → Insight → Belief 가 논리적으로 연결되나요? Belief를 Data 없이도 말할 수 있다면, Data가 Belief를 지지하지 않는 거예요."

## Phase 4: Fat Marker Sketch (해결책 스케치)

**Why this section exists:** Shape Up Ch.4: "fat marker sketches." Enough detail to bound the work, not enough to preempt designer/engineer craft. User-visible flow is the level; wireframes are too detailed; architecture words are too abstract.

**Ask:**

> "해결책을 세 부분으로 써주세요:
>
> 1. **핵심 흐름**: 사용자가 [시작점]에서 [끝점]까지 도달하는 3~5단계 (UI/아키텍처 용어 금지, 사용자 행동 중심)
> 2. **관건이 되는 지점**: 이 중 가장 위험하거나 새로운 1~2지점. 여기가 망하면 전체 망함
> 3. **기존 시스템과의 접점**: 어디에 붙고, 무엇을 바꾸는가"

**Good example:**

- **핵심 흐름:**
  1. 상담 시작 시 실장이 "녹음" 버튼 누름
  2. 상담 종료 후 자동으로 초안 차트 생성
  3. 원장이 초안 리뷰/수정 (평균 3분)
  4. 승인 시 기존 EMR에 저장
- **관건:** 3단계 리뷰/수정 UI. 잘못된 필드를 빠르게 고칠 수 없으면 전체 시간 절감 없음
- **접점:** 기존 EMR의 차트 저장 API에 write만. 읽기는 하지 않음 (권한 단순화)

**Bad example:**

> AI 에이전트가 상담 내용을 듣고 차트를 작성한다. LLM 파이프라인과 벡터 DB를 사용한다.
> → 아키텍처 단어만 있고 사용자 흐름이 없음

**Self-check:**

- [ ] 기술 용어를 다 지워도 흐름이 이해되는가
- [ ] 가장 위험한 1지점을 콕 집었는가
- [ ] 기존 시스템과의 접점이 명시됐는가
- [ ] 와이어프레임 수준까지 내려갔다면 너무 상세 (되돌릴 것)

**Probing pushback:**

- "'LLM', 'API', 'pipeline' 같은 기술 용어를 다 빼고 다시 써주세요. 사용자가 무엇을 하고 무엇을 보는지만."
- "관건 지점이 없어요. 이 중 망하면 전체가 망하는 1지점이 어딘가요?"

## Phase 5: Appetite (식욕)

**Why this section exists:** The single most important Shape Up contribution. Changing "how long will it take?" (unanswerable, padded) to "how much is it worth?" (answerable, trade-off forcing).

**Ask:**

> "식욕(Appetite)을 세 부분으로 써주세요:
>
> 1. **식욕**: 2주(Small) 또는 6주(Big) **둘 중 하나로 단언**. 그 사이는 없음
> 2. **근거**: 왜 더 길면 안 되는가. 왜 이 정도는 투자할 가치가 있는가
> 3. **데드라인 동작**: 기간 다 되면 [출시 / 중단 / 재-pitch]. **연장 없음** 조항 필수"

**Good example:**

- **식욕:** 6주 (Big Batch)
- **근거:** 2주로는 음성 인식 정확도를 쓸 만한 수준으로 못 올림 (파일럿 데이터 부족). 8주 이상 투자하기엔 경쟁사 유사 기능 발표 리스크. 6주가 MVP + 3개 병원 베타 가능한 최소 창
- **데드라인 동작:** 6주차 금요일에 3개 병원 배포 or 중단 후 회고. **연장 없음**

**Bad example:**

> 약 2~3개월 예상. 복잡도에 따라 유동적.
> → 식욕이 아니라 추정. "유동적" = 무한 연장 보장

**Self-check:**

- [ ] 2주 or 6주 중 하나로 단언했는가
- [ ] "연장 없음" 조항이 있는가
- [ ] 이 식욕이 왜 이 숫자인지 한 문장 근거가 있는가

**Probing pushback:**

- "'3~4주' 같은 중간값은 허용 안 돼요. 2주로 가능하면 2주, 부족하면 6주. 어느 쪽이에요?"
- "'유동적', '복잡도에 따라' 같은 말은 연장 보장이에요. 지우고 고정 문구로 바꿔주세요."

Also update the `허용 기간` property to match the final choice.

## Phase 6: Rabbit Holes & No-gos (함정과 하지 않을 것)

**Why this section exists:** Scope creep killer, written in advance. When mid-cycle someone says "이것도 넣자", the answer is "it's in No-gos, re-pitch next cycle." Without this section, extension is guaranteed.

**Ask:**

> "두 가지를 써주세요:
>
> 1. **Rabbit holes**: 빠지면 기간 폭주할 기술적 덫. **각 항목마다 우회 전략** 명시.
>    형식: [구체적 덫] → [우회 전략]
> 2. **No-gos**: 이번 사이클에 하지 않는 것. **유혹적인** 스코프만.
>    형식: [유혹적이지만 미루는 스코프] → [왜 미루는지 한 줄]"

**Good example:**

Rabbit holes:

- 음성 인식 커스텀 모델 학습 → 하지 않는다. Whisper API 그대로. 정확도 부족하면 프롬프트로 해결, 그래도 안 되면 스코프 축소 (전체 차트 → 핵심 필드 3개만)
- EMR 읽기 권한 → 요청하지 않는다. write-only로 시작

No-gos:

- 다국어 지원 → 한국어만. 영어 원장도 한국어 차트 씀
- 모바일 앱 → 데스크톱 웹만. 상담실에 iPad 없음
- 보험 청구 자동화 → 다음 사이클

**Bad example:**

> 리스크: 기술적 복잡도, 일정 지연, 스코프 변경 가능성
> → 일반명사 나열. 방어 메커니즘 없음. 이걸로는 아무도 거절 못 함

**Self-check:**

- [ ] Rabbit hole마다 "우회 전략"이 적혀있는가
- [ ] No-gos가 **유혹적인** 스코프인가 (유혹적이지 않으면 쓸 필요 없음)
- [ ] 사이클 중간에 "이것도 넣자"라고 하면 이 리스트로 거절 가능한가

**Probing pushback:**

- "'기술적 복잡도' 같은 일반명사는 받지 않아요. 어떤 특정 기술 함정인지 이름을 붙여주세요."
- "No-gos에 쓴 항목이 아무도 넣자고 안 할 것 같은 거예요. 유혹적이지 않으면 No-go로 쓸 필요 없어요. 진짜 유혹적인 걸 미뤄주세요."

## Phase 7: Success / Kill Criteria (성공과 실패의 기준)

**Why this section exists:** Most docs have "Metrics" that become vague dashboards. This section forces BOTH a success number AND a kill number. Without kill criteria, you get zombie projects.

**Ask:**

> "네 가지를 써주세요:
>
> 1. **성공 기준**: [기간] 후 [지표]가 [숫자]이면 성공
> 2. **중단 기준**: [중간 체크포인트]에 [지표]가 [숫자] 미만이면 중단
> 3. **측정 방법**: 로그/설문/인터뷰. **이미 존재하는** 데이터 소스여야 함
> 4. **측정 책임자**: 실명 1명"

**Good example:**

- **성공 기준:** 8주차(출시 후 2주)에 베타 3개 병원의 원장당 일일 차트 작성 시간이 기존 94분 → 40분 이하
- **중단 기준:** 4주차(MVP 완성 시점)에 내부 테스트에서 초안 차트의 필드 정확도가 80% 미만이면 스코프 축소 (핵심 필드 3개만) or 중단
- **측정 방법:** 차트 저장 timestamps 로그 + 원장 주간 인터뷰
- **책임자:** @김개발

**Bad example:**

> 사용자 만족도 향상, 효율성 개선, 지속적 모니터링
> → 숫자 없음, 중단 조건 없음, 책임자 없음. 시작하면 끝이 없음

**Self-check:**

- [ ] 성공 기준이 숫자 + 기한으로 표현됐는가
- [ ] 실패/중단 기준이 있는가 (없으면 좀비 프로젝트 확정)
- [ ] 측정 방법이 **이미 존재하는** 데이터 소스인가 (새로 만들어야 하면 함정)
- [ ] 이름 붙은 책임자 1명이 있는가

**Probing pushback:**

- "'만족도 향상' 같은 건 받지 않아요. 어떤 숫자가 어디서 어디로 움직여야 하나요?"
- "중단 기준이 빠졌어요. 이 이니셔티브가 실패하고 있다는 걸 언제 알 수 있나요? 구체적 수치와 시점으로."
- "측정 방법이 '새 대시보드 만들어서 측정'이면 함정이에요. 이미 있는 로그/인터뷰/설문을 써야 해요."

## Phase 8: Review & Write to Notion

### 8.1 Final review

Before writing, show the compiled body back to the user as a preview:

> "작성 완료. 아래 내용으로 Notion Triggers DB에 저장할게요. 수정할 부분 있으면 말씀해주세요."

Show a summary: title + 출처 + 허용 기간 + 우선순위 + 요약 (Phase 1 내용) + section count with any incomplete sections flagged.

### 8.2 Generate title

If the user didn't provide a title, generate one from the TL;DR:

- Format: `[출처 약어] 해결책 핵심 + 대상`: e.g., `[Product] 음성-to-차트 자동화 MVP (미소)`

Confirm with user before writing.

### 8.3 Write to Notion

Compose the `properties` JSON with the values collected in Phase 0 and the final title, then call `create-page.sh`. Pass the body via stdin to avoid shell-quoting pain with multiline markdown:

```bash
properties=$(jq -n \
  --arg title "<generated or user-supplied title>" \
  --arg source "<Strategic|Customer|Ops|Product>" \
  --arg appetite "<1 Week|2 Weeks|6 Weeks|3 Months|6+ Months>" \
  --arg priority "<P0|P1|P2|P3>" \
  --arg proj "<project_id from Phase 0.2>" \
  --arg req "<request_id from Phase 0.1, or empty>" \
  '{
    "이름":      {"title":[{"text":{"content":$title}}]},
    "출처":      {"select":{"name":$source}},
    "허용 기간": {"select":{"name":$appetite}},
    "우선순위":  {"select":{"name":$priority}},
    "Projects DB": {"relation":[{"id":$proj}]}
  } + (if $req == "" then {} else {"Requests DB": {"relation":[{"id":$req}]}} end)')

create-page.sh --parent triggers_db --properties "$properties" --markdown - <<'EOF'
<full markdown body of 7 sections — see 8.4>
EOF
```

Do **not** set `상태` at creation. Leave it empty (active). Only set `상태` to `Success` or `Killed` later when the Initiative terminates.

Do **not** apply any Notion template. Content is generated fresh.

### 8.4 Body structure

The final body written to Notion is the 7 sections WITHOUT the skill's meta-explanation (no "Why this section exists", no "Bad example", no "Self-check"). Only section headers + the user's actual answers.

Format:

```markdown
## 1. TL;DR

<user's paragraph>

## 2. Problem

- **누가:** …
- **언제:** …
- **무엇을 하려다:** …
- **무엇이 막혀서:** …
- **그래서 어떻게 버티고 있나:** …

## 3. DIBB

**Data:** …
**Insight:** …
**Belief:** …
**Bet:** …

## 4. 해결책 스케치

**핵심 흐름:**

1. …
   **관건:** …
   **접점:** …

## 5. Appetite

**식욕:** 6주 (Big Batch)
**근거:** …
**데드라인 동작:** …

## 6. Rabbit Holes & No-gos

**Rabbit holes:**

- … → …

**No-gos:**

- … → …

## 7. Success / Kill Criteria

**성공 기준:** …
**중단 기준:** …
**측정 방법:** …
**책임자:** @…
```

### 8.5 Confirm completion

After successful write, respond:

> "이니셔티브 생성 완료: [페이지 제목]
> URL: [Notion 페이지 URL]
>
> 다음 단계:
>
> - 하위 Spec 분해가 필요하면 `write-sdlc-feature` 스킬 호출

Return the created page URL in the final message.

## Error Handling

- **notion-api precondition failed (exit 2)** → surface the script's stderr hint (missing config, jq not installed, integration not shared, etc.) and stop.
- **Project not found** → prompt user again, show all projects.
- **User refuses to write a section substantively** (3+ failed self-checks on same section) → offer to save as draft (Notion page with `[DRAFT]` prefix in title) and come back later.
- **User wants to skip a section** → do NOT allow. Every section is load-bearing. Explain which failure mode cutting that section causes.
- **User says "시간 없어 대충 써줘"** → refuse politely. This skill's value is in forcing substance. If the user wants a stub, they can write a Notion page directly without this skill.

## Anti-Patterns (do NOT do these)

- Do not combine sections into one big question. Each section's forcing function depends on being isolated.
- Do not let the user paste a generic PRD and auto-fill sections. The Q&A is the point.
- Do not use templates from Notion. Write content directly.
- Do not add sections the user didn't ask for (no "Dependencies", "Risks", "Stakeholders"). Those are deliberately excluded per the design.
- Do not add ceremony emoji in the final body. Section numbers + plain text only.
- Do not mark a section complete if self-check fails. Push back.
