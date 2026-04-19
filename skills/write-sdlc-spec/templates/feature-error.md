---
category: feature-error
handles_request_type: 기능 에러
section_count: 8
---

# Template: 기능 에러 (Bug Spec)

A bug is a deterministic failure. This template is retrospective ("something happened, fix it") and forces reproduction, localization, and regression-guard thinking. Modeled on SWE-bench task format, Kiro bugfix WHEN/THEN, Bettenburg 2008 hypothesis-carrying reports, and CTQRS quality dimensions.

**Grounding mandate:** Sections 3, 5, 6, 7, 8 MUST cite real file:line and real error messages from the Implementation Map. Generic language (e.g., "maybe a race condition") without evidence gets pushed back.

## Sections (in order)

1. 한 줄 증상 (Symptom Line)
2. 재현 절차 (Reproduction Steps)
3. 현재 동작 vs 기대 동작 (Current vs Expected, WHEN/THEN)
4. 영향 범위 및 심각도 (Impact & Severity)
5. 위치 힌트 (Localization Hints)
6. 근본 원인 가설 (Root Cause Hypothesis)
7. 검증 커맨드 (Verification Commands: FAIL→PASS / KEEP-PASSING)
8. 변경하지 않을 것 (Unchanged Behavior)

## Section 1: 한 줄 증상

**이 섹션의 역할:** Atomicity (CTQRS 1번 차원). 한 버그 = 한 리포트. 여러 증상이면 쪼개야 한다.

**Ask (stem):**

> "한 줄로 증상을 써주세요. 다음 형식을 지켜주세요:
>
> **[조건/입력]**에서 **[관찰된 잘못된 동작]**이 발생한다. 사용자는 **[이 상태]**에 갇힌다.
>
> 1~2 문장, 여러 증상이면 하나만 남기고 나머지는 별도 Request로 분리."

**Good example:**

> TOC 생성 중 사용자가 페이지를 이탈했다가 돌아오면, 로딩 스피너가 영원히 돌고 '취소' 버튼도 비활성 상태다. 사용자는 새로고침 외에 탈출 경로가 없다.

**Bad example:**

> TOC가 이상하다. 업로드도 느리다. (증상 2개 섞임 + 구체성 부족)

**Self-check:**

- [ ] 한 문장 또는 두 문장인가
- [ ] 조건/입력이 구체적인가 (사용자 행동, 환경 조건)
- [ ] 잘못된 동작이 관찰 가능한가 (화면/에러/상태)
- [ ] 사용자가 빠진 상태(stuck state)가 명시됐는가

**Pushback probes:**

- "증상이 여러 개 섞여 있어요. 이 Request를 두 개로 쪼개거나, 가장 아픈 하나만 남겨주세요."
- "'이상하다'는 관찰이 아니에요. 어떤 UI/에러가 정확히 어떻게 나타나나요?"
- "사용자가 그 상태에서 무엇을 할 수 있나요? 탈출 경로가 있나요 없나요?"

**Length:** 1~2 문장.

**Grounding:** Request body의 증상 기술 + 가능하면 실제 에러 메시지 요약.

## Section 2: 재현 절차

**이 섹션의 역할:** Reproducibility는 time-to-fix의 최강 예측 변수 (CTQRS). 결정론적 재현 = AI가 fix 검증 가능.

**Ask (stem):**

> "다음을 써주세요:
>
> 1. **환경**: 브라우저/OS/role/feature flag 등 재현 조건
> 2. **단계**: 복붙 가능한 N단계 (한 액션 = 한 단계)
> 3. **재현율**: 100% 재현 / N회 중 M회 / 타이밍 의존
> 4. **관찰 vs 기대**: 마지막 단계에서 무엇이 보여야 하고 무엇이 보이는가"

**Good example:**

```
환경: Chrome 124 / macOS, role=publisher, flag toc_v2=on, 세션 시작 후 5분 이내.
단계:
  1. /agent/bookie 접속
  2. 책 상세 → "TOC 생성" 클릭
  3. 스트림 시작 후 2초 이내에 브라우저 뒤로가기
  4. 같은 책 상세로 재진입
관찰: 로딩 스피너 무한 회전, 취소 버튼 disabled.
기대: 스피너 없음, 또는 이전 스트림의 취소 가능 상태.
재현율: 100% (10/10 테스트).
```

**Bad example:**

> 가끔 TOC 로딩이 멈춘다. (조건·빈도·환경 전부 누락)

**Self-check:**

- [ ] 환경이 구체적으로 명시되었나 (브라우저 버전, role, flag)
- [ ] 각 단계가 한 액션인가 (복합 액션이면 분리)
- [ ] 복붙만으로 재현 가능한가
- [ ] 재현율이 명시되었나
- [ ] 관찰/기대가 분리되어 있나

**Pushback probes:**

- "'가끔'은 재현율이 아니에요. 10번 시도해서 몇 번 재현되나요?"
- "단계 3이 두 가지 액션을 합쳐놨어요. 분리해주세요."
- "환경이 빠졌어요. 어떤 브라우저/role에서 발생하나요? 다른 환경에서는 재현 안 되나요?"

**Length:** 환경 2~4줄 + 단계 3~8개 + 재현율 1줄.

**Grounding:** 사용자 입력 + Implementation Map의 진입점 file:line (해당 화면/기능).

## Section 3: 현재 동작 vs 기대 동작 (WHEN/THEN)

**이 섹션의 역할:** Kiro EARS 문법. WHEN/THEN SHALL 구조가 "개선" 같은 불명확 표현을 구조적으로 막는다.

**Ask (stem):**

> "두 가지를 써주세요:
>
> **현재 (Actual):** WHEN **[재현절차의 trigger]** THEN the system **[actually does X]**: 에러 verbatim: `...`
>
> **기대 (Expected):** WHEN **[같은 trigger]** THEN the system SHALL **[do Y instead]**."

**Good example:**

- **Current:** WHEN 사용자가 TOC 스트림 중 언마운트 후 재마운트 THEN `isGenerating` state가 true인 stale 값으로 복원된다. 콘솔: `AbortError: The operation was aborted` 뒤에 state 변경 없음.
- **Expected:** WHEN 사용자가 TOC 스트림 중 언마운트 THEN 스트림 SHALL 취소되고 `isGenerating` SHALL false로 리셋된다.

**Bad example:**

- 현재: 로딩이 안 끝남.
- 기대: 잘 됨.

**Self-check:**

- [ ] WHEN 절이 Section 2의 재현 trigger와 일치하는가
- [ ] Current의 에러 메시지가 verbatim인가 (요약/수정 금지)
- [ ] Expected가 SHALL 동사로 측정 가능한 결과를 명시하는가
- [ ] Current와 Expected가 같은 trigger를 공유하는가

**Pushback probes:**

- "Current의 에러 메시지가 재가공되어 있어요. 브라우저 콘솔/로그에서 그대로 복사해주세요."
- "'잘 됨'은 SHALL 뒤에 올 수 없어요. 정확히 어떤 상태/동작이 되어야 하나요?"
- "WHEN 절이 Section 2의 단계 3과 달라요. 통일해주세요."

**Length:** Current 1~3 bullets, Expected 1~3 bullets.

**Grounding:** 실제 콘솔/서버 로그에서 복사한 에러 메시지. Implementation Map의 관련 state 변수명.

## Section 4: 영향 범위 및 심각도

**이 섹션의 역할:** Severity inflation 방지. Chromium 기준에 따라 객관화.

**Ask (stem):**

> "다음 4가지를 써주세요:
>
> 1. **영향 받는 사용자**: 정량 추정 (N명, 역할, 비율)
> 2. **데이터 손실 여부**: Y/N, Y면 구체 설명
> 3. **우회 경로**: 있음/없음, 있으면 구체 단계
> 4. **심각도**: P0/P1/P2/P3 + 기준 매핑
>
> 심각도 기준:
>
> - P0: 데이터 손실 / 보안 / 전체 사용자 block
> - P1: 핵심 workflow block, 우회 경로 없음
> - P2: 우회 있음, 일부 사용자
> - P3: 미미, 드문 엣지"

**Good example:**

- 영향 받는 사용자: publisher role 전원 (~87명), TOC 생성 시도자 중 약 30%.
- 데이터 손실: 없음 (스트림 결과는 DB 저장 전 상태).
- 우회 경로: 있음: 페이지 새로고침 후 재시도.
- 심각도: **P1**: 핵심 workflow를 block하지만 우회 가능.

**Bad example:**

> 심각도: 높음. 많은 사용자에게 영향.

**Self-check:**

- [ ] 영향 사용자가 숫자로 표현됐나 (N명 또는 비율)
- [ ] 데이터 손실 여부가 Y/N로 명확한가
- [ ] 우회 경로가 기술됐나 (없으면 "없음" 명시)
- [ ] 심각도 선택이 기준에 매핑됐나

**Pushback probes:**

- "'많은 사용자'는 숫자로 바꿔주세요. 이 기능을 쓰는 사용자가 몇 명인가요?"
- "데이터 손실 여부를 Y/N으로 답해주세요. '아마도 없음'은 받지 않아요."
- "P0으로 선택하셨는데 데이터 손실도 없고 우회 경로도 있어요. P0 기준에 맞지 않으니 P1이나 P2로 내려주세요."

**Length:** 4~6줄.

**Grounding:** 사용자 수는 Projects DB 또는 운영 데이터 기반. 영향 비율은 로그 쿼리 기반이면 좋음.

## Section 5: 위치 힌트 (Localization Hints)

**이 섹션의 역할:** Bug Spec이 AI 에이전트에게 주는 가장 강력한 신호. SWE-bench `hints_text`의 인간 작성 버전. Bettenburg 2008 empirical evidence: 힌트 있는 리포트는 2x 빨리 fix됨.

**Ask (stem):**

> "다음 형식으로 2~5개 힌트를 써주세요:
>
> **의심 파일:** `경로:줄`
> **의심 근거:** 관찰된 단서 (코드에서 본 것, 로그 관찰, 실험 결과)
> **주의:** 틀릴 수 있음을 인정하는 톤으로 작성 ('아마', '먼저 확인할 곳')"

**Good example:**

- `src/features/publisher/hooks/use-toc-generation.ts:L42-L67`: useEffect cleanup에서 `controller.abort()`는 호출되지만 `setIsGenerating(false)`가 뒤따르지 않음. 이 파일이 아닐 수도 있지만 먼저 확인할 곳.
- `src/features/publisher/store.ts:L120`: Zustand `tocSlice`의 `isGenerating`이 `persist` 미들웨어에 포함되어 있다면 stale 값이 복원될 수 있음.
- 유사 과거 fix: commit `d3b7f08` (toc generation stream cancellation) 참고.

**Bad example:**

> TOC 관련 코드 어딘가. 아마 hook 문제.

**Self-check:**

- [ ] 각 힌트가 file:line 형식인가
- [ ] 의심 근거가 관찰된 단서(코드/로그)에 기반하는가
- [ ] 틀릴 수 있음을 인정하는 톤인가 (과신 금지)
- [ ] 유사 과거 fix가 있다면 commit hash로 링크했는가
- [ ] Implementation Map에서 확인한 실제 파일인가

**Pushback probes:**

- "파일만 언급하고 줄 번호가 없어요. 구체적으로 어느 함수/블록인가요?"
- "'아마 hook 문제'는 근거가 없어요. 코드를 읽고 어떤 단서를 봤는지 알려주세요."
- "이 파일이 Implementation Map에 없어요. 다시 코드를 읽을까요?"

**Length:** 2~5 bullets.

**Grounding (강제):** 모든 참조는 Implementation Map에 있어야 함. 없으면 코드 재읽기 후 보강.

## Section 6: 근본 원인 가설

**이 섹션의 역할:** 가설은 틀려도 탐색 공간을 자른다. 없으면 에이전트가 처음부터 전체 탐색. "모름"도 정직한 답.

**Ask (stem):**

> "다음을 써주세요:
>
> **가설:** 메커니즘 한 문장 (왜 이 버그가 발생하는가)
> **검증 방법:** 이 가설이 맞다면 나올 관찰 (실험으로 확인 가능한 것)
> **대안 가설:** 1개 이상 (내 가설이 틀렸을 때 다음 후보)
>
> 모르면 '가설 없음: 조사 필요'로 명시. 억지 가설 금지."

**Good example:**

- **가설:** 컴포넌트 언마운트 cleanup에서 `AbortController.abort()`는 호출되지만 React state batch 업데이트가 언마운트 중에는 적용되지 않아, 다음 마운트 시 이전 state가 stale하게 복원됨.
- **검증:** 언마운트 직전 `console.log('before abort', isGenerating)`을 추가해 값이 true인지 확인. 다음 마운트에서 초기 state가 true로 복원되면 가설 확정.
- **대안 가설:** Zustand store가 `persist` 미들웨어로 localStorage에 저장되어 stale 값이 복원되는 것일 수도 있음.

**Bad example:**

- race condition인 것 같다. (메커니즘 없음, 검증 불가)

**Self-check:**

- [ ] 가설이 한 문장 메커니즘으로 기술됐는가
- [ ] 검증 방법이 구체적 실험(log/dev tool)으로 제시됐나
- [ ] 대안 가설이 1개 이상인가
- [ ] 모르면 '가설 없음' 명시했나 (억지 금지)

**Pushback probes:**

- "'race condition'은 메커니즘이 아니에요. 무엇과 무엇의 순서가 어떻게 꼬이나요?"
- "검증 방법이 빠졌어요. 이 가설을 맞다/틀리다 어떻게 구별하나요?"
- "대안 가설이 없으면 이 가설에 과신할 위험이 있어요. 다른 후보를 적어주세요. 없으면 '대안 없음: 이 가설이 틀리면 재조사'로 명시."

**Length:** 3~6줄. 모르면 1줄.

**Grounding:** Implementation Map에서 발견한 실제 코드 패턴 기반.

## Section 7: 검증 커맨드 (FAIL→PASS / KEEP-PASSING)

**이 섹션의 역할:** SWE-bench의 FAIL_TO_PASS / PASS_TO_PASS를 저자 버전으로. AI 에이전트가 "완료"를 코드로 판정 가능.

**Ask (stem):**

> "두 가지를 써주세요:
>
> **FAIL→PASS**: 지금 실패하고 fix 후 통과해야 할 테스트/커맨드:
>
> - 자동 테스트 이름 (있으면) 또는
> - 수동 검증 절차 verbatim
> - 실제로 지금 실패하는지 본인이 확인했는가?
>
> **KEEP-PASSING**: 지금 통과하며 fix 후에도 통과해야 할 (regression 방지):
>
> - 인접 테스트 파일 또는 특정 테스트 이름
> - 너무 넓으면 cost 과대, 너무 좁으면 regression 놓침"

**Good example:**

- **FAIL→PASS:**
  - `bun run test:unit -- use-toc-generation.test.ts -t "unmount during stream resets isGenerating"`
  - 수동: 재현 절차 1~4 수행 → 4단계에서 스피너 없음 확인.
  - (확인: 현재 이 테스트 없음, fix와 함께 추가 필요)
- **KEEP-PASSING:**
  - `bun run test:unit -- use-toc-generation.test.ts` (전체, 기존 테스트 유지)
  - 수동: TOC 정상 생성 flow: 언마운트 없이 끝까지 완료되는 케이스

**Bad example:**

> 테스트 통과하면 된다.

**Self-check:**

- [ ] FAIL→PASS 테스트가 **지금 실제로 실패**하는지 확인했나 (실행해봄)
- [ ] KEEP-PASSING이 지금 통과하는지 확인했나
- [ ] 자동 테스트가 없는 영역은 수동 절차가 복붙 가능한가
- [ ] 각 명령이 한 가지만 검증하는가 (`-t` 필터 권장)

**Pushback probes:**

- "FAIL→PASS 테스트를 실행해봤나요? 지금 실패하지 않으면 이 명령은 완료 판정에 쓸모없어요."
- "KEEP-PASSING 범위가 너무 넓어요 (전체 테스트). 이 fix와 직접 관련된 모듈만 좁혀주세요."
- "수동 절차가 모호해요. 재현 절차처럼 복붙 가능한 단계로 쓸 수 있나요?"

**Length:** FAIL→PASS 1~3개, KEEP-PASSING 2~5개.

**Grounding:** Implementation Map의 인접 테스트 파일 식별. 없으면 새로 작성 필요 명시.

## Section 8: 변경하지 않을 것 (Unchanged Behavior)

**이 섹션의 역할:** Kiro Unchanged Behavior. Regression 가드 + 에이전트 과잉 수정 방지.

**Ask (stem):**

> "이 fix로 달라지면 안 되는 인접 시나리오/동작을 3~6개 나열해주세요:
>
> - 형식: '**[시나리오]**는 현재 정상이며, 이 fix 후에도 유지되어야 한다.'"

**Good example:**

- 네트워크 에러로 인한 TOC 실패 처리: 기존 toast 메시지 유지.
- TOC 생성 성공 후 결과 저장 flow: 변경 없음.
- 다른 publisher 탭 (Manuscript, Metadata)의 로딩 상태: 무관.
- TOC 취소 버튼 (정상 상태에서의 동작): 유지.

**Bad example:**

- (섹션 비움)

**Self-check:**

- [ ] fix가 건드릴 수 있는 인접 영역을 나열했나
- [ ] 각 항목이 현재 작동함을 확신하는가
- [ ] 3개 이상인가 (너무 적으면 생각 부족)

**Pushback probes:**

- "3개 미만이에요. fix가 건드릴 주변 함수/컴포넌트가 정말 없나요? Implementation Map에서 호출 체인을 다시 보세요."
- "이 항목이 현재 작동하나요? 만약 이미 깨져 있다면 별도 Request로 분리해주세요."

**Length:** 3~6 bullets.

**Grounding:** Implementation Map의 호출 체인 + 같은 파일의 다른 export.

## Final Body Format (Notion 쓰기용)

Notion Specs DB에 저장될 최종 본문. 메타 설명(이 섹션의 역할, Good/Bad, Self-check) 제거, 사용자의 실제 답변만.

```markdown
## 1. 한 줄 증상

<user input>

## 2. 재현 절차

**환경:** <user input>

**단계:**

1. …
2. …

**재현율:** <user input>

**관찰:** <user input>
**기대:** <user input>

## 3. 현재 vs 기대 동작

**Current:**

- WHEN <trigger> THEN <actual>: 에러: `…`

**Expected:**

- WHEN <trigger> THEN the system SHALL <expected>

## 4. 영향 범위 및 심각도

- **영향 사용자:** <N명 / 역할>
- **데이터 손실:** <Y/N>
- **우회 경로:** <있음/없음, 구체>
- **심각도:** P<0/1/2/3>: <근거>

## 5. 위치 힌트

- `<file:line>`: <의심 근거>
- `<file:line>`: <의심 근거>
- 유사 과거 fix: commit `<hash>`

## 6. 근본 원인 가설

**가설:** <one sentence mechanism>

**검증:** <specific experiment>

**대안 가설:** <alternative>

## 7. 검증 커맨드

**FAIL→PASS:**

- `<command>`
- 수동: <procedure>

**KEEP-PASSING:**

- `<command>`
- 수동: <procedure>

## 8. 변경하지 않을 것

- <scenario 1>
- <scenario 2>
- <scenario 3>
```
