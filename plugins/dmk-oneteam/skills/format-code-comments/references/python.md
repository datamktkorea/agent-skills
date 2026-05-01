# Python Comment Conventions

All comments produced by the format-code-comments skill must be written in Korean.
Technical terms (token, None, API, Redis, etc.) may remain in English within Korean sentences.

---

## Documentation Comments: Google Style Docstring

Use Google Style docstrings for Python files. This style is indentation-based,
more readable than NumPy or Sphinx styles, and integrates well with type hints.

### Basic format

```python
def get_user_by_email(email: str, include_deleted: bool = False) -> User | None:
    """이메일로 사용자를 조회한다.

    삭제된 계정은 기본적으로 제외하며, include_deleted 플래그로 포함 여부를 제어한다.

    Args:
        email: 조회할 사용자의 이메일 주소.
        include_deleted: True면 소프트 삭제된 계정도 포함한다.

    Returns:
        일치하는 사용자 객체. 존재하지 않으면 None.

    Raises:
        ValueError: 이메일 형식이 유효하지 않을 때.
        DatabaseError: DB 연결에 실패했을 때.
    """
```

### Generator functions

For functions that `yield` values, use `Yields` instead of `Returns`. This is a Google Style requirement.

```python
def stream_users_by_role(role: Role) -> Iterator[User]:
    """지정된 권한을 가진 사용자를 스트리밍한다.

    DB 커서 기반 lazy 조회로, 대량 데이터에서도 메모리를 일정하게 유지한다.

    Args:
        role: 조회 대상 권한.

    Yields:
        조건에 일치하는 사용자 객체. 매칭되는 사용자가 없으면 아무것도 yield하지 않는다.

    Raises:
        DatabaseError: DB 커넥션 끊김 등 조회 실패 시.
    """
```

### Section usage guide

| Section      | When to use                                                                                                                   |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------- |
| `Args`       | Whenever the function has one or more parameters                                                                              |
| `Returns`    | When the return value has meaning beyond its type (document `None` possibility). Use this for regular functions only.         |
| `Yields`     | For **generator functions** — use `Yields` instead of `Returns`. Required by Google Style for any function that uses `yield`. |
| `Raises`     | Whenever the function can raise — always document this                                                                        |
| `Example`    | When a usage example aids understanding (`Examples` is also accepted)                                                         |
| `Note`       | Important caveats the caller must know (`Notes` is also accepted)                                                             |
| `Attributes` | When documenting class attributes                                                                                             |

### One-line summary

- The summary line ends with a period and is short enough to fit on one line.
- **Team convention**: prefer the descriptive plain form (`-한다`) for the Korean summary,
  which maps naturally to PEP 257's English imperative ("Do this"). Both PEP 257 (imperative)
  and Google Style (imperative or descriptive — pick one and be consistent within a file)
  permit this; we pick the descriptive form for readability in Korean.
- Follow with a blank line and an extended description only when needed.

```python
def send_verification_email(user_id: str) -> bool:
    """이메일 인증 메일을 발송한다."""
```

### Multi-line docstring layout (PEP 257)

PEP 257 fixes the structure of multi-line docstrings — these rules are non-negotiable
because tooling (sphinx, pydoc, IDEs) depends on them.

1. **Opening `"""` on the same line as the summary.** The summary text starts immediately
   after the opening triple-quote.
2. **Blank line between the summary and the elaboration.** This is what tools use to
   distinguish the one-line "tooltip" from the longer description.
3. **Closing `"""` on its own line** for any docstring that spans more than one line.
   For single-line docstrings, the closing `"""` stays on the same line.

```python
# Correct — multi-line docstring
def reconcile_balance(account_id: str, snapshot_at: datetime) -> Reconciliation:
    """계좌 잔액을 외부 원장과 대조한다.

    스냅샷 시점 기준으로 내부 기록과 외부 원장의 차이를 계산하고,
    오차 임계치를 넘으면 알림을 발송한다.

    Args:
        account_id: 대조할 계좌의 고유 ID.
        snapshot_at: 대조 기준 시각.

    Returns:
        대조 결과 객체.
    """

# Correct — single-line docstring stays on one line
def is_active(self) -> bool:
    """계정이 활성 상태인지 확인한다."""

# Wrong — closing quotes on the same line as the last text
def wrong_example():
    """이렇게 닫으면 안 된다.

    여러 줄임에도 닫는 따옴표가 본문 옆에 붙어 있다."""

# Wrong — missing blank line between summary and body
def also_wrong():
    """요약 라인입니다.
    이 줄은 빈 줄 없이 본문이 시작되어 PEP 257에 어긋난다.
    """
```

### Module-level docstrings

Per Google Style, every module (`.py` file) intended for import should open with a
module-level docstring describing what the module provides. Place it at the very top,
before any imports.

```python
"""사용자 인증 관련 토큰의 생성, 검증, 갱신 로직을 제공한다.

이 모듈은 JWT 발급, Redis 기반 세션 저장, 리프레시 토큰 회전을 담당한다.
DB 모델은 다루지 않으며, 모델 계층은 ``users.models``를 참고한다.
"""

from __future__ import annotations

import jwt
...
```

### When to add a docstring

**Always add when:**

- A module is defined (top-of-file docstring describing what the module provides)
- The function or method is public (not prefixed with `_`)
- The function has 2 or more parameters
- The return type is complex or conditional (e.g., `X | None`)
- The function can raise an exception
- A class is defined

**Consider adding when:**

- A `_`-prefixed internal function has complex logic
- Parameter meaning is ambiguous from the name alone

**Skip when:**

- The function name alone makes the behavior fully self-explanatory
- Simple property getter with no side effects

### Class documentation

```python
class TokenRepository:
    """JWT 토큰의 저장 및 조회를 담당하는 저장소.

    Redis를 백엔드로 사용하며, 토큰 만료 시 자동으로 삭제된다.

    Attributes:
        ttl: 액세스 토큰의 유효 시간 (초).
        redis: Redis 클라이언트 인스턴스.
    """

    def save(self, token: str, user_id: str) -> None:
        """토큰을 Redis에 저장한다.

        Args:
            token: 저장할 JWT 문자열.
            user_id: 토큰 소유자의 사용자 ID.
        """
```

### Type hints and docstrings

**Team convention**: when type hints are present in the function signature, do not
repeat the type inside the docstring `Args` — use the parameter name only.

Note that this is a project rule, not Google's official position. Google Style
permits both forms (`name (type):` and `name:`); tools like `sphinx-napoleon` and
`pylint` accept either. We standardize on the no-type form because the signature
is already authoritative — duplicating the type creates two places that can drift.

If a function intentionally lacks type hints (e.g., heavily dynamic code), include
the type in the docstring using `name (type):`.

```python
# Preferred — type is in the signature, not repeated in the docstring
def create_user(email: str, role: Role) -> User:
    """사용자를 생성한다.

    Args:
        email: 신규 사용자의 이메일 주소.
        role: 부여할 권한 등급.
    """

# Avoid — type repeated unnecessarily when signature already has it
    """
    Args:
        email (str): 이메일 주소.
    """

# Acceptable — function lacks type hints, so docstring carries the type
def legacy_handler(payload):
    """레거시 페이로드를 처리한다.

    Args:
        payload (dict): 외부 시스템에서 전달되는 raw 페이로드.
    """
```

---

## Inline Comments: `#`

### Core principle

Inline comments explain **why** the code is written this way — the reasoning that cannot
be inferred from reading the code alone. Never restate what the code already shows.

**Good examples:**

```python
# 동시 요청 경쟁 조건 방지: DB 저장 전 메모리 캐시 먼저 무효화
cache.delete(user_id)
db.save(user)

# Python 3.9 미만 호환성 유지를 위해 | 연산자 미사용
merged = {**defaults, **overrides}

# 최대 재시도 횟수 초과 시 알림 발송 후 작업 중단
if attempt >= MAX_RETRIES:
    notify_ops_team(task_id)
    raise RetryExhaustedError(task_id)
```

**Bad example (restates the code):**

```python
# attempt가 MAX_RETRIES 이상이면
if attempt >= MAX_RETRIES:
```

### Placement and PEP 8 formatting rules

PEP 8 fixes the mechanics of inline comments:

- **Use sparingly.** Inline comments interrupt reading; lean toward block comments above
  the relevant code, and only use end-of-line comments for short, supplementary notes.
- **Two spaces before the `#`** for trailing inline comments.
- **Single space after the `#`** before the comment text.
- **Capitalize the first letter** of the comment when it forms a sentence — except when
  the first word is an identifier that is lowercase in code.

The Korean comments produced by this skill follow the same spacing rules. Korean has no
"capitalization", but the equivalent quality bar — write a complete, readable sentence —
applies.

```python
# 캐시 미스 시 DB에서 직접 조회
user = db.find_user(user_id)

MAX_RETRY = 3  # 외부 설정 없이 고정값 사용
```

---

## Section Comments

Use to visually separate distinct logical blocks within a long function or module.
Only add when the length genuinely benefits from separation. Most well-written
functions don't need them — prefer extracting helper functions before reaching
for section markers.

### Default style: plain header + blank lines

This is the dominant pattern in CPython, Django, FastAPI and most mainstream Python
projects. PEP 8 endorses extra blank lines for separating groups of related code.
A single-line comment header followed by a blank line is enough.

```python
# 입력 정규화

raw = payload.strip()
parsed = json.loads(raw)

# 중복 여부 확인

if repository.exists(parsed["id"]):
    raise DuplicateError(parsed["id"])

# 결과 저장

repository.save(parsed)
```

### Optional: ASCII rule for visually heavier separation

When a single header isn't strong enough — for example, in a long module with
several distinct phases — a short ASCII rule is portable, greppable, and
recognized.

```python
# ---------- 유효성 검사 ----------

...

# ---------- DB 저장 ----------

...
```

### Optional: VS Code folding regions

If the team relies on collapsible sections in VS Code, use `# region` / `# endregion`
markers. Treat this as an editor aid, not a structural convention — overuse signals
that the function or module should be split instead.

```python
# region 유효성 검사
...
# endregion

# region DB 저장
...
# endregion
```

### Avoid

- **Unicode box-drawing characters** (`──`, `═`, `│`, etc.) as section dividers.
  They aren't part of any standard style guide, render inconsistently across diff
  viewers and fonts, and tend to read as personal aesthetic rather than team
  convention.
- **Long banners of `#` characters** (`############`) as decoration. PEP 8 doesn't
  forbid them, but they add noise without conveying information that a plain
  header doesn't already provide.

---

## Existing Comment Quality Review

Flag for update or removal when any of the following apply:

1. **Stale content** — the docstring describes logic that no longer exists after the change
2. **WHAT repetition** — the comment restates what the code already shows
3. **Non-Korean** — team standard is Korean; technical terms may stay in English
4. **Too vague** — phrases like "처리한다" or "반환한다" with no meaningful context
5. **Missing `Raises`** — the function raises but has no `Raises` section
6. **Missing `Args` / `Returns`** — public functions with undocumented parameters
7. **Wrong section for generators** — generator function uses `Returns` instead of `Yields`
8. **Type duplication** — type is already in the signature but repeated in the docstring (`email (str):` → `email:`)
9. **PEP 257 layout violations** — closing `"""` on the same line as text in a multi-line docstring, or missing blank line between summary and elaboration
10. **Missing module docstring** — importable module without a top-of-file docstring
11. **PEP 8 inline comment violations** — fewer than two spaces before `#`, missing space after `#`
