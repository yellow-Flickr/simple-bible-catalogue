# Dependency Injection Recipes

Dependency injection is a way to make dependencies and ownership explicit,
not a requirement to add a container. Follow the project's existing
composition approach; constructor wiring or a small composition root may be
enough.

General guidance:

- Construct dependencies at a deliberate composition boundary and pass them
  explicitly.
- Match each instance's lifetime to its consumers and resources.
- Reuse an instance only while its dependencies remain valid. If a dependency
  changes, update or recreate the dependent object according to its contract.
- Dispose owned resources exactly once through the designated owner.
- Avoid service locators and hidden dependency lookup inside business logic.

The examples below use `package:provider` and are **optional, package-specific
recipes**. Do not translate provider APIs literally into another container;
map the ownership and lifecycle intent to the project's actual API.

## Provider cheat sheet

| Widget | Use for | Lifetime |
|---|---|---|
| `Provider<T>` | A value with no dependencies, or one that needs an explicit `dispose` | App |
| `Provider<T>.value` | A pre-built object handed in from `main()` (a DB store, a config) | App, **not** disposed |
| `ProxyProvider<T, R>` | `R` depends on `T` | Depends on provider configuration |
| `ProxyProvider2..6<T, R>` | `R` depends on several providers | Depends on provider configuration |
| `ChangeNotifierProvider<T>` | A `ChangeNotifier` with no dependencies | App or route |
| `ChangeNotifierProxyProvider<T, R>` | A `ChangeNotifier` that depends on `T` | Depends on provider configuration |
| `ChangeNotifierProxyProvider2..6` | A `ChangeNotifier` that depends on several providers | Depends on provider configuration |
| `MultiProvider` | The root wrapper; takes a `List<SingleChildWidget>` | App |

---

## 1. Reuse instances only when dependencies remain valid

```dart
ProxyProvider2<RemoteThingRepository, LocalThingRepository, ThingService>(
  create: (ctx) => ThingService(
    ctx.read<RemoteThingRepository>(),
    ctx.read<LocalThingRepository>(),
  ),
  update: (_, __, ___, previous) => previous!,
),
```

In this example, returning `previous!` is appropriate only while the
repositories are stable for this provider's lifetime. Provider may call
`update` when an upstream dependency changes; blindly returning the previous
object in that case can leave it holding stale dependencies.

If dependencies can change, update the existing instance through an explicit
update method or replace it according to the object's state and resource
ownership. Rebuilding is not always wrong, and reusing is not always safe.

The `update` callback signature grows with the arity. The trailing `previous`
parameter is always last:

| Arity | `update` signature |
|---|---|
| `ProxyProvider` | `(_, value, previous) => ...` |
| `ProxyProvider2` | `(_, v1, v2, previous) => ...` |
| `ProxyProvider3` | `(_, v1, v2, v3, previous) => ...` |
| `ProxyProvider4` | `(_, v1, v2, v3, v4, previous) => ...` |
| `ProxyProvider5` | `(_, v1, v2, v3, v4, v5, previous) => ...` |

### Avoid this when dependencies can change

```dart
// This can discard service state or resources on dependency changes.
ProxyProvider2<RemoteThingRepository, LocalThingRepository, ThingService>(
  create: (ctx) => ThingService(...),
  update: (_, remote, local, previous) =>
      ThingService(remote, local),   // ← new instance every time
);
```

```dart
// `watch` is not the right dependency lookup in this creation callback.
ProxyProvider<ApiClient, RemoteThingRepository>(
  create: (ctx) => RemoteThingRepository(ctx.watch<ApiClient>()),
  update: (_, __, previous) => previous!,
);
```

Use `ctx.read<T>()` inside this package's `create:` callback. Use
`ctx.watch<T>()` in a widget's `build()` when the widget should rebuild in
response to changes.

---

## 2. Pre-built singletons

```dart
// main.dart
final objectBox = await ObjectBox.create();
final config = await AuthConfig.resolve();

runApp(
  MultiProvider(
    providers: AppProviders.get(
      baseUrl: baseUrl,
      store: objectBox.objStore,
      authConfig: config,
    ),
    child: const MyApp(),
  ),
);
```

```dart
// registry
Provider<Store>.value(value: store),
Provider<AuthConfig>.value(value: authConfig),
```

`.value` means "this object already exists — the provider must not create it."
The creator retains lifecycle responsibility unless ownership is explicitly
transferred by another mechanism.

---

## 3. Long-lived clients

A shared HTTP client must be closed exactly once, when the app tears down.

```dart
Provider<http.Client>(
  create: (_) => http.Client(),
  dispose: (_, client) => client.close(),
),
```

The same pattern applies to any resource that needs releasing.

---

## 4. One possible Provider composition root

This pattern uses one function to build a provider list. It is a project
convention, not a requirement; other apps may compose dependencies through
routes, modules, generated containers, or manual constructor wiring.

```dart
class AppProviders {
  const AppProviders._();

  static List<SingleChildWidget> get({
    required String baseUrl,
    required Store store,
    required AuthConfig authConfig,
  }) =>
      [
        // ── Infrastructure ────────────────────────────────────────────────
        Provider<http.Client>(
          create: (_) => http.Client(),
          dispose: (_, client) => client.close(),
        ),
        Provider<Store>.value(value: store),
        Provider<AuthConfig>.value(value: authConfig),

        // ── Auth layer ─────────────────────────────────────────────────────
        ProxyProvider2<http.Client, AuthConfig, AuthRepository>(
          create: (ctx) => AuthRepository(
            client: ctx.read<http.Client>(),
            config: ctx.read<AuthConfig>(),
            baseUrl: baseUrl,
          ),
          update: (_, __, ___, previous) => previous!,
        ),

        // ── Feature layer ──────────────────────────────────────────────────
        // ... repositories, then service, then view model, per feature.
      ];
}
```

### Registration order in this provider pattern

A provider in this list can only read providers available above it in the
resulting tree. Other DI systems may resolve dependencies differently.

Correct order within a feature:

```
1. Remote repository   (reads ApiClient)
2. Local repository    (reads Store)
3. Service             (reads both repositories)
4. ViewModel           (reads the service)
```

### Optional organization convention

```dart
// ── Customers layer ────────────────────────────────────────────────────────
```

If a long provider list is used, grouping related dependencies can make the
dependency graph easier to review. Match the repository's existing style.

---

## 5. Cross-feature dependencies

When a view model needs another feature's service, widen the arity — do not
nest `ctx.read` inside `ctx.read` inside a closure.

```dart
ChangeNotifierProxyProvider4<
    AffordabilityService,
    DictionaryService,
    CustomerAccountService,
    LoansService,
    ApplyLoanViewModel>(
  create: (ctx) => ApplyLoanViewModel(
    ctx.read<AffordabilityService>(),
    ctx.read<DictionaryService>(),
    ctx.read<CustomerAccountService>(),
    ctx.read<LoansService>(),
  ),
  update: (_, _____, ____, __, ___, previous) => previous!,
),
```

If a view model/controller depends on many unrelated services, review whether
it owns too many responsibilities. A focused use case or facade can help when
it represents a cohesive workflow; there is no universal dependency-count
threshold.

---

## 6. A view model / controller that needs the current user

```dart
ChangeNotifierProxyProvider2<UserAccountService, AuthService, UserAccountViewModel>(
  create: (ctx) {
    final user = ctx.read<AuthService>().user;
    if (user == null) throw StateError('Auth user not available');
    return UserAccountViewModel(ctx.read<UserAccountService>(), user);
  },
  update: (_, __, ___, previous) => previous!,
),
```

This captures the user at creation time. Use it only if the user is stable for
the object's lifetime. If sign-in state can change, expose that dependency
reactively or update/recreate the view model deliberately. The `create` body
can throw when the user is a true precondition; otherwise model a null user as
a legitimate state.

---

## 7. View model / controller scope

> **Can you name the single screen that owns this state?**
> **No → app-scoped. Yes → screen-scoped.**

This is a heuristic, not a universal binary choice. A feature or session
scope may be more appropriate than either route or app scope.

### App-scoped

State read by two or more screens, read by widgets outside a screen tree
(dashboard tiles, app-bar badges, bottom-nav counters), needed across
navigation, or consumed by another feature.

```dart
// registry
ChangeNotifierProxyProvider<ThingService, ThingViewModel>(
  create: (ctx) => ThingViewModel(ctx.read<ThingService>()),
  update: (_, __, previous) => previous!,
),
```

### Screen-scoped

State owned by exactly one screen tree.

```dart
// on the route
ChangeNotifierProvider(
  create: (ctx) => ThingFormViewModel(ctx.read<ThingService>()),
  child: const ThingFormScreen(),
);
```

Screen-scoped view models are **not** added to the root registry.

### Disposal

In this provider pattern, `ChangeNotifierProvider` and
`ChangeNotifierProxyProvider` dispose their owned `ChangeNotifier` when the
provider leaves the tree. Do not also dispose the same notifier manually.
Other state-management packages have their own ownership rules; follow those
instead of assuming this lifecycle.

A view model that owns timers, streams, or subscriptions cancels them in its own
`dispose()`:

```dart
class SchedulerViewModel extends ChangeNotifier {
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
```

---

## 8. Composites and facades

When one screen needs many services, compose them into a single facade rather
than widening the view model's dependency list.

```dart
Provider<DashboardService>(
  create: (ctx) => DashboardService(
    auth: ctx.read<AuthService>(),
    loans: ctx.read<LoansService>(),
    campaigns: ctx.read<CampaignService>(),
    dictionary: ctx.read<DictionaryService>(),
  ),
),

ChangeNotifierProvider<DashboardViewModel>(
  create: (ctx) => DashboardViewModel(ctx.read<DashboardService>()),
),
```

The facade is a plain class that orchestrates; it is not a `ChangeNotifier`.

---

## 9. A service that must not be re-created

Some services own a background worker or a subscription. Give them an explicit
`dispose` so the provider releases it.

```dart
ProxyProvider<LocalSchedulerRepository, SchedulerService>(
  create: (ctx) => SchedulerService(
    repository: ctx.read<LocalSchedulerRepository>(),
  ),
  update: (_, __, previous) => previous!,
  dispose: (_, service) => service.dispose(),
),
```

---

## 10. Debug aids (Provider-specific)

```dart
// main.dart — silences provider's runtime type check while migrating
Provider.debugCheckInvalidValueType = null;
```

This disables a useful safety net. Prefer fixing the type mismatch instead, and
treat this line as temporary.

---

## 11. Checklist for a new registration

- [ ] Registered in the root registry, in the feature's banner-comment block
- [ ] Placed **after** every provider it reads
- [ ] `update:` returns `previous!` (or `previous` with the correct arity)
- [ ] `ctx.read<T>()` used inside `create:`, never `ctx.watch<T>()`
- [ ] `dispose:` provided if the object holds a resource
- [ ] `.value` used for pre-built objects handed in from `main()`
- [ ] View model scope decided and applied consistently
- [ ] No manual `dispose()` of any provider-owned notifier
