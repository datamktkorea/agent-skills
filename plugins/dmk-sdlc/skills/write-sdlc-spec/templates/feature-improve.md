---
category: feature-improve
handles_request_type: 기능 개선
section_count: 6
---

# Template: 기능 개선 (Feature Improvement Spec)

A feature-improvement is metric-bound ("X from A to B"). The baseline-target axis dominates: other sections are tight. Modeled on Microsoft Trustworthy Online Experiments (Kohavi), Booking.com experimentation framework, Google SRE toil-reduction, Web Vitals remediation, and Christina Wodtke's OKR "A to B" format.

**Grounding mandate:** Sections 2, 3, 4 MUST cite real measurements (dashboard URL, log queries, code benchmarks, commit hashes). No baseline = no improvement, just speculation.

> **Note on examples.** All Good/Bad examples below are drawn from a single illustrative project (a book-publishing agent called BINGBONG: roles like `publisher`, features like TOC generation, file paths like `src/features/publisher/...`). They exist to show shape, not content. When running the skill, substitute actual identifiers from the user's Request, Projects DB, and `code.json`. Never reproduce these example identifiers in the user-facing prompt or the Spec body.

## Sections (in order)

1. 개선 한 줄 (Improvement Line, "X from A to B")
2. 현재 baseline 증거 (Baseline Evidence)
3. 원인 귀속 (Attribution)
4. 개선 메커니즘 및 예측 효과 (Mechanism & Expected Impact)
5. Guardrail Metrics (부작용 방지 지표)
6. 검증 및 측정 방법 (Verification & Measurement)

## Section 1: 개선 한 줄 ("X from A to B")

**이 섹션의 역할:** OKR key-result 문법 강제. baseline → target → 기한 → 메커니즘 한 구절.

**Ask (stem):**

> "다음 형식으로 써주세요:
>
> **[metric 이름]**을 **[현재값 A]**에서 **[목표값 B]**로, **[기한]**까지 개선한다.
> 방법: **[핵심 메커니즘 한 구절]**."

**Good example:**

> TOC 생성 p75 latency를 현재 18.4초에서 8초 이하로, 2026-06-30까지 개선한다.
> 방법: FastAPI 쪽 프롬프트 청킹 + 프론트 스트림 buffer 제거.

**Bad example:**

> TOC 생성 속도 개선. / 더 빠르게.

**Self-check:**

- [ ] metric 이름이 기존 대시보드/로그에 실제로 존재하나
- [ ] A가 측정된 값인가 (추측 아닌)
- [ ] B가 A와 같은 단위인가 (예: p75 초)
- [ ] 기한이 년-월-일 또는 분기까지 구체적인가
- [ ] 메커니즘 한 구절이 명시됐나

**Pushback probes:**

- "'빠르게'는 metric이 아니에요. p75 latency인가요? average인가요? error rate인가요?"
- "A값이 어디서 나온 거예요? 대시보드 보고 적은 건가요, 감으로 적은 건가요?"
- "기한이 '이번 분기'면 모호해요. 어느 분기 마지막 날까지?"

**Length:** 1~2 문장.

## Section 2: 현재 baseline 증거

**이 섹션의 역할:** Google SRE / Web Vitals 원칙: 숫자 없는 개선은 이론. 측정 출처·기간·샘플·분포 전부 필요.

**Ask (stem):**

> "다음을 써주세요:
>
> **baseline 값:** (Section 1의 A와 동일)
> **출처:** 대시보드 URL / 로그 쿼리 / 코드 benchmark
> **측정 기간:** YYYY-MM-DD ~ YYYY-MM-DD
> **샘플 크기:** N
> **분포:** p50 / p75 / p95 / max 등 관심 지표
> **변동성:** 최근 6주 추세: 안정 / 악화 중 / 개선 중"

**Good example:**

- **baseline p75:** 18.4초
- **출처:** Supabase logs `toc_generation_events` 테이블, 쿼리: `select percentile_cont(0.75) ... where event = 'complete'`. (대시보드 링크: …)
- **기간:** 2026-03-01 ~ 2026-04-15 (6주)
- **샘플:** N=1,247
- **분포:** p50 12.1s, p75 18.4s, p95 34.2s, max 87s. 최악 5% 케이스는 원고 100페이지 이상.
- **변동성:** 최근 6주 p75 16.8s → 18.4s로 약간 악화 중 (페이지 평균 길이 증가 추정).

**Bad example:**

> 느리다는 피드백이 많다.

**Self-check:**

- [ ] 데이터 출처가 링크 or 쿼리로 있나
- [ ] 샘플 크기가 있나 (너무 작으면 통계적 의미 없음)
- [ ] 관심 지표 (p75 등)가 Section 1과 동일한가
- [ ] 측정 기간이 구체적인가
- [ ] 변동성 추세가 언급됐나

**Pushback probes:**

- "'피드백이 많다'는 측정이 아니에요. 몇 건인지 + 언제인지 말해주세요."
- "샘플이 너무 작아요 (N=20). 결과의 통계적 신뢰가 부족해요. 측정 기간을 늘리거나 더 많은 사용자 샘플을 확보할 수 있나요?"
- "p50만 있고 p95가 없어요. 개선 대상이 어느 분위인지 명확히 해주세요 (보통 p75 또는 p95)."

**Length:** 5~8줄.

## Section 3: 원인 귀속 (Attribution)

**이 섹션의 역할:** Web Vitals / Lighthouse: "뭐가 느린지 이름 대지 않으면 고칠 수 없다". 주요 비용 구간을 % 또는 절대값으로 구분.

**Ask (stem):**

> "다음을 써주세요:
>
> **주요 비용 구간:** baseline의 어디가 비용의 가장 큰 부분인가? % 또는 절대값
> **증거:** 어떻게 측정했나? profile / trace / server log / RUM
> **배제한 후보:** 다른 의심 후보는? 왜 주범이 아니라고 판단했나?"

**Good example:**

- **주요 비용:** 18.4초 중 평균 14.2초 (77%)는 FastAPI `/toc/generate`의 LLM 호출 대기.
- **증거:** Supabase logs의 `request_id`별 구간 로그. `llm_start` ~ `llm_end` 평균 14.2s (N=1,247).
- **프론트 스트림 처리:** 평균 0.8초 (4%): 큰 비중 아님.
- **네트워크 latency:** 중앙값 ~200ms.
- **배제한 후보:**
  - 프론트 렌더링: dev tool profile 측정 결과 렌더링 구간 평균 30ms. 주범 아님.
  - DB 쿼리: 호출 1회, 평균 80ms. 주범 아님.
- **결론:** LLM 호출이 주요 비용 (77%). 여기를 줄여야 목표 달성 가능.

**Bad example:**

> 전반적으로 느리다.

**Self-check:**

- [ ] 주요 비용이 % 또는 절대값으로 표현됐나
- [ ] 측정 방법이 링크/쿼리로 citation됐나
- [ ] 다른 의심 후보가 명시적으로 배제됐나 (배제 근거 포함)
- [ ] 결론이 Section 4의 메커니즘과 정합하는가

**Pushback probes:**

- "'전반적으로'는 attribution이 아니에요. 어느 구간이 몇 %인가요?"
- "LLM이 느리다고 단정했는데 측정 데이터가 없어요. trace 또는 로그로 입증할 수 있나요?"
- "다른 후보를 배제하지 않았어요. 렌더링이 느린 가능성은요? 네트워크는요? 배제 근거가 없으면 Section 4 메커니즘이 엉뚱한 곳을 건드릴 위험이 있어요."

**Length:** 5~10줄.

## Section 4: 개선 메커니즘 및 예측 효과

**이 섹션의 역할:** 베팅 명시. Microsoft MDE (minimum detectable effect): 예측 효과를 수식/추정으로.

**Ask (stem):**

> "다음을 써주세요:
>
> **메커니즘:** 구체적으로 무엇을 변경하는가 (코드 수준)
> **예측 효과:** 이 변경이 baseline에 수식/추정으로 얼마나 영향?
> **불확실성:** 예측이 틀릴 수 있는 지점
> **합계:** 여러 메커니즘이면 총합이 목표 B에 도달하는지 계산"

**Good example:**

- **메커니즘 1:** FastAPI 프롬프트를 섹션 단위로 청킹해 LLM을 병렬 호출 (현재 직렬).
  - 파일: `src/publisher/services/toc_service.py:L42-L80`
  - 예측: 14.2s × 1/병렬도 ≈ 14.2s × 0.4 = 5.7s (병렬도 2.5 가정)
  - 불확실성: 실제 병렬도는 LLM provider rate limit 의존. 최악 시 gain 없음.
- **메커니즘 2:** 프론트 스트림 buffer 제거 (현재 1초 flush interval → 즉시 flush).
  - 파일: `src/features/publisher/hooks/use-toc-generation.ts:L55`
  - 예측: 0.8s → 0.3s, gain 0.5s
- **합계 예측:** 14.2 + 0.8 = 15.0s → 5.7 + 0.3 = 6.0s.
- **목표 B (8s) 도달:** 합계 예측 6.0s + 기타 구간 4.2s = 10.2s. 목표 초과 가능성 있음: 메커니즘 1의 병렬도가 실제 2.5 이상 나와야 8s 이하.
- **백업 메커니즘:** 병렬도가 예측보다 낮으면 캐시 레이어 추가 (파일: `src/publisher/cache/`): 예측 gain 1~2s 추가.

**Bad example:**

> 더 빠르게 만든다.

**Self-check:**

- [ ] 변경이 실행 가능한 구체 수준인가 (파일:줄)
- [ ] 예측이 수식/추정으로 도출됐나
- [ ] 불확실성을 인정하나
- [ ] 합계 예측이 목표 B에 도달하나 (안 하면 메커니즘 부족)
- [ ] 목표 미달 시 백업 메커니즘이 있나

**Pushback probes:**

- "예측이 '많이 빨라진다'면 측정 불가. 숫자로 추정해주세요."
- "합계 예측이 13s인데 목표는 8s예요. 메커니즘이 부족해요. 다른 구간을 더 줄이거나 목표를 현실적으로 조정해주세요."
- "불확실성을 인정 안 했어요. 예측이 무조건 맞을 거라고 보는 건 위험해요. 가장 큰 불확실성이 뭔가요?"

**Length:** 6~12줄.

**Grounding:** Implementation Map의 hot-path 파일.

## Section 5: Guardrail Metrics

**이 섹션의 역할:** Booking.com / Microsoft: 주 지표만 보면 부작용을 놓친다. 속도 개선이 품질/비용/안정성을 깎는 함정.

**Ask (stem):**

> "개선하는 과정에서 나빠지면 안 되는 지표 3~5개를 써주세요.
>
> 각 항목: **[지표] ≥/≤ [임계치]**: 악화 시 **[롤백/재검토/조사]**
>
> 반드시 포함:
>
> - 품질 지표 (속도 개선이 품질을 깎는 함정)
> - 비용 지표 (속도 개선이 cost를 올릴 수 있음)
> - 안정성 지표 (에러율 등)"

**Good example:**

- **TOC 생성 성공률:** ≥ 98% (현재 98.7%). 97% 이하 시 즉시 **롤백**.
- **LLM 비용 per 요청:** ≤ +10% (병렬화로 token 중복 우려). +15% 초과 시 **재검토** (프롬프트 최적화).
- **결과 품질 주관 평가:** publisher 피드백 "좋음" 비율 ≥ 현재 수준 (월간 설문). 10%p 이상 감소 시 **조사**.
- **에러 로그 발생률:** ≤ baseline (AbortError 등 제외). 2배 초과 시 **롤백**.

**Bad example:**

> (섹션 생략)

**Self-check:**

- [ ] 3~5개인가
- [ ] 각 항목에 수치 임계치가 있나
- [ ] 악화 시 행동(롤백/재검토/조사)이 명시됐나
- [ ] 품질 guardrail이 있나 (속도 개선이 품질 깎는 함정 방지)
- [ ] 비용 guardrail이 있나 (해당되면)

**Pushback probes:**

- "품질 guardrail이 없어요. LLM 병렬화로 prompt가 짧아지면 품질이 떨어질 수 있어요. 어떻게 감지하죠?"
- "'나빠지면 재검토'는 구체적이지 않아요. 어떤 숫자가 어떤 값 넘으면 정확히 무엇을 하죠?"

**Length:** 3~5 bullets.

## Section 6: 검증 및 측정 방법

**이 섹션의 역할:** 출시 후 실제로 목표 달성했는지 측정. baseline과 동일 방법이어야 사과-대-사과 비교.

**Ask (stem):**

> "다음을 써주세요:
>
> **측정 방법:** Section 2의 baseline 측정과 **완전히 동일한** 쿼리/대시보드 재실행
> **측정 기간:** 배포 후 N일
> **샘플 크기 목표:** N ≥ ?
> **결과별 결정:** target B 이하 → ?, target B 근접 → ?, 악화 → ?"

**Good example:**

- **측정 방법:** Section 2와 동일한 Supabase 쿼리. `toc_generation_events` 테이블, p75 계산.
- **측정 기간:** 100% 배포 후 7일 관측.
- **샘플 목표:** N ≥ 500 (현재 추세로 7일이면 확보).
- **결과별 결정:**
  - p75 ≤ 8s (목표 달성) → **완료** 선언 + flag 제거 2주 후
  - p75 8~12s (부분 달성) → **메커니즘 재검토**: 백업 메커니즘(캐시) 시도
  - p75 > 12s (실패) → **롤백** + 원인 조사

**Bad example:**

> 빨라졌는지 확인한다.

**Self-check:**

- [ ] 측정 방법이 baseline과 완전히 동일한가 (다르면 비교 의미 없음)
- [ ] 샘플 크기 목표가 있나
- [ ] 결과별 결정이 미리 정의됐나 (3가지 경우)
- [ ] Guardrail (Section 5) 확인도 포함되는가

**Pushback probes:**

- "측정 방법이 baseline과 달라요. p75 vs p95가 섞여있어요. 어느 쪽으로 통일하나요?"
- "결과별 결정이 1가지 밖에 없어요. 부분 달성이면요? 실패면요?"
- "Guardrail도 함께 측정해야 해요. Section 5 지표들도 동시에 추적하나요?"

**Length:** 4~6줄.

## Final Body Format (Notion 쓰기용)

```markdown
## 1. 개선 한 줄

<metric>을 <A>에서 <B>로, <deadline>까지. 방법: <mechanism>.

## 2. Baseline 증거

- **값:** <A> (p75)
- **출처:** <dashboard link / SQL / benchmark>
- **기간:** <YYYY-MM-DD ~ YYYY-MM-DD>
- **샘플:** N=<...>
- **분포:** p50 / p75 / p95 / max
- **변동성:** <trend>

## 3. 원인 귀속

- **주요 비용:** <%>: <구간>: <증거>
- **기타 구간:** <percentages>
- **배제한 후보:** <X>: <배제 근거>
- **결론:** <...>

## 4. 개선 메커니즘 및 예측

**메커니즘 1:** <what> (파일: `<file:line>`)

- 예측: <formula or estimate>
- 불확실성: <...>

**메커니즘 2:** ...

**합계 예측:** <A'> (vs target B)

**백업 메커니즘 (필요 시):** <...>

## 5. Guardrail Metrics

- **<지표>:** <op> <threshold>: 악화 시 <action>
- **<지표>:** ...
- **<지표>:** ...

## 6. 검증 및 측정 방법

- **방법:** <query/dashboard: same as Section 2>
- **기간:** 배포 후 <N>일
- **샘플 목표:** N ≥ <...>
- **결과별 결정:**
  - 달성: <...>
  - 부분 달성: <...>
  - 실패: <...>
```
