# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**GENESIS PICKING** — an offline-first Flutter order-picking assistant for a Dakar-based
parapharmacy wholesaler (Univers Parapharmacie). Three roles (Administrateur,
Préparateur, Coursier) share one app: admins import/manage picking tours and users,
préparateurs pick products against a tour, coursiers handle "produit introuvable"
requests. All business text, comments, and domain naming are in **French**; keep new
domain code consistent with that (infrastructure/technical naming stays English).

## Commands

```bash
flutter pub get                                                   # install deps
dart run build_runner build --delete-conflicting-outputs          # regenerate local_database.g.dart after touching any Drift table/@DriftDatabase
flutter analyze                                                   # lint (see analysis_options.yaml)
flutter test                                                      # run all tests
flutter test test/features/picking/picking_service_test.dart      # run a single test file
flutter test --plain-name "some test description"                 # run a single test by name
flutter run                                                        # run the app
```

Run `build_runner` any time you add/modify a Drift table or change `LocalDatabase`'s
`@DriftDatabase(tables: [...])` list — `local_database.g.dart` is generated, not hand-edited.

## Architecture

### Layering: `core/` vs `features/`

- `lib/core/` — everything cross-cutting and stable: config, error handling
  (`Result<T>` + `AppException`), logging, theme, i18n scaffolding, navigation,
  session, local storage (Drift), and the sync queue *mechanism*. Feature modules
  depend on `core/`, never the reverse.
- `lib/features/<name>/` — one folder per business module, each internally split into
  `data/` (models, repository interfaces + Drift implementations, Drift tables),
  `domain/` (services — business rules), and `presentation/` (Riverpod controllers +
  screens/widgets). Not every feature has all three (e.g. `administration` and
  `sync` are read/orchestration-heavy).

Modules, in the order they were built (see `MODULE_*.md` for the full design
rationale/tradeoffs of each — read the relevant one before making non-trivial changes
in that area):

| Feature dir | Module | Responsibility |
|---|---|---|
| `auth/`, `user_management/` | 2 | Login, password hashing/lockout, account CRUD |
| `tours/` | 3 | Download/list/resume a picking tour |
| `picking/` | 4 | The core picking engine — product-by-product guided collection |
| `courier/` | 5 | "Produit introuvable" requests + courier-facing screens |
| `sync/` (+ `core/sync/`) | 6 | Real sync engine: queue drain, conflict resolution, transport |
| `administration/` | 8 | Read-only aggregation dashboard + tour reassignment, over existing repos |
| `import/` | (dedicated) | Format-agnostic tour import: PDF (real/calibrated), CSV/Excel/JSON (functional, uncalibrated) |

`core/sync/SyncQueue` (write-only enqueue, used by business modules) and
`features/sync/data/SyncRepository` (read/update, used only by the sync engine) look
similar but are deliberately separate responsibilities — don't merge them.

### Per-feature class pattern (see `features/picking/` as the canonical example)

`XxxState`/model → `XxxRepository` (abstract interface, pure CRUD, no business rules)
→ `DriftXxxRepository` (Drift implementation) → `XxxService` (domain logic: validation,
transitions, orchestration across repositories) → `XxxController` (Riverpod
`Notifier`, screen-facing state) → screen/widgets. Repositories that touch more than
one table for a single atomic operation (e.g. `PickingRepository` updating a product
*and* tour progress together) are kept distinct from single-table repositories
(`ProductRepository`) — don't collapse them.

Providers for a feature live in one `<feature>_providers.dart` file per feature
(mirrors `core/providers/core_providers.dart` for cross-cutting ones).

### State management: Riverpod

Chosen for explicit dependencies (`ref.watch`) and testability — services take their
dependencies (repositories, other services) via constructor injection so tests can
swap in fakes without touching Riverpod at all. `ref.onDispose` is used everywhere a
provider owns a closeable resource (DB connection, stream subscription) — follow this
when adding new providers that own resources.

### Local storage: Drift (SQLite), offline-first

Single `LocalDatabase` (`core/storage/local_database.dart`) assembles every table
from every feature via `@DriftDatabase(tables: [...])`. Schema is versioned
(`schemaVersion`, currently 9) with an additive `onUpgrade` migration per version —
never edit a past migration step; add a new `if (from < N)` block. `local_database.g.dart`
is generated (excluded from lint via `analysis_options.yaml`) — regenerate, don't hand-edit.

### Error handling: `Result<T>` + `AppException`

`data`/`domain` layers return `Result<T>` (`core/errors/result.dart`) instead of
throwing, so callers must handle failure via `.when(success:, failure:)`.
`AppException` subclasses map to user-facing French messages centrally through
`ErrorHandler.userMessageFor()` — add new failure cases there, don't inline error
strings in screens. `FutureBuilder` usages must handle `snapshot.hasError` explicitly
(a past audit found several screens that didn't — see MODULE_9.md).

### Navigation: go_router with centralized role guard

All redirect logic lives in `AppNavigationGuard.resolveRedirect()`
(`core/navigation/app_navigation_guard.dart`), called from the single `redirect:` in
`app_router.dart`. Never add ad-hoc role checks or redirects inside a screen — route
protection (including preventing a role from reaching another role's home) must stay
in the guard so it's tested in one place (`test/core/navigation/app_navigation_guard_test.dart`).

### Sync: offline queue, drained by a separate engine

Business modules only ever call `SyncQueue.enqueue(...)` (fire-and-forget, optional
priority) to record an event — they never talk to the network. `features/sync/domain/SyncService`
is the actual engine: drains the queue, checks `NetworkMonitor` before each operation
(not just once), talks to `SyncTransport` (currently `SimulatedSyncTransport` — this
specific engine is still not wired to a real backend), and resolves conflicts via
`ConflictResolver`. Keep this separation when touching sync: engine changes go in
`features/sync/`, enqueueing changes go wherever the business event happens.

### Real cross-device sync: Firebase/Firestore (separate path from the queue above)

As of 2026-08-30, a real backend exists and is in active use: **Firebase/Firestore**
(project `genesis-picking-univers`, config in `lib/firebase_options.dart` +
`android/app/google-services.json`, rules in `firestore.rules`). This is a
**second, independent** sync path, deliberately not routed through
`core/sync/SyncQueue`/`SyncService` above — it exists so that accounts, tours, and
courier requests created on one device (e.g. a préparateur importing a tour on a PC)
become visible on another device (e.g. that préparateur's phone, or the coursier's
phone) without a shared file/network drive. Firebase Authentication is **not** used —
local password auth (`SyncingUserRepository`) remains the only login mechanism;
Firestore is purely a data relay. No Firebase Storage (requires the paid "Blaze"
plan, unavailable — payment card rejected): photos are compressed client-side
(`core/sync/photo_compression.dart`, max 480px/JPEG 70) and embedded directly as a
`data:` URI in the Firestore document instead.

The pattern repeats per feature needing this — `tours/`, `auth/` (via
`SyncingUserRepository`/`UserPullSync`), `courier/` — each with a push side
(`XRemoteSink`/`NoXRemoteSink`/`FirestoreXRemoteSink`, called best-effort/try-catch
right after the local write already succeeded — a push failure never blocks or
reverses the local write) and a pull side (`XRemoteSource`/`NoXRemoteSource`/
`FirestoreXRemoteSource`, plus `XRepository.upsertFromRemote()` for idempotent local
merge). `firestore.rules` currently allows open read/write on every collection
(`users`, `tours`, `tour_product_lines`, `courier_requests`) — acceptable only
because this is a small trusted internal team with no public exposure; **every new
collection added to this sync path needs its own `match` block added to
`firestore.rules` and deployed (`firebase deploy --only firestore:rules`), or writes
to it fail silently with `permission-denied`** (this exact gap caused a real
multi-day debugging session for `courier_requests`).

A recurring, easy-to-miss pitfall in this sync path: any data a receiving device
needs to *display* (not just store) must travel **inside** the pushed document
itself, never be assumed reachable via a local join to another table — the
receiving device may never have downloaded the data the join depends on (e.g. a
coursier device never downloads a tour, so `CourierRequestsTable` denormalizes
`produitNom`/`produitDescription`/`produitImageUrl` as a snapshot taken at request
creation, exactly like `quantiteDemandee`/`emplacement` already did — see that
table's doc comment).

When testing this path end-to-end across real devices (not the `flutter test` fakes,
which use `No*` no-op implementations by default): a code fix alone does nothing
until the actual rebuilt binary reaches the actual device — verify each target
device is running a build newer than the fix (e.g. compare the artifact's file
timestamp against the latest edited source file), don't assume a device is "already
updated" because a build succeeded on this machine.

## Testing conventions

- Domain/service tests use hand-written in-memory fakes (`FakeXxxRepository` etc. in
  `test/features/<feature>/`) implementing the same abstract repository interfaces as
  the Drift implementations — no mocking framework. When you add a method to a
  repository interface, update its fakes to match or tests won't compile.
- No widget/integration/navigation tests exist yet (documented gap, see MODULE_9.md
  §6) — unit tests cover `domain`/`data` logic only.

## Known technical debt (documented, intentionally not fixed — see MODULE_9.md)

- `core/l10n/` i18n scaffolding exists but is never called; all screens hardcode
  French text directly.
- `DatabaseSeeder` creates a default admin account with a hard-coded password if none
  exists; nothing forces changing it.
- Role/permission enforcement is UI + router only — Firestore (see "Real cross-device
  sync" above) has no server-side rule checking role/ownership, it's wide open by
  design for now; nothing enforces permissions outside the app itself.
- `core/sync/SyncService`/`SimulatedSyncTransport` (the original queue-drain engine)
  is still not wired to a real backend — don't confuse it with the separate, real
  Firebase/Firestore path described above, which bypasses this engine entirely.
