# Offline Data and Cache Policy

Caching is an optional feature policy, not a required layer. Add it when the
product needs data to remain available offline, reduce repeated reads, or
support a defined stale-data experience. Pick a strategy that fits the
project's persistence package and data requirements.

## Decide the behavior first

Before implementing a cache, answer:

1. Which data may be shown offline, and for how long?
2. What uniquely identifies a cached result? Include relevant filters, account,
   locale, tenant, or permissions in the key when they change the result.
3. Is stale data acceptable? Should the UI show a stale indicator or refresh
   warning?
4. Does a valid empty result differ from "never fetched"?
5. How are writes reflected locally, and how are conflicts or failed writes
   handled?
6. What invalidates the cache: TTL, user action, account change, data mutation,
   schema migration, or another event?

Do not assume that list endpoints should always succeed from cache or that
detail reads can never use cached data. Make the choice per feature and per
data sensitivity. For example, stale balances or permissions can be more
harmful than a clear refresh failure.

## A package-neutral read strategy

A common stale-while-revalidate flow is:

```text
read local snapshot → render it if available → fetch remote when policy says
to → store a successful response → publish the updated snapshot
```

For a cache-first read:

```text
if an entry exists and is fresh:
    return it
otherwise:
    attempt remote fetch
    on success: persist data and freshness together, then return it
    on failure: apply the feature's explicit stale-data policy
```

The policy may be to return stale data with a warning, to return a typed
failure, or to require a successful refresh. Do not accidentally return an
empty or unrelated cached value as a fallback.

## Freshness and cache identity

- Store freshness separately from the records when records are replaced or
  partial results are cached.
- Track freshness per cache key or dataset, not just globally, when requests
  vary by filter or user.
- Update freshness only after a successful fetch and successful persistence.
  If storing data and its timestamp cannot be atomic, document and test the
  recovery behavior.
- Treat "no freshness record" as unknown/uncached, not automatically fresh.
  A valid cached empty result can still be fresh when its metadata says so.
- Use an injected clock or equivalent seam when deterministic TTL tests are
  needed.

Keep TTL and invalidation policy near the feature/application layer, rather
than scattering different literal durations across widgets.

## Writes and cache consistency

Choose a write strategy explicitly:

- **Remote-first:** persist the confirmed server result locally after success.
- **Optimistic:** update local/UI state before the request, then reconcile on
  success or roll back/mark pending on failure.
- **Queued offline write:** persist an operation for later synchronization,
  with conflict and duplicate handling.

Optimistic updates and offline write queues need explicit failure, retry,
idempotency, and conflict behavior. They are not just a local write followed
by a network call.

## Connectivity

Connectivity signals can inform UI, but they are not proof that a request will
succeed or fail. Unless the product explicitly requires otherwise, attempt the
operation and handle its actual result. A connectivity check may be a useful
optimization, never the sole correctness mechanism.

## Test cases

- Empty cache and no network.
- Fresh cache and remote available/unavailable.
- Stale cache and successful refresh.
- Stale cache and failed refresh, including the chosen UI warning/error.
- Valid empty result versus never-fetched data.
- Different filters/accounts produce isolated cache entries.
- Failed writes do not falsely mark data fresh.
- Concurrent refreshes and cache invalidation if relevant.

## Anti-patterns

| Anti-pattern | Risk |
|---|---|
| Treating missing metadata as fresh | A cold cache can suppress the first fetch |
| Marking data fresh before persistence succeeds | Metadata can claim data is current when it is missing |
| Falling back to a cache for the wrong query or user | Data leaks or misleading results |
| Clearing all local data on every startup | Removes the value of offline support |
| Gating all requests on a connectivity plugin | Connectivity can be stale or inaccurate |
| Returning an empty collection for both failure and valid empty data | UI cannot tell what happened |
| Retrying writes without duplicate protection | The operation may happen more than once |
