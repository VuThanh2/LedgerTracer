# LedgerTracer

Offline app for importing bank statements from several accounts, searching
transactions, and reconciling internal transfers between them. All data stays
in a local SQLite database on the device.

Supported statement formats: Excel (.xlsx), CSV, MT940 and JSON.

## Requirements

| | Version / note |
|---|---|
| Flutter | 3.47.0 (stable) |
| Dart | 3.13.0 (bundled with Flutter) |
| Android | Android SDK via Android Studio, an emulator or a physical device |
| Web | Google Chrome |

Tested targets are **Android** and **Web (Chrome)**. Fingerprint / face unlock
for App Lock only works on a device with biometrics enrolled; the PIN works
everywhere.

No environment variables, API keys or external services are needed.

## Setup

```bash
git clone https://github.com/VuThanh2/LedgerTracer.git
cd LedgerTracer
flutter doctor        # check that Flutter, Android toolchain and Chrome are found
flutter pub get
```

## Run

```bash
flutter devices                 # list available devices
flutter run -d chrome           # Web
flutter run -d <device-id>      # Android emulator or phone
```

Release builds:

```bash
flutter build apk --release     # build/app/outputs/flutter-apk/app-release.apk
flutter build web --release     # build/web
```

## Main scenarios

1. **Accounts** — create one bank account per statement you plan to import.
2. **Import** — pick one or more files, assign each to an account, and start
   the import. Re-importing the same file is detected as a duplicate.
3. **Transactions** — search, filter, open, edit or delete transactions;
   export the current list to Excel/CSV.
4. **Reconciliation** — with statements from two or more accounts imported,
   run the scan, then confirm or reject the suggested internal-transfer pairs.
5. **Statistics** — view cash flow by period; confirmed internal transfers
   are excluded by default.
6. **Settings** — App Lock (PIN / biometrics), backup & restore, reset app.

### Developer Diagnostics (performance experiment)

Open **Settings**, tap the footer line *"LedgerTracer · offline · data never
leaves this device"* 7 times, then open **Developer diagnostics →**. From
there you can probe the runtime and benchmark the statement-import and
reconciliation-scan workloads under different concurrency settings.

## Tests

```bash
flutter test          # unit + widget tests
flutter analyze       # static analysis
```

## Project structure

```
lib/
  domain/          entities, value objects, repository interfaces
  application/     use cases
  infrastructure/  SQLite, statement parsers, exporters, platform services
  presentation/    screens, BLoCs, widgets
  core/            concurrency (isolates / main-thread fallback on Web)
docs/              requirements, use cases, design notes
```