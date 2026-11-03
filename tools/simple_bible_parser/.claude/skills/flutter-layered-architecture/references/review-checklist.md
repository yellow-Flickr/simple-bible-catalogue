# Feature Architecture Review Checklist

Use this as a guide, not a rigid scorecard. Adapt it to the feature's scope and
the project's packages and conventions. A small feature does not need every
layer or every concern listed here.

## 1. Boundaries and dependencies

- [ ] Widgets primarily render state and forward user intent.
- [ ] Business rules and workflows have a clear owner.
- [ ] Transport, persistence, and platform details do not leak through the UI.
- [ ] Dependencies are explicit and flow in a deliberate direction.
- [ ] No service locator or hidden global lookup was introduced unnecessarily.
- [ ] Every added layer has a responsibility that improves changeability or
      testability.

## 2. State ownership and lifecycle

- [ ] Each mutable state value has a clear owner.
- [ ] State scope matches its consumers and required lifetime.
- [ ] The project's established view-model/controller terminology and state
      mechanism are followed.
- [ ] Async operations publish loading/data/error state consistently.
- [ ] Duplicate or stale async operations are guarded only where the feature
      can race and incorrect results or duplicate side effects matter.
- [ ] Timers, subscriptions, clients, and other resources have one clear
      disposal owner.

## 3. Data and external adapters

- [ ] External data is converted or validated at an appropriate boundary.
- [ ] Existing project validation helpers are reused instead of duplicating
      rules; untrusted input is checked at the boundary that needs to trust it.
- [ ] API payloads and persisted records are separated from domain concepts
      when their shapes or lifecycles differ.
- [ ] Repositories or adapters do not contain unrelated UI state or feature
      presentation policy.
- [ ] Dependencies such as clients and stores are injected when ownership or
      testing requires it.
- [ ] Mutating operations are safe against unintended duplicates where needed.

## 4. Errors and fallback behavior

- [ ] Expected failures have deliberate handling and safe UI messaging.
- [ ] Unexpected failures remain observable through the project's diagnostics.
- [ ] Failure is distinguishable from a valid empty result.
- [ ] Caching/fallback behavior is explicit and does not hide important errors.
- [ ] Retries are bounded and safe for the operation.
- [ ] Sensitive details are not exposed in logs or UI.

## 5. Optional persistence/cache checks

- [ ] The feature genuinely requires offline or repeated-read support.
- [ ] Cache keys include all relevant query/user context.
- [ ] Missing freshness metadata is not treated as a known-fresh entry.
- [ ] Freshness is recorded only after the intended data is stored.
- [ ] Invalidation and stale-data UI behavior are defined.
- [ ] Optimistic or queued writes have reconciliation and failure behavior.

## 6. Compatibility and verification

- [ ] Existing behavior, navigation, validation, and cancellation semantics are
      preserved unless intentionally changed.
- [ ] Tests are added or updated with meaningful behavior changes; when the
      user marks the feature complete or adequate, meaningful coverage gaps
      have been reviewed and addressed, unless tests were explicitly excluded.
- [ ] Tests cover meaningful behavior and state transitions rather than only
      mirroring private implementation details.
- [ ] Async ordering or duplicate-action tests exist when a concrete race risk
      warrants them; no unnecessary concurrency machinery was added.
- [ ] Focused formatter, analyzer, and test commands pass.
- [ ] Code generation is run only when required by changed generated inputs.
- [ ] Generated files were not hand-edited.
- [ ] Direct callers and obsolete code paths are accounted for.
- [ ] Documentation reflects any new project convention.

## Package-specific checks (only when applicable)

Apply these only if the project uses the corresponding mechanism:

- **Dependency-injection package:** verify its actual create/update/dispose
  semantics; do not reuse stale objects when dependencies change.
- **State-management package:** verify notifier/stream/controller ownership
  and avoid disposing package-owned objects twice.
- **Code generation:** run the repository's documented generator and inspect
  generated changes.
- **Database package:** verify indexes, migrations, transactions, and query
  behavior using that package's conventions.
- **Network client:** verify status/error mapping, timeouts, auth refresh, and
  write retry/idempotency behavior.
