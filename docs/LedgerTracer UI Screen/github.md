repo: VuThanh2/LedgerTracer
branch: main
path: lib

## Last sync
date: 2026-08-30T13:30:35Z

### Updated in this project
- Đọc toàn bộ cây `lib/` — repo hiện là scaffold rỗng (mọi file 0 byte trừ `lib/main.dart`), không có UI để recreate.
- Ghi memory dự án vào `CLAUDE.md` từ Overview / Screen Map / DESIGN.
- Thiết kế UI xuất phát từ `uploads/DESIGN.md`, đặt tên màn hình khớp cấu trúc `lib/presentation/*`.

## Screen map
| Screen (design) | Repo files |
| --- | --- |
| App Shell | lib/app/ledger_tracer_app.dart, lib/app/router.dart, lib/presentation/shared/responsive/breakpoints.dart |
| Transaction List / Detail / Filter | lib/presentation/transactions/transactions_page.dart, lib/presentation/transactions/bloc/* |
| Import (Nhập mới / Lịch sử) | lib/presentation/import/import_page.dart, lib/presentation/import/bloc/* |
| Reconciliation | lib/presentation/reconciliation/reconciliation_page.dart, lib/presentation/reconciliation/bloc/* |
| Statistics | lib/presentation/statistics/statistics_page.dart, lib/presentation/statistics/bloc/* |
| Settings / Account Management / Backup | lib/presentation/settings/settings_page.dart, lib/presentation/accounts/accounts_page.dart |
| Developer Diagnostics | lib/presentation/diagnostics/diagnostics_page.dart |
| Theme tokens | lib/app/theme.dart (chưa có nội dung) |
