# REBS — Business Automation Platform (Flutter)

Offline-first Flutter application built with **Clean Architecture** for the **REBS** platform (**HRMS**, **CRM**, and **Accounts** modules), starting with the employee **Attendance** and **Leave Management** workflows.

## Architecture Overview

```text
lib/
├── main.dart
├── app.dart
├── core/
│   ├── config/          # Environment config (API base URL, timeouts, sync backoff)
│   ├── constants/       # REST endpoints & SQLite schema constants
│   ├── database/        # Local SQLite database (offline source of truth)
│   ├── di/              # get_it dependency injection setup
│   ├── error/           # Typed exceptions, domain Failure hierarchy, Result<T>
│   ├── network/         # Dio ApiClient (idempotency keys) & Connectivity monitor
│   ├── router/          # go_router StatefulShellRoute across REBS modules
│   ├── sync/            # Durable SQLite outbox queue, SyncManager & SyncHandler contract
│   ├── theme/           # Material 3 theme
│   ├── usecases/        # Base UseCase<T, Params>
│   └── widgets/         # Global SyncStatusBanner, SyncStatusChip, AppShellScaffold
└── features/
    ├── hrms/
    │   ├── attendance/  # domain / data (local, remote, sync handler) / presentation (BLoC + UI)
    │   └── leave/       # domain / data (local, remote, sync handler) / presentation (BLoC + UI)
    ├── crm/             # Module scaffold ready for Clean Architecture expansion
    └── accounts/        # Module scaffold ready for Clean Architecture expansion
```

## Offline-First & Reliable Sync Strategy

1. **Local SQLite Source of Truth**: Attendance logs, leave requests, and leave balances are read from local SQLite so the app stays responsive with zero connectivity.
2. **Atomic Transactional Outbox**: Every write (Check In, Check Out, Apply Leave, Cancel Leave) writes the local domain record and enqueues a `SyncOperation` in `sync_queue` inside a single SQLite transaction.
3. **Idempotent Retries**: Every outbox operation carries a unique `X-Idempotency-Key` so flaky network retries never create duplicate check-ins or leave requests.
4. **Automatic Recovery & Backoff**: `SyncManager` listens to connectivity changes, recovers interrupted operations on restart, processes queued items FIFO, applies capped exponential backoff on transient failures, and isolates `409 Conflict` errors so one conflicting record cannot block the queue.
5. **Pluggable Multi-Module Sync**: Future **CRM** and **Accounts** features only need to implement `SyncHandler` and register with `SyncManager` in `lib/core/di/injection_container.dart`.

## Getting Started

```bash
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=https://api.yourdomain.com/v1
```
# workspace
