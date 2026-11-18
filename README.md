# REBS — Business Automation Platform (Flutter)

Offline-first Flutter application built with **Clean Architecture** for the **REBS** platform (**HRMS**, **CRM**, and **Accounts** modules), focused on the employee **Dashboard**, **Attendance Check-In/Out**, and **Leave Management** workflows.

## Architecture Overview

```text
lib/
├── main.dart
├── app.dart
├── core/
│   ├── config/          # API URL, preconfigured employee, office coordinates & company timezone
│   ├── constants/       # REST endpoints & SQLite schema constants
│   ├── database/        # Local SQLite database (offline source of truth, unique daily constraints)
│   ├── di/              # get_it dependency injection setup
│   ├── error/           # Typed exceptions, domain Failure hierarchy, Dart 3 sealed Result<T>
│   ├── location/        # Geolocator service, Haversine 200m calculator, reviewer simulator UI
│   ├── network/         # Dio ApiClient (idempotency keys) & Connectivity monitor
│   ├── router/          # go_router StatefulShellRoute across REBS modules
│   ├── sync/            # Durable SQLite outbox queue, SyncManager & SyncHandler contract
│   ├── theme/           # Material 3 theme
│   ├── time/            # CompanyClock for configurable company-timezone working days & formatting
│   ├── usecases/        # Base UseCase<T, Params>
│   └── widgets/         # Global SyncStatusBanner, SyncStatusChip, AppShellScaffold
└── features/
    ├── auth/            # Preconfigured employee session initialization & SQLite persistence
    ├── hrms/
    │   ├── dashboard/   # Employee Dashboard (profile, today's status, balances, latest 5 records)
    │   ├── attendance/  # domain / data (local, remote, sync handler) / presentation (BLoC + UI)
    │   └── leave/       # domain / data (local, remote, sync handler) / presentation (BLoC + UI)
    ├── modules/         # REBS platform module hub
    ├── crm/             # Module scaffold ready for Clean Architecture expansion
    └── accounts/        # Module scaffold ready for Clean Architecture expansion
```

## Attendance Check-In & Check-Out Rules

- **Once per company working day**: Working dates (`YYYY-MM-DD`) and displayed timestamps are resolved using `CompanyClock` in the configured `COMPANY_TIMEZONE` (`Asia/Kolkata` by default), enforced in both repository checks and a SQLite `UNIQUE(employee_id, attendance_date)` index.
- **Check-out only after check-in**: Single attendance session per working day with no overnight shifts.
- **Duplicate tap protection**: Guarded across UI (`isSubmitting` lock), BLoC (`submitting` + rapid double-tap drop window), and repository (`_isMutationInFlight` mutex + pre/post-GPS database checks).
- **GPS capture & 200m office geofence**: Captures timestamp and WGS84 coordinates, verifies Haversine distance ≤ 200m from the configured office (`Teqbae Innovations, Kochi` at `10.0159, 76.3419` by default), and handles denied, permanently denied (with **Settings** action), unavailable GPS (with **GPS** settings action), and outside-radius states with meaningful messages.

## Configurable Office Coordinates & Reviewer Location Simulation

Office coordinates and company timezone are never hardcoded into UI or business logic; they live in `lib/core/config/employee_config.dart` and can be overridden at launch:

```bash
flutter run \
  --dart-define=OFFICE_LATITUDE=10.0159 \
  --dart-define=OFFICE_LONGITUDE=76.3419 \
  --dart-define=COMPANY_TIMEZONE=Asia/Kolkata \
  --dart-define=API_BASE_URL=http://localhost:8080
```

### How Reviewers Can Simulate Locations
1. **Quick In-App Toggle**: On the **Dashboard** or **Attendance** card, toggle **Inside 200m Range** ON (~25m from office) to allow check-in/out, or OFF (~450m away) to see the inline **Outside Office Premises** warning and geofence rejection.
2. **Full Location Simulator Sheet**: Tap the **tune icon** beside the toggle (or the top-right location icon on Dashboard) to test any mode:
   - `Live Device GPS`
   - `Simulate: Inside Office (~25m)`
   - `Simulate: Outside Office (~450m)`
   - `Simulate: Permission Denied`
   - `Simulate: Permanently Denied`
   - `Simulate: Location Unavailable`
   - `Simulate: Custom Coordinates` (enter any latitude & longitude)
3. **CLI Launch Flag**:
   ```bash
   flutter run --dart-define=SIMULATE_LOCATION=inside         # ~25m inside office
   flutter run --dart-define=SIMULATE_LOCATION=outside        # ~450m outside office
   flutter run --dart-define=SIMULATE_LOCATION=denied         # permission denied
   flutter run --dart-define=SIMULATE_LOCATION=denied_forever # permanently denied
   flutter run --dart-define=SIMULATE_LOCATION=unavailable    # GPS disabled/unavailable
   ```

## Device-Side vs Production Server-Side Validation

Device-side checks provide immediate offline UX and clear error feedback, **but must never be trusted as the sole security boundary**. A production REBS server must repeat the following checks:

| Check | Why the Production Server Must Repeat It |
|---|---|
| **Employee identity & authorization** | Derive `employee_id` from verified JWT/session claims—never trust client-submitted IDs—and verify active employment and assigned office. |
| **Office geofence distance & spoofing** | Recompute Haversine distance against authoritative office coordinates stored server-side; flag mock-location telemetry, poor GPS accuracy, or impossible travel speeds. |
| **Working-day uniqueness & ordering** | Enforce transactional `UNIQUE(employee_id, company_working_date)` and state transitions (`check_in` must precede `check_out`, single session per working day) to prevent races across multiple devices. |
| **Event identity & idempotency** | Enforce unique `X-Idempotency-Key` / `event_id` records server-side so client retries after timeouts never create duplicate attendance logs. |
| **Authoritative timestamp & company timezone** | Validate client timestamps against server UTC time and the company timezone (rejecting implausible future/past clock skew while allowing a defined offline grace window). |

## Offline-First & Reliable Sync Strategy

1. **Local SQLite Source of Truth**: Attendance logs, leave requests, and leave balances are read from local SQLite so the app stays responsive with zero connectivity.
2. **Atomic Transactional Outbox**: Every write commits the local domain record and enqueues a `SyncOperation` in `sync_queue` inside a single SQLite transaction.
3. **Idempotent Retries**: Every outbox operation carries a unique `X-Idempotency-Key` so retries after timeouts never duplicate server records.
4. **Automatic Recovery & Backoff**: `SyncManager` listens to connectivity changes, recovers interrupted operations on restart, processes queued items FIFO, applies capped exponential backoff on transient failures, and isolates `409 Conflict` errors so one conflicting record cannot block the queue.

## Getting Started

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```
