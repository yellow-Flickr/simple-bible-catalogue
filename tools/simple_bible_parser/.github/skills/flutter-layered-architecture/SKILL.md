---
name: flutter-layered-architecture
description: "Design, implement, review, or refactor maintainable Flutter features with clear UI, application, domain, and data boundaries. Use when adding features, choosing layer responsibilities, handling state, dependency injection, errors, persistence, caching, or migrating legacy code; adapt to the packages and conventions already used by the project."
---

# Flutter Feature Architecture

Use this skill to establish clear responsibilities and testable boundaries in
a Flutter app. It describes architectural roles, not a required folder layout,
dependency-injection container, state-management library, transport client, or
database.

## Start with the project

Before changing code:

1. Read the feature and its neighboring implementations, tests, and project
   instructions. Inspect `pubspec.yaml` only to understand the packages already
   in use; do not add or replace packages just to match an example here.
2. Identify the project's existing architecture, naming, state-management,
   dependency-injection, error, and persistence conventions.
3. Reuse those conventions when they are sound. If the project has no clear
   convention, choose the smallest structure that separates UI from business
   rules and external I/O.
4. Confirm which behavior is required before adding optional concerns such as
   offline support, caching, retries, or cross-feature state.

Do not retrofit every feature into a fixed template. A small, local feature
may need only a screen and a focused state holder; larger or more complex
features may benefit from the boundaries below.

## Architectural roles

These are responsibilities, not mandatory directories or one-class-per-layer
rules. Combine or omit roles when the feature does not need them.

| Role | Owns | Avoid |
|---|---|---|
| Presentation (widgets and state holder) | Rendering, user interaction, and UI state | Transport, persistence, or substantial business rules |
| Application (use case, service, or coordinator) | Feature workflows, orchestration, and policies spanning dependencies | Widget concerns and hidden dependency lookup |
| Domain (when useful) | Business concepts, invariants, and rules independent of frameworks | UI, transport, and storage details |
| Data / infrastructure | API, database, filesystem, platform, and other external-system adapters | UI state and feature presentation decisions |

Names vary across Flutter projects. A presentation state holder may be called
a **view model** or a **controller**; treat those terms as equivalent unless
the project explicitly distinguishes them. Likewise, application logic may be
called a service, use case, or coordinator. Follow local naming rather than
renaming code to match this guide.

A common dependency direction is:

```text
Widget → ViewModel / Controller → use case / service → repository or adapter
```

Keep dependencies pointing toward stable abstractions where the project uses
them. Do not force every call through a repository, service, interface, or
domain layer when that adds no useful separation.

## State and dependency lifetimes

- Keep mutable UI state in the project's established state-management
  mechanism. Widgets should render state and send user intent; avoid having
  multiple unrelated owners for the same state.
- Inject dependencies explicitly, usually through constructors or the
  project's established composition root. Avoid service locators and hidden
  lookups inside business logic.
- Match each object's lifetime to its consumers and resources. Screen-only
  state should usually end with the screen; shared state should live only as
  long as its actual consumers require.
- Follow the chosen package's lifecycle semantics. Reuse an existing instance
  only when its dependencies remain valid; update or recreate it when required.
  Dispose resources exactly once through their designated owner.
- Do not assume a root registry, provider ordering, `ChangeNotifier`, or any
  particular state-management package.

## DI registration: choose a composition shape

When adding a dependency, wire it through the project's actual registration
or composition mechanism. Constructing a class alone does not make it available
to consumers. Find where the app, feature, route, or test assembles
dependencies, then register or pass it there.

There is no single required DI layout. These approaches can be combined:

| Approach | How it works | Good fit | Watch out for |
|---|---|---|---|
| **Central registry** | One composition root declares most or all app dependencies. | Small apps or teams that value one easy-to-find dependency graph. | The registry can grow into a long, hard-to-navigate file; keep registration organized and avoid giving every object app-wide lifetime. |
| **Feature modules composed at the root** | Each feature exposes a registration/composition function; the app root combines those functions. | Medium-to-large apps where feature ownership and modularity matter. | Keep a clear app-level assembly point; avoid hidden registration side effects or duplicated bindings across modules. |
| **Scoped/local composition** | Route, screen, or a small parent constructs dependencies for a bounded subtree and passes them explicitly. | Short-lived UI state, isolated workflows, tests, and small features. | Do not create multiple competing instances of something that must be shared, or let short-lived UI scope own app-wide resources. |
| **Manual constructor wiring** | The caller directly creates an object and passes its dependencies. | Small object graphs, simple apps, and tests. | As the graph grows, centralize assembly so construction does not spread across widgets and business logic. |

These are organizational choices, not different architectural principles. A
modular app can have one root composition point that calls feature registration
functions and also creates screen-scoped state at routes. Prefer a **clear
composition root** over either extreme: one giant undifferentiated registry or
dependency construction scattered throughout the application.

### Registration workflow

1. Find the existing composition root or route-level composition point; follow
   the project's established DI and state-management packages.
2. Identify the new object's prerequisites and consumers. Register each
   binding once, after its prerequisites when the mechanism is order-dependent.
3. Choose a scope from actual ownership: application/session shared, feature
   shared, or route/screen local. Keep a dependency no longer-lived than
   necessary.
4. Define creation, configuration, updates, and disposal. Reuse an instance
   only while its dependencies remain valid; give resources one disposal owner.
5. Verify the intended consumer receives the configured instance. Add or
   update a composition/widget test when useful, and check for duplicate or
   missing registrations.

Consult the [DI recipes](./references/di-recipes.md) for optional
package-specific examples. Its `provider` recipes illustrate one central
registry style; they are not required when another composition shape fits
better.

## External I/O, errors, and caching

- Keep transport, database, filesystem, and platform details behind a boundary
  that can be tested independently.
- For input validation, first inspect and reuse the project's existing
  validators/utilities (for example, a shared `validation.dart`) instead of
  duplicating rules in widgets or feature code. Keep user-friendly form
  validation near presentation, and validate again at any business or external
  data boundary that must not trust client input.
- Convert external response shapes into typed app-facing values near that
  boundary. Preserve useful failure context and follow the project's error
  convention (`Result`, typed failures, exceptions, or another established
  contract).
- Decide explicitly where a failure is handled. Do not silently swallow
  unexpected failures or disguise them as valid empty data.
- Handle async/concurrency risks in proportion to the feature. For ordinary
  async work, consistently publish loading/result/error state and restore
  loading in all completion paths. Add safeguards when the behavior can
  actually race—for example, prevent duplicate form submissions or stop an
  older search response from replacing newer results. Do not add cancellation,
  locking, or concurrency abstractions without a concrete need; when an
  operation can outlive its screen, avoid publishing state after disposal and
  use the project's established lifecycle pattern.
- Add caching or offline behavior only when the feature requires it. Define
  cache identity, freshness, invalidation, and stale-data behavior before
  implementing a cache. A failed refresh must not make stale data appear fresh.
- Retry only appropriate transient failures and only when repeating the
  operation is safe. Do not blindly retry writes or authentication failures.

For optional implementation details, see:

- [Feature template](./references/feature-template.md) — package-neutral
  starting point and boundary examples.
- [Error contract](./references/error-contract.md) — typed failure handling.
- [Offline cache](./references/offline-cache.md) — cache policy and freshness.
- [Refactoring legacy code](./references/refactoring-legacy.md) — incremental
  migration steps.
- [Review checklist](./references/review-checklist.md) — architecture and
  behavior checks.
- [DI recipes](./references/di-recipes.md) — general DI guidance followed by
  optional `provider` examples, including a registration checklist.
- [DFA case study](./references/dfa-case-study.md) — details specific to the
  original DFA application; illustrative only, not a template for other apps.

## Implementation workflow

1. Trace the current behavior and list the relevant inputs, outputs, side
   effects, and failure cases.
2. Choose only the boundaries needed for the feature; keep package and folder
   choices consistent with the project.
3. Implement with explicit dependencies and typed data at boundaries.
4. Add or update focused tests alongside implementation when introducing or
   changing meaningful behavior. Inspect existing validation helpers and test
   conventions before adding new rules or test tooling.
5. Derive test cases from actual behavior and contracts, not just method
   names. Cover important success, boundary, state-transition, and failure
   paths; use unit tests for isolated rules and feature/widget tests for
   behavior across feature boundaries. Add async ordering/duplicate-operation
   tests only when the feature has those risks. Avoid trivial tests that only
   repeat implementation details.
6. Follow the project's existing test framework, directory layout, fixtures,
   and mocking/fake conventions. Prefer deterministic tests that do not call
   live services. Do not add a testing package unless required and approved by
   the project's conventions.
7. When the user says the feature is complete or adequately functional, review
   the implemented methods and functions for missing tests and fill meaningful
   gaps. Do not wait for this checkpoint to test changes already made; respect
   an explicit request to exclude tests.
8. Run the focused tests and the smallest relevant formatter/analyzer
   commands. Run code generation only when required by changed generated
   inputs.
9. Check that behavior is preserved, resources have clear owners, and
   documentation reflects any new convention. Report tests added, commands
   run, and any important behavior not covered.
