# TypeScript / JavaScript Comment Conventions

All comments produced by the format-code-comments skill must be written in Korean.
Technical terms (token, null, API, Promise, etc.) may remain in English within Korean sentences.

---

## Documentation Comments: TSDoc

Use TSDoc format for TypeScript files. TSDoc is a superset of JSDoc that integrates
with TypeScript's type system and powers IDE autocompletion.

### Basic format

```ts
/**
 * 한 줄 요약 설명.
 *
 * 필요하면 더 자세한 설명을 여기에 작성한다.
 * 여러 줄도 가능하다.
 *
 * @param userId - 조회할 사용자의 고유 식별자
 * @param options - 조회 옵션 (페이지네이션, 필터 등)
 * @returns 사용자 정보 객체. 존재하지 않으면 null 반환
 * @throws {NotFoundError} 사용자가 데이터베이스에 없을 때
 * @throws {UnauthorizedError} 접근 권한이 없을 때
 */
async function getUserById(userId: string, options?: QueryOptions): Promise<User | null> {
```

### Tag usage guide

| Tag                                              | When to use                                                                                                                                                                     |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `@param`                                         | Add when the parameter's meaning isn't obvious from name and type alone. For exported APIs, document every parameter; for internal helpers, document only the non-obvious ones. |
| `@typeParam`                                     | Every generic type parameter on functions, classes, and types — describe the type's role                                                                                        |
| `@returns`                                       | When the return value has meaning beyond its type                                                                                                                               |
| `@throws`                                        | Whenever the function can throw — always document this                                                                                                                          |
| `@defaultValue`                                  | Default value of an optional property or parameter (especially in interfaces and option objects)                                                                                |
| `@see`                                           | Cross-reference to a related symbol, doc, or URL                                                                                                                                |
| `{@link Symbol}`                                 | Inline link to another API item — renders as a clickable reference in IDE tooltips and generated docs                                                                           |
| `@remarks`                                       | Additional caveats or background context that doesn't fit in the summary                                                                                                        |
| `@example`                                       | When a usage example aids understanding                                                                                                                                         |
| `@deprecated`                                    | Functions or methods that should no longer be used (state replacement when possible)                                                                                            |
| `@public` / `@beta` / `@alpha` / `@experimental` | Release-stage modifiers — declare API stability for consumers (stable / opt-in preview / unstable preview / experimental)                                                       |
| `@internal`                                      | Marks non-public implementation details that should not be considered part of the API                                                                                           |

### When to add TSDoc

**Always add when:**

- The function, class, interface, or type is `export`ed
- The function has 3 or more parameters
- The return type is complex or conditional
- The function can throw
- It is an async function with failure scenarios

**Consider adding when:**

- An internal function has complex logic
- Parameter meaning is ambiguous from the type alone

**Skip when:**

- The name and types make the function fully self-explanatory
- Simple getter/setter with no side effects

### Class documentation

```ts
/**
 * JWT 기반 인증 토큰을 관리한다.
 *
 * 액세스 토큰과 리프레시 토큰의 생성, 검증, 갱신을 담당한다.
 * 토큰은 Redis에 저장되며 만료 시 자동으로 제거된다.
 */
export class TokenService {
  /**
   * 새 액세스 토큰을 발급한다.
   *
   * @param payload - 토큰에 포함할 사용자 정보
   * @returns 서명된 JWT 문자열
   */
  issue(payload: TokenPayload): string {
```

### Generic type parameters

Use `@typeParam` for every generic type parameter. The role of `T` or `K` is rarely
obvious from the letter alone, so describing intent is essential.

```ts
/**
 * 캐시에서 값을 조회하거나, 없으면 fetcher로 가져와 저장한다.
 *
 * @typeParam K - 캐시 키 타입. 문자열 또는 직렬화 가능한 객체.
 * @typeParam V - 캐시 값 타입. JSON 직렬화가 가능해야 한다.
 * @param key - 조회할 키
 * @param fetcher - 캐시 미스 시 값을 새로 가져올 함수
 * @returns 캐시된 값 또는 fetcher가 반환한 값
 */
async function getOrSet<K, V>(key: K, fetcher: () => Promise<V>): Promise<V> {
```

### Cross-references with `@see` and `{@link}`

Use `@see` as a block tag for general references. Use `{@link Symbol}` inline within
prose to link to another API item — IDEs render it as a clickable cursor target.

```ts
/**
 * 신규 사용자를 등록한다.
 *
 * 이메일 검증을 통과한 후에만 영속 저장된다.
 * 검증 흐름의 세부 사항은 {@link verifyEmailToken}을 참고한다.
 *
 * @param input - 사용자 입력 (이메일, 비밀번호 등)
 * @see https://internal.example.com/docs/auth-flow
 */
function registerUser(input: RegisterInput): Promise<User> {
```

### Default values with `@defaultValue`

Document defaults explicitly on optional properties and parameters. Pair with
`@param` when the default isn't obvious from the signature.

```ts
interface PaginationOptions {
  /**
   * 한 페이지당 결과 개수.
   *
   * @defaultValue 20
   */
  pageSize?: number;

  /**
   * 0-based 페이지 인덱스.
   *
   * @defaultValue 0
   */
  page?: number;
}
```

### API stability with release-stage modifiers

For libraries or packages with external consumers, declare the stability of each
exported API. The four standard TSDoc modifiers form a stability spectrum:

| Modifier        | Meaning                                                                  |
| --------------- | ------------------------------------------------------------------------ |
| `@public`       | Stable, supported API. Breaking changes follow semver major.             |
| `@beta`         | Available for opt-in preview; API may change before stable release.      |
| `@alpha`        | Early preview; expect frequent breaking changes.                         |
| `@experimental` | Synonym used in some toolchains for `@alpha`/`@beta`-like preview state. |
| `@internal`     | Not part of the public API at all — implementation detail.               |

Place the modifier as a single tag in the doc comment.

```ts
/**
 * 사용자 활동 로그를 외부 분석 시스템에 전송한다.
 *
 * 새 백엔드(v2)로 전환 중인 동안 동작이 바뀔 수 있으므로 `@beta`로 표기한다.
 * 안정화되면 `@public`으로 승격한다.
 *
 * @param event - 전송할 활동 이벤트
 * @beta
 */
export function sendActivityEvent(event: ActivityEvent): Promise<void> {

/**
 * 내부 캐시 키 직렬화 헬퍼.
 *
 * 호출자는 외부에서 직접 사용하지 말 것. 다음 메이저 버전에서 시그니처가
 * 변경될 수 있다.
 *
 * @internal
 */
export function _serializeCacheKey(key: unknown): string {
```

For application code without external consumers, these modifiers usually aren't
needed — `@internal` alone is enough to signal "not part of the surface area."

---

## Inline Comments: `//`

### Core principle

Inline comments explain **why** the code is written this way — the reasoning that cannot
be inferred from reading the code alone. Never restate what the code already shows.

**Good examples:**

```ts
// 재시도 3회 초과 시 세션 전체를 무효화해 보안 위협 차단
if (retryCount > 3) {
  await this.invalidateSession(userId);
}

// IE11 호환성 문제로 Array.from 대신 spread 사용
const items = [...nodeList];

// 소수점 이하 버림: 픽셀 단위라 정수만 유효
const width = Math.floor(containerWidth / columns);
```

**Bad example (restates the code):**

```ts
// retryCount가 3보다 크면
if (retryCount > 3) {
```

### Placement

Prefer a standalone line above the relevant code. Trailing end-of-line comments are
acceptable only for short supplementary notes.

```ts
// 캐시 미스 시 DB에서 직접 조회
const user = await db.findUser(id);

const MAX_RETRY = 3; // 외부 설정 없이 고정값 사용
```

---

## Section Comments

Use to visually separate distinct logical blocks within a long file or function.
Only add when the length genuinely benefits from separation. In most cases,
extracting a helper function or splitting the file is a better answer than adding
section markers.

### Default style: plain header + blank lines

This is the pattern used in the TypeScript compiler, React, VS Code, and most
mainstream JS/TS projects. A single-line comment header followed by a blank line
is enough.

```ts
// 유효성 검사

const parsed = parseInput(raw);
assertSchema(parsed);

// DB 저장

await repository.save(parsed);

// 이메일 발송

await mailer.sendWelcome(parsed.email);
```

### Optional: VS Code folding regions

If the team relies on collapsible sections in VS Code, use `// #region` /
`// #endregion`. Treat this as an editor aid — overuse usually signals that the
file should be split.

```ts
// #region Initialization
...
// #endregion

// #region Event Handlers
...
// #endregion
```

### Optional: TSDoc banner for top-level groupings

For library code, a short TSDoc-style comment can flag a logical grouping of
exported APIs.

```ts
/** Authentication-related public API. */

export function login(...) {}
export function logout(...) {}
```

### Avoid

- **Unicode box-drawing characters** (`──`, `═`, `│`, etc.) as section dividers.
  They aren't part of any standard style guide, render inconsistently across diff
  viewers and fonts, and tend to read as personal aesthetic rather than team
  convention.
- **Long banners of `/` or `*` characters** as decoration. They add visual noise
  without conveying information that a plain header doesn't already provide.

---

## Existing Comment Quality Review

Flag for update or removal when any of the following apply:

1. **Stale content** — the comment describes logic that no longer exists after the change
2. **WHAT repetition** — the comment restates what the code already shows
3. **Non-Korean** — team standard is Korean; technical terms may stay in English
4. **Too vague** — phrases like "처리한다" or "반환한다" with no meaningful context
5. **Missing `@throws`** — the function throws but has no `@throws` tag
6. **Missing `@param` / `@returns`** — exported functions with undocumented parameters
7. **Missing `@typeParam`** — generic functions, classes, or types with undocumented type parameters
8. **Missing `@defaultValue`** — optional properties or parameters with non-obvious defaults
