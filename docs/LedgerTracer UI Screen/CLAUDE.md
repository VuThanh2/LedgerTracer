# LedgerTracer — Project Memory

Nguồn gốc: 3 tài liệu người dùng đưa (`uploads/Overview.md`, `uploads/Screen Map.md`, `uploads/DESIGN.md`).
Các chat sau KHÔNG cần paste lại file/skill. Nếu cần chi tiết đầy đủ, đọc lại 3 file trên.
Ngôn ngữ giao tiếp & mọi UI copy: **tiếng Việt**.

## 1. Sản phẩm (Overview.md)
LedgerTracer — công cụ **đối soát & phân tích giao dịch ngân hàng offline-first**, Flutter Web + Android.
Người dùng: DNNVV, quỹ, hộ kinh doanh có nhiều tài khoản ngân hàng.

Pain points: đối soát cuối kỳ bằng Excel; tra cứu 1 giao dịch trong lịch sử dài; phát hiện giao dịch **nội bộ trùng lặp** (chuyển giữa 2 tài khoản của cùng tổ chức → xuất hiện 2 lần).

Chức năng cốt lõi: import sao kê (**CSV / Excel .xlsx,.xls / MT940 / JSON** — KHÔNG PDF, là trade-off có chủ đích) · live search (tên, nội dung CK, khoảng tiền) · đối soát đa tài khoản (ghép cặp nội bộ) · thống kê dòng tiền.

Nguyên tắc: offline-first, dữ liệu chỉ trên thiết bị · **không phải phần mềm kế toán** (không hạch toán kép/hoá đơn/thuế) · **Tool không phải Service → KHÔNG có tài khoản người dùng, không đăng nhập, không đồng bộ** · dữ liệu demo là synthetic.

Case study: quyên góp cộng đồng quy mô hàng trăm nghìn GD; đối soát công nợ DNNVV; đối soát doanh thu sàn TMĐT theo NĐ 117/2025.

## 2. Screen Map (Screen Map.md)
Nav 4 ô (theo tần suất): **Giao dịch · Nhập · Đối soát · Thống kê**. Mobile = bottom nav; Web = nav rail dọc trái. Settings là icon bánh răng (mobile: AppBar phải; web: chân rail).

Màn hình:
- **App Shell**, **App Lock Screen** (PIN; native thêm sinh trắc học; "Quên PIN?" → dialog xoá toàn bộ dữ liệu, gõ chuỗi xác nhận)
- **Import Screen** = 1 route, 2 tab: *Nhập mới* (stepper 4 bước: Chọn file → Gán tài khoản (bắt buộc chặn) → Tiến trình (huỷ chỉ tại ranh giới lô; huỷ xong vẫn sang b4) → Tổng kết) và *Lịch sử* (hoàn tác theo file/nhóm; lượt đã huỷ/gián đoạn vẫn ở lại)
- **Transaction List Screen** (màn chính; gộp mọi tài khoản, cuộn lười, ngày giảm dần; Web two-pane, Mobile push detail) + **Filter Panel** (khoảng tiền/ngày/tài khoản/loại tiền, AND; mobile bottom sheet, web panel phải) + **Context Chips** ("Lượt nhập: <file>", "Không gồm chuyển khoản nội bộ") + **Transaction Detail** + **Edit Form** + **Delete Confirm**
- **Reconciliation Screen** (chạy + duyệt; Mobile thẻ vuốt, Web bảng 2 cột + nút) + **Segmented Control** *Chờ quyết định (n) / Đã xác nhận (n) / Đã từ chối (n)* (luôn hiện cả khi 0) + **Match Window Control** (matchWindowDays, không nằm trong Settings) + **Pair Detail** (2 vế + ứng viên thay thế) + **Rejection Snackbar** (có Hoàn tác) + empty state "chưa đủ 2 tài khoản"
- **Statistics Screen** (biểu đồ vào/ra theo tháng & theo tài khoản, tab loại tiền; công tắc loại trừ GD nội bộ **mặc định bật, không ghi nhớ**; drill-down sang Transaction List; Zero-effect Notice)
- **Settings** (3 nhóm: Tài khoản ngân hàng / Bảo mật / Dữ liệu) → **Account Management** (+ Account Form Dialog dùng lại ở Import b2) → **Backup & Restore** (mật khẩu file độc lập PIN)
- **Export Dialog** (CSV/Excel, 5 điểm vào, ghi mọi tiêu chí + Context Chip vào đầu file, nêu rõ file không mã hoá)
- **Web Degradation Indicator** (chỉ Web; nhúng vào Import b3 + Reconciliation)
- **Developer Diagnostics Screen** (vào từ mục ẩn cuối Settings; chạy workload theo chiến lược concurrency + batch size, đo thời gian/frame time/số lô)

Quy tắc: không màn hình nào riêng 1 nền tảng, trừ Web Degradation Indicator — khác biệt chỉ ở **hình thái**, không ở tập tính năng.
Thứ tự làm: Đợt 1 App Shell + Transaction List + Import(Nhập mới) + Diagnostics · Đợt 2 Reconciliation + Statistics + Lịch sử + Account Management · Đợt 3 Settings + App Lock + Backup&Restore.

## 3. Design System (DESIGN.md — tuân theo NGHIÊM NGẶT)
Nền gần trắng, **một accent indigo duy nhất**, hairline thay đổ bóng, bề mặt phẳng, **không gradient, không blur, không animation trang trí**.

Màu chính: primary `#533afd` · primary-deep `#4434d4` · primary-press `#2e2b8c` · primary-soft `#665efd` · primary-subdued `#b9b9f9` · primary-wash `#eeecff` · brand-dark-900 `#1c1e54` · dark-surface `#262a63` · dark-hairline `#33377a` · dark-ink-mute `#8e96c4`.
Chữ: ink `#0d253d` · ink-secondary `#273951` · ink-mute `#64748d` (chỉ trên canvas) · ink-mute-2 `#61718a` · on-primary `#fff`.
Bề mặt: canvas `#ffffff` (chrome) · canvas-soft `#f6f9fc` (bảng/list/rail) · canvas-cream `#f5e9d4` · cream-wash `#fdf7ec` · ruby-wash `#fdecef` · hairline `#e3e8ee` · hairline-input `#a8c3de` (đường kẻ cấu trúc) · hairline-control `#6594c4` (viền phần tử tương tác) · shadow-blue `#003770`.
Ngữ nghĩa: verdant `#0e6245` (tiền vào/đã xác nhận) · verdant-soft `#cbf4c9` · ruby `#ea2261` (đồ hoạ) · ruby-ink `#d61452` (chữ đỏ) · lemon `#9b6829` · lemon-ink `#8f6026` · magenta `#f96bee` (chart Diagnostics).

Typography: Sohne → thay bằng **Inter** (Google Fonts). Display tier ≥26px luôn **weight 300 + tracking âm** (56/-1.4 · 48/-0.96 · 32/-0.64 · 26/-0.26). Body weight 400+ (dấu tiếng Việt). `ss01` toàn cục, `tnum` mọi phần tử số. body-tabular 14px/w500/-0.42px cho ô tiền. mono-log = JetBrains Mono 12px cho log Diagnostics. Sàn 11px, chỉ cho pill viết hoa. Line-height ≥1.4.

Hình học: radius xs4 sm6 md8 lg12 xl16 pill9999. Spacing 2/4/8/12/16/24/32/64. Nút pill padding 8px 16px, **tối đa 1 nút filled/màn**.
Density: Web row 36px, card 16px, touch min 32px · Mobile row 52px, card 24px, touch min 48px. Screen padding 16px mọi breakpoint.
Elevation: 0 = phẳng + viền 1px hairline (mặc định) · 1 = `0 1px 3px rgba(0,55,112,.08)` (menu, snackbar) · 2 = `0 8px 24px rgba(0,55,112,.08), 0 2px 6px rgba(0,55,112,.04)` (dialog, bottom sheet).

**Ba kênh ngữ nghĩa tách bằng HÌNH DẠNG, không bằng hue:**
- Hướng tiền = chữ màu, căn phải, **luôn hiện dấu + / −**, không nền
- Trạng thái verdict = pill có nền, **không icon** (Gợi ý cream/lemon-ink · Đã xác nhận verdant-soft/verdant · Đã từ chối hairline/ink-secondary)
- Phản hồi hệ thống = banner full-width, **luôn có icon**, viền trái 3px (warning/danger/info/success)
- Nhãn phân loại = pill viền không nền, có icon (`badge-internal` icon ⇄)

Bảng: header nền canvas-soft, micro-cap in hoa, gạch chân 1px hairline-input, dính đỉnh. Row nền canvas-soft, kẻ 1px hairline, **1px hairline-input mỗi 5 dòng**. Row selected nền primary-wash + chỉ báo dọc 3px primary. Không nền xen kẽ dòng, không viền dọc cột, không cột căn giữa.

**Frame Pulse** — phần tử chuyển động DUY NHẤT: dải 12 vạch 3×12px cách 3px cạnh progress-bar, con trỏ sáng tiến 1 vạch / 2 frame, vạch sáng = primary đặc, còn lại hairline-input. Do Ticker điều khiển (không theo tiến độ dữ liệu) → khựng lại khi UI thread bị chặn = tín hiệu quan sát được. Xuất hiện ở Import b3, Reconciliation đang chạy, Diagnostics; bản 6 vạch thu nhỏ trên app bar khi chuyển tab.
Progress bar: cao 4px, rãnh hairline, thanh primary, nhãn caption dạng `1.240 / 3.000`.

Breakpoints: Expanded ≥1024 (rail có nhãn, đủ cột, panel chi tiết phải, số tổng 56px) · Medium 600–1023 (rail chỉ icon, số tổng 48px) · Compact <600 (bottom nav, list dạng card, số tổng 32px).

Don't: weight 300 ở cỡ body · gradient/blur/animation trang trí · nút tô ruby/verdant đặc · tô nền cả dòng theo hướng tiền · primary làm màu chữ body · thêm màu mới · chữ <12px · padding nút <8px16px · nút chữ nhật bo góc.

## 4. Codebase (github.md)
Repo `VuThanh2/LedgerTracer` (Flutter, branch main) — hiện là **scaffold rỗng**: mọi file trong `lib/` 0 byte trừ `lib/main.dart`. Cấu trúc là Clean Architecture + BLoC: `lib/{app,application,core,domain,infrastructure,presentation}`; presentation có page + bloc theo feature và `shared/widgets/{money_text,empty_state,progress_panel,currency_tab_bar,web_limitation_banner}`. Không có UI để recreate → design xuất phát từ DESIGN.md, và đặt tên khớp cấu trúc repo.
