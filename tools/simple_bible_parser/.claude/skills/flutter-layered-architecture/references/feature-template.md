# Feature Structure and Boundary Template

Use this as a design aid, not as a required file list or copy-and-paste
scaffold. Start with the project's conventions and add only the boundaries
that solve a real problem. All examples use Dart concepts but avoid prescribing
third-party packages.

## Choose the smallest useful shape

A simple local screen may only need a widget and a state holder. A feature with
business workflows and remote or persistent data may benefit from separate
presentation, application, domain, and data roles:

```text
lib/<feature>/
  domain/          # optional: concepts, invariants, value types
  data/            # optional: API/database/platform adapters
  application/     # optional: use cases, workflows, policies
  presentation/    # widgets and view model/controller
```

Directory names and class names are examples. A repository is useful when it
provides a stable data boundary; it is not mandatory when it merely forwards
one call without adding value.

## Responsibilities

| Component | Typical responsibility |
|---|---|
| Model / value type | Represent a concept with the types and invariants the app needs |
| Data source / adapter | Communicate with one external system |
| Repository | Provide an app-facing data contract when multiple sources, mapping, or isolation justify it |
| Use case / service | Coordinate dependencies and enforce feature policy when needed |
| View model / controller | Own presentation state and user-triggered operations |
| Widget | Render state and relay user intent |

The terms **view model** and **controller** are both used for the presentation
state holder in Flutter projects. Use whichever term the project uses; this
template uses both names interchangeably.

## Example data contract

Define the contract at the boundary that best fits the project. A repository
interface is useful when it improves testing or isolates data sources:

```dart
abstract interface class ItemRepository {
  Future<List<Item>> getItems();
  Future<Item?> getItem(String id);
}
```

If `Item` needs JSON, database annotations, or generated serialization, keep
those concerns aligned with the project's existing model conventions. Separate
API payloads, persistence records, and domain models when their shapes or
lifecycles differ; do not create duplicate types merely for architectural
symmetry.

An adapter should:

- accept required clients, stores, or platform interfaces as dependencies;
- map external data into typed app-facing values near the boundary;
- keep endpoint paths, query details, and database operations out of widgets;
- expose meaningful errors instead of swallowing them;
- avoid owning global configuration or constructing hidden service locators.

## Example application workflow

Add an application service or use case when a workflow combines dependencies,
enforces business rules, or owns a policy such as cache fallback:

```dart
class ItemService {
  ItemService(this._repository);

  final ItemRepository _repository;

  Future<List<Item>> loadItems() => _repository.getItems();
}
```

For a single pass-through operation, calling the repository from the
view model/controller may be simpler and appropriate. Follow local conventions
and keep business policy out of widgets either way.

## Example presentation state holder

This is a shape, not a prescribed state-management implementation. Adapt it to
the project's mechanism (for example a notifier, bloc/cubit, provider-based
model, or another established approach):

```dart
class ItemController {
  ItemController(this._service);

  final ItemService _service;
  bool isLoading = false;
  String? errorMessage;
  List<Item> items = const [];

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    publishState();
    try {
      items = await _service.loadItems();
    } on ExpectedFailure catch (failure) {
      errorMessage = failure.safeMessage;
    } finally {
      isLoading = false;
      publishState();
    }
  }

  void publishState() {
    // Replace with the project's state-emission mechanism.
  }
}
```

The example's `ExpectedFailure` and `publishState` are placeholders for the
project's actual error and state contracts; do not add those names as new
dependencies. Consider immutable state snapshots if that is the established
pattern. Keep state private or expose read-only values where practical, and
prevent overlapping operations when duplicate requests would be harmful.

The controller should:

- express loading, success, empty, and failure states that the UI needs;
- map known failures to presentation-safe state;
- retain unexpected failures for diagnostics rather than silently ignoring
  them;
- release timers, subscriptions, and other owned resources using the
  project's lifecycle convention.

## Dependency composition

Construct objects in the project's established composition root or route
scope. Pass dependencies explicitly. The composition mechanism may be
constructor wiring, a DI container, a state-management package, or manual
composition.

Choose scope by actual ownership and lifetime:

- screen/route scope for state that ends with one screen;
- feature scope for state shared by a feature's routes;
- session/app scope only when consumers and lifetime justify it.

These are conceptual scopes, not package APIs. Dispose only resources owned by
the relevant scope, once.

## Tests to consider

- Domain rules and mapping logic can be tested without widgets or external I/O.
- Application policies are tested with controlled dependency fakes.
- State transitions are tested for success, empty data, expected failure, and
  unexpected failure as appropriate.
- Adapters are tested at their boundary using the project's existing
  conventions, without requiring live production services.
- Widget tests focus on rendering and user interaction rather than duplicating
  business-rule tests.
- When relevant, test validation rules at their existing helper and test that
  forms show or block submission appropriately. Reuse the project's shared
  validators (for example, `validation.dart`) rather than copying rules into a
  new feature. Validate untrusted input again at a business/data boundary where
  correctness or security requires it.
- Test async ordering or duplicate-action safeguards only when the feature can
  exhibit those races (such as overlapping searches or repeated submissions).
  Prefer tests for the observable outcome over tests for a particular locking
  or cancellation implementation.

## Testing during implementation and feature completion

Add or update focused tests as meaningful behavior is implemented or changed,
using the project's existing test conventions. When the user marks the feature
complete, or says it has adequate structure or functionality, inspect the
implemented public methods and functions for missing meaningful coverage and
fill those gaps. Do not defer all test work until completion unless the user
explicitly asks for that workflow or excludes tests.

Use the method/function inventory to find behavior worth verifying, not to
create one shallow test per method mechanically:

| Code under test | Typical test focus |
|---|---|
| Pure functions, validators, mappers, and domain rules | Unit tests for valid, invalid, boundary, and transformation cases |
| Use cases/services/controllers/view models | Unit tests for outputs, state transitions, dependency interactions, and expected failures |
| Feature flow spanning layers | Feature tests for user-visible behavior and important integration boundaries |
| Widgets/screens | Widget tests for rendering states, user actions, and navigation where relevant |
| External adapters | Boundary tests using fakes, fixtures, or controlled clients; avoid live production services |

Prioritize meaningful branches and contracts: success, empty results, invalid
input, expected errors, and edge cases that can change user-visible behavior.
For async behavior, add ordering or repeated-action cases when there is an
actual race risk; do not add generic concurrency machinery or tests without a
feature-specific reason. Keep tests deterministic and independent of private
implementation details.

## Feature completion checklist

- [ ] The boundaries match the feature's complexity and the surrounding code.
- [ ] Widgets do not own transport or persistence policy.
- [ ] Dependencies and resource lifetimes are explicit.
- [ ] Data crossing an external boundary is validated or mapped into useful
      app-facing types.
- [ ] Existing validation utilities are reused where appropriate; validation
      is applied at the relevant form and trusted data boundaries.
- [ ] Errors and empty data remain distinguishable.
- [ ] Relevant tests are added alongside behavior changes; at feature
      completion, meaningful coverage gaps have been reviewed and addressed
      (unless the user excluded tests).
- [ ] Tests cover important rules, state transitions, and user-visible
      behavior without mechanically duplicating implementation details.
- [ ] Async race safeguards and tests are added only where concrete feature
      behavior can race.
- [ ] Existing formatting, analysis, generation, and test commands pass.
