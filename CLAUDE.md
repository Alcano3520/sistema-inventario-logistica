# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository layout

This repo contains two unrelated codebases:

- **`app/`** — the active product: a Flutter app (`inventario_logistica`) backed by Supabase. All current development happens here.
- **Repo root** (`Codigo.gs`, `index.html`, `JavaScript.html`, `Stylesheet.html`) — the legacy Google Apps Script system ("el sistema original") that the Flutter app is replacing/porting from. It is referenced in commit messages when porting behavior/bug-parity, but is not built or run. Don't edit it unless explicitly asked to check parity with the original.

All commands below assume `cd app` first.

## Commands

```bash
flutter pub get              # install dependencies
flutter analyze              # static analysis (uses flutter_lints via app/analysis_options.yaml)
flutter run                  # run the app (device/emulator or web)
flutter build apk|web|...    # build for a target platform
```

There is no test suite in this repo (`app/test/` is empty) — do not assume `flutter test` covers anything.

The app reads Supabase credentials from `app/.env` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`), loaded via `flutter_dotenv` and declared as a Flutter asset in `pubspec.yaml`. This file is gitignored; it must exist locally for the app to run.

## Architecture

### Feature-first structure

`app/lib/features/<feature>/` each split into `data/` (Supabase repositories), `domain/` (plain model classes), `presentation/` (Riverpod providers + screens/widgets). Shared cross-feature code lives in `app/lib/core/` (theme, Supabase client init, module config) and `app/lib/shared/widgets/` (the app shell/nav).

State management is Riverpod (`flutter_riverpod`) throughout — providers are colocated in each feature's `presentation/` folder (e.g. `general_providers.dart`, `auth_providers.dart`). Repositories are plain classes instantiated by providers, not services with DI containers.

### Multi-module design (`core/modulos.dart`)

The app serves multiple independent inventories ("módulos") from one codebase and one Supabase project, each with **fully separate tables**:

- `barcos` (Bote/BOAT inventory) — table prefix `inv_*`
- `motos` (Moto inventory) — table prefix `inv_motos_*`
- `general` ("Inventario General"/dotación — payroll-deduction issuance to employees) — table prefix `inv_general_*`, feature folder `features/general/`

`barcos` and `motos` are `TipoModulo.simple`: they share the exact same screens (`features/movimientos`, `features/productos`, `features/historial`) and differ only by which table set (`ModuloTablas`) is injected via `tablasActivasProvider`. Adding a new "simple" module means adding a `ModuloTablas` entry in `_tablasPorModulo` and an entry in `modulosDisponibles` — no new screens needed.

`general` is `TipoModulo.dotacion`: a structurally different flow (deliveries to employees, payroll deductions, returns, corrections) with its own dedicated screens under `features/general/presentation/`, not shared with the simple modules.

`AppShell` (`shared/widgets/app_shell.dart`) picks which tab set to build (`_construirTabsSimple` vs `_construirTabsDotacion`) based on the active module's `TipoModulo`, and filters tabs by `perfil.esAdmin`.

The active module is tracked by `moduloActivoProvider` (set once at the module-selector screen, before entering `AppShell`); every repository in the simple modules reads table names through `tablasActivasProvider` rather than hardcoding table names.

### Auth & authorization

`Perfil` (`features/auth/domain/perfil.dart`) is the business-level user (separate from Supabase Auth's `User`): `rol` (`'Admin'` vs operator roles) and `modulos` (list of module keys the user is allowed into) drive UI visibility. `esAdmin` gates admin-only tabs/screens app-wide. Note: the module *selector* screen always lets Admin through regardless of their own `modulos` list (Admin sees all modules; operators only see what's in their `inv_perfiles.modulos`) — don't reintroduce a `modulos`-based filter for Admin in the selector.

### Offline support (`general` module only)

`features/general/data/offline_queue_general.dart` + `sync_general_service.dart` implement an offline queue backed by Hive: writes made while offline are queued (`OfflineQueueGeneral.encolar`) and replayed against Supabase when connectivity returns (via `connectivity_plus`), by re-invoking the *same repository method* rather than recomputing/caching stock client-side. This is deliberate: stock math always happens in a Postgres trigger on insert into `inv_general_movimientos`, so replaying is race-safe and there's no client-side stock recalculation to keep in sync. Preserve this pattern (queue-and-replay through the repository, never precompute a stock delta client-side) when extending offline behavior.

### Supabase conventions

- All repositories call the shared `supabase` client getter from `core/supabase_config.dart`.
- Business logic that must be atomic (stock adjustments, duplicate detection/removal, stock recalculation) is implemented as Postgres RPCs, named per module in `ModuloTablas` (`rpcDetectarDuplicados`, `rpcEliminarDuplicados`, `rpcRecalcularStocks`) — call these instead of doing multi-step read-modify-write from Dart.
- Signed transaction records (entradas/salidas/entregas/devoluciones) can carry a signature image uploaded to the `inv-firmas` storage bucket; `motos` signatures live under a `motos/` subfolder (`ModuloTablas.carpetaFirmas`) to avoid colliding with `barcos`' existing paths at the bucket root — keep this subfolder convention when adding modules.

## Language

UI strings, Dart identifiers, comments, and commit messages in this repo are predominantly in Spanish (logistics domain for the company Insevig: bote/moto inventories, entregas, devoluciones, nómina, cédula). Match this convention for new code and commits rather than switching to English.
