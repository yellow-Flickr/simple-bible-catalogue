# Error Handling Contract

Treat failures as part of an operation's contract. Keep their meaning intact
across boundaries, decide where each failure is handled, and show users a
useful message without exposing implementation details.

This guidance is transport- and package-neutral. HTTP status mappings below
are examples for HTTP-backed features; GraphQL, local persistence, platform
APIs, and other transports should map their own failures into the app's
established error model.

## Choose one app-facing convention

Use the convention already present in the project. Common choices include:

- typed exceptions;
- a typed `Result`/`Either` value;
- a state object that carries success, loading, and failure.

Avoid mixing conventions arbitrarily. A useful failure should preserve the
information callers need, such as its category, a safe display message,
validation details, retryability, and an underlying cause for diagnostics.
Do not make every feature depend on HTTP status codes if those codes have no
meaning outside the transport adapter.

For example, an HTTP adapter may map `401`, `403`, `404`, `422`, server errors,
and connectivity/timeouts to typed failures. The mapping belongs at the
transport boundary, not in widgets. Validation details should be represented
with a type that matches the API contract instead of assuming every server
returns `Map<String, dynamic>`.

## Responsibility by boundary

| Boundary | Responsibility |
|---|---|
| Transport / platform adapter | Interpret external failure signals and map them into the app's error convention |
| Repository or data adapter | Preserve meaningful failure information; translate only when its abstraction requires it |
| Use case / service | Apply the feature's explicit policy, such as fallback, compensation, or rethrow |
| View model / controller | Convert expected failures into presentation state and safe UI messages |
| Widget | Render the provided state; avoid owning transport or business error policy |

The exact boundary names can differ. Keep the direction of responsibility:
external details are translated inward, while presentation wording stays near
the presentation layer or in localization.

## Handle expected and unexpected failures differently

- Handle expected failures specifically when the feature can respond
  meaningfully (for example validation, missing data, permission denial, or
  offline state).
- Preserve a useful generic error state for unexpected failures; do not turn
  arbitrary programming errors into success-shaped values.
- Log or report unexpected failures through the project's established
  diagnostics path. Avoid logging credentials, tokens, personal data, or
  complete sensitive payloads.
- Do not silently ignore an error. If stale or cached data is intentionally
  returned, make that fallback policy explicit and retain a way to observe the
  refresh failure when needed.
- Avoid catching an error only to rethrow it unchanged. Catch only when adding
  context, translating a boundary, performing cleanup, or applying a deliberate
  policy.

With typed exceptions, catch more specific subtypes before their parent type.
With `Result` values, match all relevant cases. In either style, ensure cleanup
and loading-state restoration happen on both success and failure, typically
through `finally` or an equivalent structured mechanism.

## HTTP-specific considerations

For an HTTP-backed API:

| Signal | Possible app-facing category |
|---|---|
| Authentication rejected | Unauthenticated / session expired |
| Permission denied | Forbidden |
| Resource missing | Not found |
| Request validation rejected | Validation failure with field details |
| Server failure | Remote service failure |
| Socket, DNS, or timeout | Network unavailable / request timed out |
| Other response | A safe, typed request failure |

Map statuses once at the HTTP boundary. Do not parse the same response body
again in each repository or screen. A `401` is not a generic transient error:
refresh credentials under a deliberate, bounded policy or end the session.
Never retry it blindly.

Retries should be bounded, limited to genuinely transient failures, and safe
for the operation. A read is often retryable; a write may need an idempotency
mechanism or server-supported deduplication before retrying.

## Presentation

The view model/controller should expose enough state for the UI to distinguish
loading, data, empty results, and failure when those states matter. An empty
collection is valid domain data; do not use it to conceal a failed request.

Map technical failures to localized, user-appropriate text. Keep detailed
diagnostics out of UI strings. A stale-data fallback may show the last known
data while also exposing a non-blocking refresh warning if that is useful to
the user.

## Anti-patterns

| Anti-pattern | Why it is risky |
|---|---|
| Empty `catch` or ignored error | The failure and its consequences disappear |
| Returning an empty list for every error | Failure becomes indistinguishable from a valid empty result |
| Exposing raw transport exceptions to widgets | Couples presentation to infrastructure and may leak details |
| Converting every failure to a string too early | Removes type and context needed for policy decisions |
| Catching a parent exception before a specific subtype | Prevents specialized handling |
| Retrying every failure | Can repeat unsafe writes, waste resources, or loop on permanent errors |
