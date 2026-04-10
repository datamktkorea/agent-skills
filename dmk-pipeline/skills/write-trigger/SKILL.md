---
name: write-trigger
description: Writes a trigger document — the first step of the development pipeline. When the user describes a situation that prompted development, determines the trigger type (Fix/Build/Improve/Strategy) and priority (P0–P3), completes a Problem Statement in the correct format, and saves the document to ~/.pipeline/docs/{project}/trigger/. Always use this skill when the user says "트리거 문서 써줘", "개발 시작 전에 정리해야 해", "왜 이 기능 만드는지 문서화해야 해", "트리거 작성", "write trigger", or wants to document why a piece of development is starting.
---

# 트리거 문서 작성 스킬

트리거 문서는 부키 개발 프로세스의 출발점이다. 개발이 시작되기 전, "왜 이 일을 하는가"를 팀이 공통 언어로 정의한다.

상세 기준과 예시는 `references/trigger-guide.md`에 있다. Problem Statement 작성 기준, 나쁜 예 / 좋은 예가 필요하면 그 파일을 참고한다.

---

## Project Detection (Autonomous)

Before doing anything else, resolve which project to use:

1. Read `~/.pipeline/config.json`.
   - If it does not exist → stop: "파이프라인 설정이 필요합니다. 먼저 `gh-pipeline-setup`을 실행해주세요."

2. Count projects in `config.projects`:
   - **1 project** → use it automatically.
   - **Multiple projects** → go to step 3.

3. Try to detect from the current git remote:
   ```bash
   gh repo view --json name -q '.name' 2>/dev/null
   ```
   Match the repo name against each project's `repos` list in the config.
   - **Match found** → confirm: "Using project `{PROJECT}` (detected from current repo). Correct?"
   - **No match** → show list and ask:
     ```
     Which project are you working on?
     1. bingbong-bookie
     2. bingbong-payments
     ```

Save the resolved `{PROJECT}` — use it as the save path base: `~/.pipeline/docs/{project}/trigger/`.

---

## 진행 순서

### Step 1 — 상황 파악

사용자에게 아래를 묻는다 (한 번에 물어봐도 된다):

1. 어떤 상황이 이 개발을 시작하게 만들었나요?
2. 누가 이 문제를 겪고 있나요? (사용자 유형, 역할)
3. 어떤 조건에서 문제가 발생하나요? (시점, 조건, 빈도)

사용자가 이미 충분한 맥락을 제공했다면 추가 질문 없이 Step 2로 넘어간다.

---

### Step 2 — 트리거 유형 결정

아래 기준으로 유형을 판단하고, 사용자에게 제안하며 확인을 받는다.

| 유형            | 판단 기준                                       |
| --------------- | ----------------------------------------------- |
| 🔴 **Fix**      | 원래 돼야 하는데 안 됨 (버그, 오류, 장애)       |
| 🟡 **Build**    | 기능 자체가 없어서 못 함 (신기능, 새 흐름)      |
| 🔵 **Improve**  | 되긴 하는데 불만족스러움 (속도, UX, 유지보수성) |
| 🟢 **Strategy** | 사용자 문제가 아닌 비즈니스/계약/규제 이유      |

두 유형이 겹쳐 보이면 더 근본적인 원인을 선택한다.

---

### Step 3 — 우선순위 결정

| 등급   | 기준                                                              |
| ------ | ----------------------------------------------------------------- |
| **P0** | 지금 이 순간 사용자가 핵심 작업을 완료할 수 없음 / 매출 직접 영향 |
| **P1** | 주요 기능 손상, 우회 방법 없거나 매우 어려움                      |
| **P2** | 불편하지만 우회 방법 존재                                         |
| **P3** | 개선하면 좋지만 지금 급하지 않음                                  |

사용자의 상황 설명을 바탕으로 등급을 제안하고 확인한다.
P0와 P1이 애매하면: "지금 이 순간 서비스를 전혀 못 쓰는 상태인가요?"라고 묻는다.

---

### Step 4 — Problem Statement 작성

**반드시 이 형식을 지킨다:**

```
[누가] [어떤 상황에서] [무엇이] 안 된다
```

**검증 체크리스트 (3가지 모두 통과해야 완료):**

- [ ] 누가: 역할이나 사용자 유형이 명시되어 있다
- [ ] 어떤 상황에서: 시점, 조건, 트리거가 측정 가능하게 표현되어 있다
- [ ] 무엇이 안 된다: 증상이 관찰 가능한 수준으로 구체적이다

**사용 금지 표현:** 가끔, 종종, 자주, 느리다, 이상하다, 불편하다
→ 시점·조건·횟수·수치로 대체한다

초안을 작성한 뒤 사용자에게 보여주고 수정 여부를 확인한다.
3가지 체크리스트 중 하나라도 미흡하면 구체화 질문을 추가로 한다.

---

### Step 5 — 트리거 문서 생성 및 저장

확인이 완료되면 아래 형식으로 마크다운 문서를 작성하고, 파일로 저장한다.

**파일명 규칙:** `~/.pipeline/docs/{project}/trigger/YYYYMMDD-{kebab-case-feature-name}.md`

- 예: `~/.pipeline/docs/bookie/trigger/20260410-search-result-rendering.md`
- `{project}`는 `~/.pipeline/config.json`의 `project` 값을 읽어서 사용한다.
- config.json이 없으면 사용자에게 묻는다: "프로젝트 이름을 입력해주세요 (예: bookie):"
- 디렉토리가 없으면 자동으로 생성한다. 사용자에게 확인을 구하지 않는다.

```markdown
# 트리거 문서

| 항목        | 내용                                         |
| ----------- | -------------------------------------------- |
| 작성일      | YYYY-MM-DD                                   |
| 작성자      | (사용자가 밝힌 경우 기입, 아니면 공란)       |
| 트리거 유형 | 🔴 Fix / 🟡 Build / 🔵 Improve / 🟢 Strategy |
| 우선순위    | P0 / P1 / P2 / P3                            |
| 발신자      | 고객 / 내부 팀 / 경영진 / 모니터링 시스템    |

## Problem Statement

[누가] [어떤 상황에서] [무엇이] 안 된다

## 배경 및 맥락

(문제가 발생한 경위, 언제부터, 어떤 조건에서 — 사용자 설명 기반으로 작성)

## 기대 결과

이 문제가 해결되면 어떤 상태여야 하는가

## 참고 자료

(스크린샷, 로그, 관련 이슈 링크 — 있으면 기입, 없으면 삭제)
```

파일 저장 후 사용자에게 저장된 경로를 알려준다.

---

## 주의사항

- **발신자 ≠ 트리거 유형.** 고객이 말했더라도 실제 성격이 Fix면 Fix다.
- **Problem Statement는 해결책을 담지 않는다.** "~기능을 추가한다"가 아니라 "~이 안 된다"로 끝난다.
- **"기대 결과"도 해결책이 아니다.** "사용자가 업로드 후 완료 여부를 새로고침 없이 확인할 수 있다"처럼 상태를 서술한다.
- Problem Statement가 완성되기 전까지는 문서를 최종 생성하지 않는다.
