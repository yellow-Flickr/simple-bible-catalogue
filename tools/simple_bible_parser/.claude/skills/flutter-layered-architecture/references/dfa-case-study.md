# DFA Case Study

A snapshot of how this particular `dfa` repository is organized. It is
project-specific and intentionally uses its packages, names, and paths; it is
not a normative architecture or a template for other projects. For portable
guidance, use the parent skill and its other references.

---

## Where each layer lives

```
lib/
├── main.dart                  ← bootstrap: ObjectBox, AuthConfig, MultiProvider
├── app_providers.dart         ← THE registry. AppProviders.get(...) → List<SingleChildWidget>
├── shared/                    ← canonical cross-cutting infrastructure
│   ├── network/api_client.dart, api_exceptions.dart, network_manager.dart
│   ├── dictionary/            ← domain/ data/ application/  (a full feature in shared/)
│   ├── instituition/          ← domain/ data/ application/
│   └── box_metadata.dart      ← cache freshness entity
├── <feature>/                 ← canonical features
│   ├── auth/ campaigns/ crm/ dashboard/ loans/ policy/ rewards/
│   ├── transactions/ user_accounts/
│   ├── domain/ data/ application/ presentation/
├── theme/                     ← dark_mode.dart, light_mode.dart, theme_provider.dart
├── utilities/                 ← shared toolkit (NOT architecture)
└── shop/, functions.dart      ← legacy — do not imitate
```

### Canonical features

These all follow the four-layer contract:

`auth` · `campaigns` · `crm` · `dashboard` · `loans` · `policy` · `rewards` ·
`shared/dictionary` · `shared/instituition` · `transactions` · `user_accounts`

### Shared infrastructure (`lib/shared/`)

Canonical. `shared/dictionary/` is a complete feature living in `shared/`
because other features depend on it.

### Shared toolkit (`lib/utilities/`)

Not architecture — a bag of helpers. Import freely, but do not treat it as a
layer:

| File | Contents |
|---|---|
| `helpers.dart` | `cashToString`, `statusColor`, `dateFormatter`, `assignIcons`, `PhoneNormaliser` |
| `constants.dart` | Date formats, `cacheTTL`, `logo`, `smsSkipDays` |
| `extends.dart` | `NullableStringExtension`, `Date` extension |
| `responsive.dart` | `Responsive` widget, `isMobile` / `isTablet` |
| `toast.dart` | `Toast` helpers |
| `file_picker_helper.dart` | `FilePickHelper` — the only place `file_picker` is called; owns the cancellation contract |
| `components/` | `custom_components.dart`, `dashboard_components.dart`, `bottom_navigation.dart`, `linear_bar.dart` |

### Legacy — do not imitate

| Path | Why |
|---|---|
| `lib/shop/` | `local/UserModel.dart`, `local/shopping_localstates.dart`, `screens/`, `components/` — mutable local state, no service/repository layer, no error contract |
| `lib/functions.dart` | Entirely commented out. Superseded by the service layer. The `Decisions` class it sketches is the old god-service |
| `lib/notifications/chatbot/` | Standalone `ChangeNotifier` with its own state, no service layer |
| `lib/utilities/components/custom_components.dart` | Some legacy `Provider.of<LocalState>` reads remain commented; the live code uses `context.watch<UserAccountViewModel>()` |

**Rule of thumb:** if the code lives under `shop/`, `functions.dart`, or
`notifications/chatbot/`, do not copy its structure. If you need a pattern
from there, re-derive it from the layer contract.

---

## The registry

`lib/app_providers.dart` (541 lines) — one class, one static getter, 65 provider
registrations, of which 15 are view models. The rest are services, remote and
local repositories, and the infrastructure singletons.

```dart
class AppProviders {
  const AppProviders._();

  static List<SingleChildWidget> get({
    required String baseUrl,
    required Store store,
    required AuthConfig authConfig,
  }) => [
        // ... infrastructure, then one banner-commented block per feature
      ];
}
```

Wired in `lib/main.dart`:

```dart
objectBox = await ObjectBox.create();
final config = await AuthConfig.resolve();

runApp(MultiProvider(
  providers: AppProviders.get(
    baseUrl: baseUrl,
    store: objectBox.objStore,
    authConfig: config,
  ),
  child: const MyApp(),
));
```

### Registration order in the file

The order is a hard constraint — a provider may only read providers above it.

```
Infrastructure
  Provider<http.Client>          (dispose: client.close())
  Provider<Store>.value
  Provider<AuthConfig>.value

Auth layer
  ProxyProvider2<http.Client, AuthConfig, AuthRepository>
  ChangeNotifierProvider<AuthService>
  ProxyProvider<AuthService, ApiClient>            ← ApiClient comes here

Then, per feature:
  ProxyProvider<ApiClient, Remote<X>Repository>
  ProxyProvider<Store, Local<X>Repository>
  ProxyProvider2<Remote<X>Repository, Local<X>Repository, XService>
  ChangeNotifierProxyProvider<XService, XViewModel>
```

### Cross-feature view models

Some view models need several services. The arity grows to match:

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

`DashboardService` is the facade pattern — it composes ten services so
`DashboardViewModel` needs only one dependency.

---

## The ViewModel scope rule, applied

> **Can you name the single screen that owns this state?**
> **No → app-scoped. Yes → screen-scoped.**

### App-scoped (registered in `app_providers.dart`)

`CustomerViewModel` is the clearest example. Its state is read by:

- `crm/customers/presentation/customer_list.dart` — the list screen
- `crm/customers/presentation/customer_details/customer_view.dart` — the detail screen
- `dashboard/presentation/reports/crm_reports.dart` — dashboard report tiles
- `utilities/components/dashboard_components.dart` — dashboard counters
- `shop/components/slider.dart` — a widget outside any screen tree

Five consumers across three feature trees → app-scoped. This is the case the
rule is designed for.

The full app-scoped set, from `AppProviders.get`:

`UserAccountViewModel` · `AffordabilityViewModel` · `CampaignViewModel` ·
`CustomerViewModel` · `CustomerAccountViewModel` · `ClaimsViewModel` ·
`SMSSchedulerViewModel` · `RewardsViewModel` · `TransactionsViewModel` ·
`LoansViewModel` · `LoanDetailViewModel` · `CustomerSignupViewModel` ·
`ApplyLoanViewModel` · `DirectSalesSchedulerViewModel` · `DashboardViewModel`

### Screen-scoped (register on the route)

No feature currently uses this. It is the correct choice for a future
single-screen form view model:

```dart
ChangeNotifierProvider(
  create: (ctx) => CustomerFormViewModel(ctx.read<CustomerService>()),
  child: const CustomerPersonalDetails(),
);
```

Do **not** also add it to `app_providers.dart`.

---

## The API client

`lib/shared/network/api_client.dart` — one client for the whole app.

```dart
class ApiClient {
  final AuthService authService;
  final http.Client _client;
  final String baseUrl;
```

- `_mergeHeaders` adds `Content-Type`, `Accept`, and
  `Authorization: Bearer ${authService.accessToken}` when a token exists.
  Per-request headers override.
- `_send` retries transient failures with `RetryOptions` (2 attempts,
  exponential backoff, 10% jitter) and maps socket/timeout errors to
  `NetworkException`.
- `_parse` handles the three response shapes: `rawJson` (body as string),
  `fromJson` (converter), and a direct cast to `T`.
- `_assertSuccess` maps status codes to the `ApiException` hierarchy.

### The exception hierarchy

`lib/shared/network/api_exceptions.dart` — `ApiException` base with
`UnauthorizedException` (401), `ForbiddenException` (403),
`NotFoundException` (404), `ValidationException` (422, carries a field-error
map), `ServerException` (5xx), `NetworkException` (no connectivity).

### Writing a remote repository

`lib/crm/customers/data/remote_customer_repository.dart` is the reference
implementation:

```dart
class RemoteCustomerRepository {
  final ApiClient _client;

  RemoteCustomerRepository(this._client);

  static const String _customerPath = '/customers';
  static const String _searchPath = '/customers/search';

  Future<List<CustomerModel>> getCustomerListByParameter(
          Map<String, String>? parameter) async =>
      _client.get(_customerPath,
          queryParams: parameter,
          fromJson: (d) =>
              (d as List).map((e) => CustomerModel.fromJson(e)).toList());

  Future<String> registerCustomer(CustomerDetail signUpData) async =>
      _client.post(_customerPath,
          headers: {"Idempotency-key": const Uuid().v4()},
          body: signUpData.toJson(),
          rawJson: true);
}
```

Note the `Idempotency-key` header on every write.

---

## The service, in this repo

`lib/crm/customers/application/customer_service.dart`:

```dart
class CustomerService {
  final RemoteCustomerRepository _remote;
  final LocalCustomersRepository _local;

  CustomerService(this._remote, this._local);

  int count() => _local.count();
  bool isEmpty() => _local.isEmpty();
  List<CustomerModel> query() => _local.getAll();
  List<CustomerModel> search(String term) => _local.search(term);

  Future<List<CustomerModel>> syncIfEmpty({Map<String, String>? filter}) async {
    try {
      if (_local.isCacheValid(cacheTTL)) {
        return _local.getAll();
      }
      return await getList(filter: filter);
    } on Exception catch (e) {
      log(e.toString());
      return _local.getAll();
    }
  }

  Future<List<CustomerModel>> getList({Map<String, String>? filter}) async {
    try {
      final items = await _remote.getCustomerListByParameter(filter);
      _local
        ..clear()
        ..saveAll(items);
      _local.markFresh();
      return items;
    } catch (e) {
      log(e.toString());
      return _local.getAll();
    }
  }

  Future<CustomerDetail> getDetail(String id) =>
      _remote.getCustomerAllDetails(id);
}
```

`cacheTTL` comes from `lib/utilities/constants.dart` — `Duration(days: 1)`.

---

## The local repository and freshness

`lib/crm/customers/data/local_customers_repository.dart` holds a
`Box<CustomerModel>` plus a `Box<BoxMetadata>`, with
`isCacheValid(ttl)` / `markFresh()`.

`lib/shared/box_metadata.dart`:

```dart
@Entity()
class BoxMetadata {
  @Id()
  int? uid;

  @Unique(onConflict: ConflictStrategy.replace)
  final String cacheName;

  DateTime lastUpdated;

  bool isExpired(Duration ttl) => DateTime.now().difference(lastUpdated) > ttl;
  void markFresh() => lastUpdated = DateTime.now();
}
```

The entity pattern (`lib/crm/customers/domain/customer_model.dart`):

```dart
@Entity()
class CustomerModel {
  @Id()
  int? uid;

  @Unique(onConflict: ConflictStrategy.replace)
  String? customerid;

  String? customername;
  String? status;
  // ...

  factory CustomerModel.fromJson(Map<String, dynamic> json) => /* ... */;
  Map<String, dynamic> toJson() => { /* ... */ };
}
```

Regenerate after any entity change:

```
dart run build_runner build
```

`lib/objectbox.g.dart` and `lib/objectbox-model.json` are generated. Never
hand-edit them.

---

## The view model, in this repo

`lib/crm/customers/presentation/customer_view_model.dart` — the reference
implementation of the contract:

```dart
class CustomerViewModel extends ChangeNotifier {
  final CustomerService _service;

  CustomerViewModel(this._service);

  bool _loading = false;
  bool _initialized = false;
  String? _error;
  List<CustomerModel> items = [];
  List<CustomerModel> searchResults = [];

  bool get loading => _loading;
  String? get error => _error;
  bool get isEmpty => _service.isEmpty();

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      items = await _service.syncIfEmpty();
      _clearError();
    } catch (e) {
      log(e.toString());
    } finally {
      _initialized = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_loading) return;
    _begin();
    try {
      items = await _service.getList();
      _clearError();
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      _end();
    }
  }

  void _begin() { _loading = true; notifyListeners(); }
  void _end()   { _loading = false; notifyListeners(); }
  void _setError(String message) => _error = message;
  void _clearError() => _error = null;
}
```

---

## Screen conventions

- `context.watch<ViewModel>()` in `build()` when the whole screen reacts.
- `context.read<ViewModel>()` in callbacks and in `initState`.
- `Consumer<ViewModel>` when only a subtree reacts.
- `init()` is called from `addPostFrameCallback` in `initState`:

```dart
@override
void initState() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    context.read<CustomerViewModel>().init();
  });
  super.initState();
}
```

- Search is debounced at 500 ms in the screen, using a `Timer` cancelled in
  `dispose()`.
- `responsive_sizer` is used for sizing (`1.w`, `2.h`); `lib/utilities/responsive.dart`
  provides a `Responsive` widget for breakpoint layouts.
- Theme comes from `context.watch<ThemeProvider>().themeData`.

---

## Known issues in this repo

Do not propagate these into new code. They are recorded here so a reviewer can
tell a mistake from a pattern.

### 1. `AppProviders.disposeAllViewModels` double-disposes

`lib/app_providers.dart:536-540` manually disposes app-scoped view models:

```dart
static void disposeAllViewModels(BuildContext context) {
  getProviders(context).forEach((disposableProvider) {
    disposableProvider.dispose();
  });
}
```

`ChangeNotifierProxyProvider` already disposes its `ChangeNotifier` when the
provider leaves the tree — it passes `dispose: ChangeNotifierProvider._dispose`
to the underlying provider, which calls `notifier?.dispose()`.

`ChangeNotifier.dispose()` starts with
`assert(ChangeNotifier.debugAssertNotDisposed(this))`, so the second call trips
a Flutter assertion in debug builds.

**Correct behaviour:** do not dispose a provider-owned notifier manually. A
view model that owns timers or subscriptions implements `dispose()` itself and
cancels them there.

### 2. `ApiClient` maps DELETE to GET

`lib/shared/network/api_client.dart:169`:

```dart
_Method.delete => _client.get(uri, headers: headers),
```

Every `DELETE` in the app is sent as a `GET`. Affects
`deleteCustomerAttachment`, `deleteCustomerIdinfo`, and any other delete
endpoint.

### 3. `CustomerViewModel._begin()` does not notify

`lib/crm/customers/presentation/customer_view_model.dart:288-291` has
`notifyListeners()` commented out inside `_begin()`. This means the loading
state is only published on `_end()`. The contract — and the template — say
`_begin` notifies. The other view models follow the contract; this one does
not.

### 4. The root `feature_template.md` contradicts the scoping rule

`feature_template.md` (repo root) says:

> ViewModels are scoped to their screen, NOT registered here.

The actual code registers ~15 view models globally in `app_providers.dart`.
The rule in this skill — *app-scoped when no single screen owns the state* —
reconciles the two. The skill's `references/feature-template.md` is the
canonical version; the root file is stale.

### 5. `Provider.debugCheckInvalidValueType = null`

`lib/main.dart:42` disables provider's runtime type checking. This silences a
useful safety net during a migration. Prefer fixing the type mismatch and
removing the line.

### 6. Credentials in `pubspec.yaml`

Two git dependencies in `pubspec.yaml` embed GitLab deploy tokens in their
URLs. This is a live credential leak in a committed file, and it is copied
into every agent that reads the manifest.

Move the tokens out of the manifest — use a deploy token configured in CI, or
`pubspec_overrides.yaml` (git-ignored) for local clones — and rotate the
exposed ones.

### 7. `file_picker` call sites — fixed via `FilePickHelper`

`file_picker` 12.0.0 signals a cancelled pick **differently per API**:

- `FilePicker.pickFile()` returns **null**
- `FilePicker.pickFiles()` returns an **empty list**

> Returns a list of `PlatformFile` objects containing the selected files, or
> an empty list if the user canceled the operation.

The codebase was written against the older API, where `pickFiles` returned
`List<XFile>?` and cancel produced `null`. After the upgrade to 12.0.0 the
guards were never updated, so **every one of the 19 call sites crashed when
the user backed out of the system picker**. The only path that worked was the
in-app "Cancel" button, which pops `null`.

| Pattern | Sites | Failure on cancel |
|---|---|---|
| `if (file.isNotEmpty) { File(file.first.path!) } else { File('') }` | 10 | `PathNotFoundException` at the consumer's `readAsBytesSync()` — the `File('')` sentinel is not a real file |
| `_paths!.first.readAsBytes()` | 5 | `StateError: No element` (and a null-check crash if the pick throws `PlatformException`) |
| `file.single.path!` | 1 | `StateError: No element` — `crm/customers/presentation/customer_signup/attachment.dart:372` |
| `pickedFile.first.path!` | 1 | `StateError: No element` — `campaigns/campaign/presentation/campaign_audience.dart:1222`; the loader spinner never hides |
| `file.first.path!`, caller commented out | 1 | dead code — `loans/affordability/presentation/add_affordability.dart:729` |

**The fix:** one shared helper, `lib/utilities/file_picker_helper.dart`, now
owns the cancellation contract. Every call site routes through it.

```dart
class FilePickHelper {
  static Future<PlatformFile?> pickPlatformFile({...});  // null on cancel
  static Future<File?> pickFile({...});                   // null on cancel
  static Future<List<PlatformFile>> pickFiles({...});     // empty on cancel
}
```

The helper catches `PlatformException` and returns null / empty, so a failed
pick is never an unhandled error. It never fabricates a `File('')` — that
sentinel is not a valid file and reading it throws.

### The migrated call sites (19)

All `FilePicker.*` calls now live only inside `lib/utilities/file_picker_helper.dart`.

| File | Uses |
|---|---|
| `utilities/components/custom_components.dart` | `pickFile` — keeps the `File('')` "no file" marker for `UploadWidget` |
| `loans/loan/presentation/loan_application/apply_loan_attachments.dart` | `pickFile` |
| `loans/loan/presentation/loan_application/apply_loan_consolidated_loan.dart` | `pickFile` |
| `loans/loan/presentation/loan_application/apply_loan_security_cheque_form.dart` | `pickFile` |
| `loans/loan/presentation/loan_application/apply_loan_security_guarrantor.dart` | `pickPlatformFile` |
| `loans/loan/presentation/loan_application/apply_loan_security_asset_collateral.dart` | `pickPlatformFile` |
| `loans/loan/presentation/loan_edit/edit_loan_attachment.dart` | `pickFile` |
| `loans/loan/presentation/loan_edit/loan_security/edit_post_dated_cheque.dart` | `pickPlatformFile` |
| `loans/loan/presentation/loan_edit/loan_security/edit_guarantor_security.dart` | `pickPlatformFile` |
| `loans/loan/presentation/loan_edit/loan_security/edit_asset_collateral.dart` | `pickPlatformFile` |
| `loans/affordability/presentation/add_affordability.dart` | `pickFile` |
| `crm/customers/presentation/customer_details/update_customer_attachment.dart` | `pickFile` |
| `crm/customers/presentation/customer_edit/attachment.dart` | `pickFile` |
| `crm/customers/presentation/customer_signup/attachment.dart` | `pickFile` |
| `policy/presentation/claims/claims_attachment.dart` | `pickFile` |
| `transactions/presentation/transfers/remittance_ID.dart` | `pickFile` |
| `transactions/presentation/transfers/send/senderDetails.dart` | `pickFile` |
| `campaigns/campaign/presentation/campaign_audience.dart` | `pickPlatformFile` |
| `loans/loan/presentation/loan_application/apply_loan_security_savings_collateral.dart` | commented out — dead code, left as-is |

**The five `_paths` loan-security screens** keep their `_paths` list shape so
no downstream code has to change; they now assign `_paths = [picked]` and
return early on null, which also stops the loader.

**When adding a new picker call, use `FilePickHelper`.** Never call
`FilePicker` directly, never fabricate a `File('')`, and never index a pick
result without checking it for null / emptiness first.

---

## Boot sequence

```
lib/main.dart
  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(smsWorkmanagerCallback);
  objectBox = await ObjectBox.create();        ← lib/objectbox.dart
  final config = await AuthConfig.resolve();    ← lib/auth/domain/auth_config.dart
  runApp(MultiProvider(providers: AppProviders.get(...), child: MyApp()));
```

`lib/objectbox.dart` opens the store at
`<documents>/obx-dfa` and reuses an already-open store if one exists.

`MyApp` reads `NetworkManager` and `ThemeProvider`, wraps the app in
`ResponsiveSizer`, and sets `home: WelcomePage()`.

Auth gating happens in `lib/auth/presentation/auth_wrapper.dart`, which reads
`AuthService` and routes to login or the app shell.

---

## Feature checklist for `dfa`

- [ ] `lib/<feature>/domain/` — entity with `@Entity()`, `fromJson`, `toJson`
- [ ] `lib/<feature>/data/remote_<feature>_repository.dart` — `ApiClient`, `static const` paths, `Idempotency-key` on writes
- [ ] `lib/<feature>/data/local_<feature>_repository.dart` — `Box<T>` + `BoxMetadata` freshness
- [ ] `lib/<feature>/application/<feature>_service.dart` — remote→local fallback, rethrow on detail
- [ ] `lib/<feature>/presentation/<feature>_view_model.dart` — `_begin`/`_end`, typed exception mapping
- [ ] `lib/<feature>/presentation/` — screens that read the view model only
- [ ] `lib/app_providers.dart` — registrations in dependency order, in a banner-commented block
- [ ] View model scope decided and applied
- [ ] `dart run build_runner build` re-run if the entity changed
- [ ] `flutter analyze` clean
