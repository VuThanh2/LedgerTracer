---
name: LedgerTracer-design-system
description: "Ngôn ngữ thiết kế của LedgerTracer, một công cụ đối soát sao kê ngân hàng offline-first chạy trên Flutter Web và Android. Hệ thống xây trên một nền trung tính gần trắng, một accent indigo duy nhất trung tính về ngữ nghĩa, và viền hairline thay cho đổ bóng. Chữ dùng Sohne ở weight 300 cho display tier với tracking âm, và tabular figures cho mọi ô số vì bảng giao dịch là màn hình chính của sản phẩm. Bề mặt phẳng tuyệt đối, không gradient và không blur, vì đây là công cụ làm việc dày dữ liệu và vì bản thân độ mượt khung hình là dữ liệu mà ứng dụng cần trưng ra."

colors:
  primary: "#533afd"
  primary-deep: "#4434d4"
  primary-press: "#2e2b8c"
  primary-soft: "#665efd"
  primary-bg-subdued-hover: "#b9b9f9"
  primary-wash: "#eeecff"
  brand-dark-900: "#1c1e54"
  dark-surface: "#262a63"
  dark-hairline: "#33377a"
  dark-ink-mute: "#8e96c4"
  ink: "#0d253d"
  ink-secondary: "#273951"
  ink-mute: "#64748d"
  ink-mute-2: "#61718a"
  on-primary: "#ffffff"
  canvas: "#ffffff"
  canvas-soft: "#f6f9fc"
  canvas-cream: "#f5e9d4"
  cream-wash: "#fdf7ec"
  hairline: "#e3e8ee"
  hairline-input: "#a8c3de"
  hairline-control: "#6594c4"
  shadow-blue: "#003770"
  ruby-ink: "#d61452"
  lemon-ink: "#8f6026"
  verdant: "#0e6245"
  verdant-soft: "#cbf4c9"
  ruby: "#ea2261"
  ruby-wash: "#fdecef"
  magenta: "#f96bee"
  lemon: "#9b6829"

typography:
  display-xxl:
    fontFamily: "sohne-var, 'SF Pro Display', system-ui, -apple-system, sans-serif"
    fontSize: 56px
    fontWeight: 300
    lineHeight: 1.03
    letterSpacing: -1.4px
    fontFeature: ss01
  display-xl:
    fontFamily: "sohne-var, 'SF Pro Display', system-ui, -apple-system, sans-serif"
    fontSize: 48px
    fontWeight: 300
    lineHeight: 1.15
    letterSpacing: -0.96px
    fontFeature: ss01
  display-lg:
    fontFamily: "sohne-var, 'SF Pro Display', system-ui, -apple-system, sans-serif"
    fontSize: 32px
    fontWeight: 300
    lineHeight: 1.1
    letterSpacing: -0.64px
    fontFeature: ss01
  display-md:
    fontFamily: "sohne-var, 'SF Pro Display', system-ui, -apple-system, sans-serif"
    fontSize: 26px
    fontWeight: 300
    lineHeight: 1.12
    letterSpacing: -0.26px
    fontFeature: ss01
  heading-lg:
    fontFamily: "sohne-var, 'SF Pro Display', system-ui, -apple-system, sans-serif"
    fontSize: 22px
    fontWeight: 400
    lineHeight: 1.2
    letterSpacing: -0.22px
    fontFeature: ss01
  heading-md:
    fontFamily: "sohne-var, 'SF Pro Display', system-ui, -apple-system, sans-serif"
    fontSize: 20px
    fontWeight: 400
    lineHeight: 1.4
    letterSpacing: -0.2px
    fontFeature: ss01
  heading-sm:
    fontFamily: "sohne-var, 'SF Pro Display', system-ui, -apple-system, sans-serif"
    fontSize: 18px
    fontWeight: 500
    lineHeight: 1.4
    letterSpacing: 0
    fontFeature: ss01
  body-lg:
    fontFamily: "sohne-var, 'SF Pro Display', system-ui, -apple-system, sans-serif"
    fontSize: 16px
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: 0
    fontFeature: ss01
  body-md:
    fontFamily: "sohne-var, 'SF Pro Display', system-ui, -apple-system, sans-serif"
    fontSize: 15px
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: 0
    fontFeature: ss01
  body-sm:
    fontFamily: "sohne-var, 'SF Pro Display', system-ui, -apple-system, sans-serif"
    fontSize: 13px
    fontWeight: 400
    lineHeight: 1.45
    letterSpacing: 0
    fontFeature: ss01
  body-tabular:
    fontFamily: "sohne-var, 'SF Pro Display', system-ui, -apple-system, sans-serif"
    fontSize: 14px
    fontWeight: 500
    lineHeight: 1.45
    letterSpacing: -0.42px
    fontFeature: tnum
  tabular-lg:
    fontFamily: "sohne-var, 'SF Pro Display', system-ui, -apple-system, sans-serif"
    fontSize: 26px
    fontWeight: 400
    lineHeight: 1.15
    letterSpacing: -0.5px
    fontFeature: tnum
  button-md:
    fontFamily: "sohne-var, 'SF Pro Display', system-ui, -apple-system, sans-serif"
    fontSize: 16px
    fontWeight: 400
    lineHeight: 1.0
    letterSpacing: 0
    fontFeature: ss01
  button-sm:
    fontFamily: "sohne-var, 'SF Pro Display', system-ui, -apple-system, sans-serif"
    fontSize: 14px
    fontWeight: 400
    lineHeight: 1.0
    letterSpacing: 0
    fontFeature: ss01
  caption:
    fontFamily: "sohne-var, 'SF Pro Display', system-ui, -apple-system, sans-serif"
    fontSize: 13px
    fontWeight: 400
    lineHeight: 1.4
    letterSpacing: -0.39px
    fontFeature: tnum
  micro:
    fontFamily: "sohne-var, 'SF Pro Display', system-ui, -apple-system, sans-serif"
    fontSize: 12px
    fontWeight: 400
    lineHeight: 1.4
    letterSpacing: 0
    fontFeature: ss01
  micro-cap:
    fontFamily: "sohne-var, 'SF Pro Display', system-ui, -apple-system, sans-serif"
    fontSize: 11px
    fontWeight: 500
    lineHeight: 1.2
    letterSpacing: 0.3px
    fontFeature: ss01
  mono-log:
    fontFamily: "'JetBrains Mono', ui-monospace, monospace"
    fontSize: 12px
    fontWeight: 400
    lineHeight: 1.55
    letterSpacing: 0
    fontFeature: zero

rounded:
  xs: 4px
  sm: 6px
  md: 8px
  lg: 12px
  xl: 16px
  pill: 9999px

spacing:
  xxs: 2px
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 24px
  xxl: 32px
  huge: 64px

density:
  row-compact: 36px
  row-touch: 52px
  cell-padding-x: 12px
  cell-padding-y: 8px
  card-padding-compact: 16px
  card-padding-touch: 24px
  screen-padding: 16px
  touch-target-min: 48px

components:
  button-primary-pill:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.button-md}"
    rounded: "{rounded.pill}"
    padding: 8px 16px
  button-primary-pill-pressed:
    backgroundColor: "{colors.primary-press}"
    textColor: "{colors.on-primary}"
    typography: "{typography.button-md}"
    rounded: "{rounded.pill}"
    padding: 8px 16px
  button-secondary:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.primary}"
    typography: "{typography.button-md}"
    rounded: "{rounded.pill}"
    padding: 8px 16px
  button-destructive:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.ruby-ink}"
    typography: "{typography.button-sm}"
    rounded: "{rounded.pill}"
    padding: 8px 16px
  button-on-dark:
    backgroundColor: "{colors.brand-dark-900}"
    textColor: "{colors.on-primary}"
    typography: "{typography.button-md}"
    rounded: "{rounded.pill}"
    padding: 8px 16px
  text-input:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.ink}"
    typography: "{typography.body-md}"
    rounded: "{rounded.sm}"
    padding: 8px 12px
  text-input-focused:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.ink}"
    typography: "{typography.body-md}"
    rounded: "{rounded.sm}"
    padding: 8px 12px
  card-surface:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.ink}"
    typography: "{typography.body-md}"
    rounded: "{rounded.md}"
    padding: 16px
  table-header:
    backgroundColor: "{colors.canvas-soft}"
    textColor: "{colors.ink-secondary}"
    typography: "{typography.micro-cap}"
    rounded: "0px"
    padding: 8px 12px
  table-row:
    backgroundColor: "{colors.canvas-soft}"
    textColor: "{colors.ink}"
    typography: "{typography.body-sm}"
    rounded: "0px"
    padding: 8px 12px
  table-row-selected:
    backgroundColor: "{colors.primary-wash}"
    textColor: "{colors.ink}"
    typography: "{typography.body-sm}"
    rounded: "0px"
    padding: 8px 12px
  money-cell-in:
    backgroundColor: "transparent"
    textColor: "{colors.verdant}"
    typography: "{typography.body-tabular}"
    rounded: "0px"
    padding: 0px
  money-cell-out:
    backgroundColor: "transparent"
    textColor: "{colors.ruby-ink}"
    typography: "{typography.body-tabular}"
    rounded: "0px"
    padding: 0px
  pill-pending:
    backgroundColor: "{colors.canvas-cream}"
    textColor: "{colors.lemon-ink}"
    typography: "{typography.micro-cap}"
    rounded: "{rounded.pill}"
    padding: 4px 8px
  pill-confirmed:
    backgroundColor: "{colors.verdant-soft}"
    textColor: "{colors.verdant}"
    typography: "{typography.micro-cap}"
    rounded: "{rounded.pill}"
    padding: 4px 8px
  pill-rejected:
    backgroundColor: "{colors.hairline}"
    textColor: "{colors.ink-secondary}"
    typography: "{typography.micro-cap}"
    rounded: "{rounded.pill}"
    padding: 4px 8px
  pill-tag-soft:
    backgroundColor: "{colors.primary-bg-subdued-hover}"
    textColor: "{colors.primary-press}"
    typography: "{typography.micro-cap}"
    rounded: "{rounded.pill}"
    padding: 4px 8px
  badge-internal:
    backgroundColor: "transparent"
    textColor: "{colors.ink-secondary}"
    typography: "{typography.micro-cap}"
    rounded: "{rounded.pill}"
    padding: 3px 7px
  chip-filter:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.ink-secondary}"
    typography: "{typography.micro}"
    rounded: "{rounded.pill}"
    padding: 5px 10px
  banner-warning:
    backgroundColor: "{colors.cream-wash}"
    textColor: "{colors.lemon-ink}"
    typography: "{typography.body-sm}"
    rounded: "{rounded.md}"
    padding: 12px
  banner-danger:
    backgroundColor: "{colors.ruby-wash}"
    textColor: "{colors.ruby-ink}"
    typography: "{typography.body-sm}"
    rounded: "{rounded.md}"
    padding: 12px
  banner-info:
    backgroundColor: "{colors.primary-wash}"
    textColor: "{colors.primary-deep}"
    typography: "{typography.body-sm}"
    rounded: "{rounded.md}"
    padding: 12px
  banner-success:
    backgroundColor: "{colors.verdant-soft}"
    textColor: "{colors.verdant}"
    typography: "{typography.body-sm}"
    rounded: "{rounded.md}"
    padding: 12px
  row-account-select:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.ink}"
    typography: "{typography.body-md}"
    rounded: "{rounded.md}"
    padding: 14px 12px
  card-pair-swipe:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.ink}"
    typography: "{typography.body-md}"
    rounded: "{rounded.lg}"
    padding: 16px
  segmented-control:
    backgroundColor: "{colors.canvas-soft}"
    textColor: "{colors.ink-secondary}"
    typography: "{typography.micro}"
    rounded: "{rounded.md}"
    padding: 3px
  progress-bar:
    backgroundColor: "{colors.hairline}"
    textColor: "{colors.primary}"
    typography: "{typography.caption}"
    rounded: "{rounded.pill}"
    padding: 0px
  frame-pulse:
    backgroundColor: "transparent"
    textColor: "{colors.primary}"
    typography: "{typography.micro-cap}"
    rounded: "{rounded.xs}"
    padding: 0px
  empty-state:
    backgroundColor: "{colors.canvas-soft}"
    textColor: "{colors.ink-secondary}"
    typography: "{typography.body-md}"
    rounded: "{rounded.md}"
    padding: 32px 16px
  nav-rail-web:
    backgroundColor: "{colors.canvas-soft}"
    textColor: "{colors.ink-secondary}"
    typography: "{typography.body-sm}"
    rounded: "0px"
    padding: 12px 8px
  nav-bar-mobile:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.ink-mute-2}"
    typography: "{typography.micro-cap}"
    rounded: "0px"
    padding: 8px 0px
  app-bar:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.ink}"
    typography: "{typography.heading-sm}"
    rounded: "0px"
    padding: 0px 16px
  dialog:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.ink}"
    typography: "{typography.body-md}"
    rounded: "{rounded.lg}"
    padding: 24px
  snackbar:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.on-primary}"
    typography: "{typography.body-sm}"
    rounded: "{rounded.md}"
    padding: 12px 16px
  link-on-light:
    backgroundColor: "transparent"
    textColor: "{colors.primary}"
    typography: "{typography.body-md}"
    rounded: "{rounded.xs}"
    padding: 0px
  diag-panel:
    backgroundColor: "{colors.dark-surface}"
    textColor: "{colors.on-primary}"
    typography: "{typography.mono-log}"
    rounded: "{rounded.md}"
    padding: 12px
  diag-metric:
    backgroundColor: "{colors.dark-surface}"
    textColor: "{colors.primary-bg-subdued-hover}"
    typography: "{typography.tabular-lg}"
    rounded: "{rounded.md}"
    padding: 16px
---

## Overview

Ngôn ngữ thiết kế của LedgerTracer bắt đầu từ bảng dữ liệu. Người dùng là kế toán và người quản lý quỹ, ngồi trước một danh sách vài nghìn giao dịch, quét mắt theo cột, và cần trả lời một câu hỏi cụ thể càng nhanh càng tốt. Mọi bề mặt trong hệ thống đều phục vụ hành động đó: nền gần như không màu, khoảng cách hẹp, và màu chỉ xuất hiện ở nơi mang nghĩa nghiệp vụ.

Bảng màu có hai vai trò chính. **Indigo** (`{colors.primary}` — `#533afd`) là accent duy nhất của hệ thống, dùng tiết chế với đúng một nút filled trên mỗi màn hình. **Deep navy** (`{colors.ink}` — `#0d253d`) là màu chữ toàn hệ thống và là nền của snackbar. Ba accent phụ mang nghĩa nghiệp vụ cố định: `{colors.verdant}` cho tiền vào và trạng thái đã xác nhận, `{colors.ruby}` cho tiền ra và hành động phá huỷ, `{colors.lemon}` cho cảnh báo. Chúng không bao giờ là màu nút.

Chữ dựng quanh **Sohne** ở weight 300 với tracking âm cho display tier — 56px ở tracking -1.4px thu dần xuống -0.2px ở 20px. Chữ nội dung dùng weight 400 để giữ nét cho dấu tiếng Việt ở cỡ nhỏ. Mọi ô số, từ tiền tới ngày tới thời gian đo, dùng OpenType `tnum` để cột thẳng hàng tuyệt đối. Bộ ký tự `ss01` bật toàn cục.

**Đặc trưng:**
- Vùng dữ liệu chìm nhẹ trên `{colors.canvas-soft}` trong khi chrome giữ trắng `{colors.canvas}` — bảng tách khỏi khung ứng dụng mà không cần thêm đường viền nào.
- Đường kẻ sổ cái: hairline nhạt giữa mọi dòng, `{colors.hairline-input}` cứ mỗi 5 dòng, giúp mắt bám hàng khi cuộn qua nghìn dòng.
- Ba kênh màu tách nhau bằng hình dạng chứ không bằng hue — tiền là chữ màu căn phải, trạng thái là pill có nền, phản hồi là banner có icon.
- Bề mặt phẳng tuyệt đối: mặc định là elevation 0 cộng viền 1px. Đổ bóng chỉ tồn tại ở menu nổi và dialog.
- Nút hình pill (`{rounded.pill}`) với padding chặt `8px 16px`, ngắn và dứt khoát.
- Density khác nhau theo nền tảng vì tác vụ khác nhau, không vì kích thước màn.
- **Frame Pulse** — dải vạch chuyển động theo Ticker cạnh mỗi thanh tiến độ. Đây là phần tử chuyển động duy nhất của hệ thống và nó tồn tại vì lý do chức năng.

## Colors

### Brand & Accent
- **Indigo** (`{colors.primary}` — `#533afd`): accent của hệ thống. Nút filled, link, thanh tiến độ, chỉ báo dòng đang chọn.
- **Indigo Deep** (`{colors.primary-deep}` — `#4434d4`): chữ trên nền indigo nhạt — banner thông tin, chip đang bật, ô nav đang chọn.
- **Indigo Press** (`{colors.primary-press}` — `#2e2b8c`): trạng thái nhấn của nút filled.
- **Indigo Soft** (`{colors.primary-soft}` — `#665efd`): hover, chỉ báo phụ, điểm nhấn trong biểu đồ.
- **Indigo Subdued** (`{colors.primary-bg-subdued-hover}` — `#b9b9f9`): nền tag mềm và Context Chip; đồng thời là màu số đo trên nền tối.
- **Indigo Wash** (`{colors.primary-wash}` — `#eeecff`): nền dòng đang chọn và nền banner thông tin.
- **Brand Dark 900** (`{colors.brand-dark-900}` — `#1c1e54`): nền màn Developer Diagnostics.
- **Verdant** (`{colors.verdant}` — `#0e6245`): tiền vào, trạng thái đã xác nhận. Không bao giờ là màu nút.
- **Verdant Soft** (`{colors.verdant-soft}` — `#cbf4c9`): nền pill xác nhận và banner thành công.
- **Ruby** (`{colors.ruby}` — `#ea2261`): điểm nhấn cho hướng tiền ra trong biểu đồ và chỉ báo đồ hoạ. Không bao giờ là màu nút.
- **Ruby Ink** (`{colors.ruby-ink}` — `#d61452`): biến thể tối hơn dùng cho **chữ** — ô tiền ra, nút phá huỷ, banner nguy hiểm. Ruby ở dạng chữ nhỏ không đạt tương phản 4.5:1 trên nền sáng, nên mọi chữ màu đỏ dùng token này.
- **Magenta** (`{colors.magenta}` — `#f96bee`): series biểu đồ ở màn Diagnostics.
- **Lemon** (`{colors.lemon}` — `#9b6829`): điểm nhấn hổ phách cho chỉ báo đồ hoạ.
- **Lemon Ink** (`{colors.lemon-ink}` — `#8f6026`): biến thể tối hơn dùng cho **chữ** cảnh báo trên nền cream.

### Surface
- **Canvas** (`{colors.canvas}` — `#ffffff`): chrome — app bar, dialog, card, panel.
- **Canvas Soft** (`{colors.canvas-soft}` — `#f6f9fc`): vùng bảng và danh sách, nav rail, rãnh segmented control.
- **Canvas Cream** (`{colors.canvas-cream}` — `#f5e9d4`): nền pill trạng thái Gợi ý.
- **Cream Wash** (`{colors.cream-wash}` — `#fdf7ec`): nền banner cảnh báo.
- **Ruby Wash** (`{colors.ruby-wash}` — `#fdecef`): nền banner nguy hiểm.
- **Hairline** (`{colors.hairline}` — `#e3e8ee`): viền card, kẻ giữa các dòng bảng, nền pill Đã từ chối.
- **Hairline Input** (`{colors.hairline-input}` — `#a8c3de`): gạch chân header bảng, đường kẻ đậm mỗi 5 dòng, icon trang trí ở màn trống. Chỉ dùng cho đường kẻ cấu trúc, không dùng cho viền phần tử tương tác.
- **Hairline Control** (`{colors.hairline-control}` — `#6594c4`): viền ô nhập, chip lọc, badge. Đậm hơn `{colors.hairline-input}` để đạt tối thiểu 3:1 so với nền, mức bắt buộc để nhận diện được ranh giới của phần tử tương tác.
- **Dark Surface** (`{colors.dark-surface}` — `#262a63`): panel bên trong màn Diagnostics.
- **Dark Hairline** (`{colors.dark-hairline}` — `#33377a`): viền panel trên nền tối.
- **Shadow Blue** (`{colors.shadow-blue}` — `#003770`): màu gốc của mọi đổ bóng.

### Text
- **Ink** (`{colors.ink}` — `#0d253d`): màu chữ mặc định. Deep navy, không bao giờ đen tuyền. Đồng thời là nền snackbar.
- **Ink Secondary** (`{colors.ink-secondary}` — `#273951`): chữ phụ, nhãn trong card, badge phân loại, header cột, chữ pill Đã từ chối.
- **Ink Mute** (`{colors.ink-mute}` — `#64748d`): helper và chữ giữ chỗ. Chỉ đặt trên `{colors.canvas}`; trên `{colors.canvas-soft}` nó không đạt 4.5:1 nên dùng `{colors.ink-secondary}`.
- **Ink Mute 2** (`{colors.ink-mute-2}` — `#61718a`): nhãn nav chưa chọn.
- **Dark Ink Mute** (`{colors.dark-ink-mute}` — `#8e96c4`): nhãn phụ trên nền tối.
- **On Primary** (`{colors.on-primary}` — `#ffffff`): chữ trên nền indigo và navy.

### Semantic

Hệ thống có ba kênh ngữ nghĩa. Chúng dùng chung một số hue nhưng **không bao giờ bị đọc nhầm, vì mỗi kênh có hình dạng và vị trí riêng**.

| Kênh | Hình thức bắt buộc |
|---|---|
| Hướng tiền | Chữ màu, căn phải, không nền, dấu luôn hiện |
| Trạng thái verdict | Pill có nền nhạt, căn trái, **không icon** |
| Phản hồi hệ thống | Banner full-width, **luôn có icon**, viền trái 3px |
| Nhãn phân loại | Pill viền không nền, có icon |

**Hướng tiền** — `{colors.verdant}` cho tiền vào, `{colors.ruby-ink}` cho tiền ra. Dấu `+` và `−` luôn hiển thị và là tín hiệu chính; màu là lớp thông tin thứ hai. Khoảng 8% nam giới không phân biệt được đỏ với lục, và quy ước màu tài chính Việt Nam không thống nhất với phương Tây, nên màu một mình không đủ mang nghĩa.

**Trạng thái verdict** — ba trạng thái của một cặp đối soát:

| Trạng thái | Nền | Chữ |
|---|---|---|
| Gợi ý | `{colors.canvas-cream}` | `{colors.lemon-ink}` |
| Đã xác nhận | `{colors.verdant-soft}` | `{colors.verdant}` |
| Đã từ chối | `{colors.hairline}` | `{colors.ink-secondary}` |

Trạng thái Đã từ chối dùng xám trung tính: từ chối là một phán quyết hợp lệ của người dùng, không phải sự cố.

**Phản hồi hệ thống** — bốn banner:

| Vai trò | Nền | Chữ | Nơi dùng |
|---|---|---|---|
| Cảnh báo | `{colors.cream-wash}` | `{colors.lemon-ink}` | Giới hạn xử lý trên Web, lệch số tài khoản khi nhập |
| Nguy hiểm | `{colors.ruby-wash}` | `{colors.ruby-ink}` | Hoàn tác nhập, xoá tài khoản, xoá dữ liệu khi quên PIN |
| Thông tin | `{colors.primary-wash}` | `{colors.primary-deep}` | Thông báo bộ lọc không thay đổi kết quả |
| Thành công | `{colors.verdant-soft}` | `{colors.verdant}` | Nhập xong, khôi phục xong |

## Typography

### Font Family

Display và UI tier dùng **Sohne** (bản quyền của Klim Type Foundry) ở weight 300 và 400. Font biến thiên (`sohne-var`) được nạp với `font-feature-settings: "ss01"` bật toàn cục.

Chữ số dùng OpenType `tnum` ở mọi vai trò có số. Log của màn Diagnostics dùng **JetBrains Mono** với `zero` để phân biệt chữ số không và chữ O trong chuỗi định danh.

### Hierarchy

| Token | Cỡ | Weight | Line Height | Tracking | Dùng ở |
|---|---|---|---|---|---|
| `{typography.display-xxl}` | 56px | 300 | 1.03 | -1.4px | Số tổng chính ở Thống kê, breakpoint Expanded |
| `{typography.display-xl}` | 48px | 300 | 1.15 | -0.96px | Số tổng chính ở Thống kê, breakpoint Medium |
| `{typography.display-lg}` | 32px | 300 | 1.1 | -0.64px | Tiêu đề màn hình trên web, số tổng phụ |
| `{typography.display-md}` | 26px | 300 | 1.12 | -0.26px | Tiêu đề bước trong luồng Nhập, màn trống |
| `{typography.heading-lg}` | 22px | 400 | 1.2 | -0.22px | Tiêu đề dialog |
| `{typography.heading-md}` | 20px | 400 | 1.4 | -0.2px | Tiêu đề section |
| `{typography.heading-sm}` | 18px | 500 | 1.4 | 0 | App bar, tiêu đề card |
| `{typography.body-lg}` | 16px | 400 | 1.5 | 0 | Chữ dẫn trong dialog và màn trống |
| `{typography.body-md}` | 15px | 400 | 1.5 | 0 | Chữ mặc định |
| `{typography.body-sm}` | 13px | 400 | 1.45 | 0 | Ô chữ trong bảng |
| `{typography.body-tabular}` | 14px | 500 | 1.45 | -0.42px | Ô tiền (`tnum`) |
| `{typography.tabular-lg}` | 26px | 400 | 1.15 | -0.5px | Số đo ở Diagnostics (`tnum`) |
| `{typography.caption}` | 13px | 400 | 1.4 | -0.39px | Helper, ngày, số tài khoản (`tnum`) |
| `{typography.micro}` | 12px | 400 | 1.4 | 0 | Chip lọc, chú thích |
| `{typography.micro-cap}` | 11px | 500 | 1.2 | +0.3px | Header cột, nhãn pill, nhãn nav |
| `{typography.mono-log}` | 12px | 400 | 1.55 | 0 | Log ở Diagnostics |

### Principles

- **Weight 300 là chữ ký của display tier.** Các cỡ 26px trở lên luôn render ở weight 300; nâng lên 400 làm mất chất editorial của hệ thống.
- **Tracking âm trên display.** -1.4px ở 56px, giảm theo tỉ lệ xuống -0.26px ở 26px. Đây là dấu ấn typographic.
- **Chữ nội dung dùng weight 400 trở lên.** Ở cỡ 13–16px, weight 300 làm các dấu chồng tiếng Việt (`ộ`, `ữ`, `ế`) mất nét, và mất hẳn khi nội dung được ghi hình rồi nén.
- **Tabular figures cho mọi con số**, không chỉ tiền: ngày, số tài khoản, số dòng, thời gian đo. Cột lệch một pixel là mất khả năng quét dọc.
- **Số tiền nặng hơn chữ xung quanh một bậc** — `{typography.body-tabular}` ở weight 500. Nó là thứ mắt tìm.
- **Sàn line-height 1.4** cho mọi dòng chứa tiếng Việt; bảng và chữ nội dung dùng 1.45–1.5. Dấu chồng cần thêm chiều cao trên và dưới so với văn bản Latin.
- **Sàn cỡ chữ 11px, và 11px chỉ dành cho nhãn pill viết hoa.** Mật độ đạt được bằng cách giảm chiều cao dòng và padding, không bằng cách thu nhỏ chữ.
- **`ss01` toàn cục** trên phần tử gốc; `tnum` áp theo từng phần tử số.
- **Indigo không phải màu chữ ở cỡ nội dung.** Nó là màu CTA và link.
- **Viền của phần tử tương tác đạt tối thiểu 3:1** so với nền, dùng `{colors.hairline-control}`. Đường kẻ cấu trúc thuần trang trí không chịu ràng buộc này.
- **Mọi cặp chữ trên nền đạt tối thiểu 4.5:1.** Các accent ngữ nghĩa có hai dạng: dạng gốc dùng cho chỉ báo đồ hoạ, và dạng `-ink` tối hơn dùng cho chữ. Không dùng dạng gốc làm màu chữ ở bất kỳ cỡ nào.

### Note on Font Substitutes

Sohne là font thương mại. Thay thế bằng **Inter** (mã nguồn mở, có trên Google Fonts) ở weight 300 cho display tier với `letter-spacing` giữ nguyên, và weight 400–500 cho chữ nội dung. Inter hỗ trợ đầy đủ bộ dấu tiếng Việt, kể cả các tổ hợp dấu chồng, và có `tnum`. Tránh Helvetica và system-ui mặc định: chúng nặng hơn mức hệ thống cần và xử lý dấu tiếng Việt kém hơn ở cỡ nhỏ.

## Layout

### Spacing System
- **Đơn vị cơ sở**: 8px, với các token phụ 2 / 4 / 12px cho công việc tinh.
- **Token**: `{spacing.xxs}` 2px · `{spacing.xs}` 4px · `{spacing.sm}` 8px · `{spacing.md}` 12px · `{spacing.lg}` 16px · `{spacing.xl}` 24px · `{spacing.xxl}` 32px · `{spacing.huge}` 64px.
- **Padding màn hình**: `{density.screen-padding}` 16px trên mọi breakpoint.
- **Padding card**: 16px ở density compact, 24px ở density touch.
- **Ô bảng**: `{density.cell-padding-y}` 8px dọc, `{density.cell-padding-x}` 12px ngang.
- `{spacing.huge}` chỉ dùng cho khoảng nghỉ dọc ở màn trống và màn Thống kê.

### Density

Density khác nhau theo **tác vụ**, không theo kích thước màn. Web là nơi nhập hàng loạt và đối soát cuối kỳ, người dùng đang so sánh nên cần nhiều dòng cùng lúc. Mobile là nơi tra cứu nhanh và vuốt xác nhận, thao tác chính là chạm.

| | Web | Mobile |
|---|---|---|
| Chiều cao dòng | `{density.row-compact}` 36px | `{density.row-touch}` 52px |
| Padding card | `{density.card-padding-compact}` 16px | `{density.card-padding-touch}` 24px |
| `VisualDensity` | `compact` | `standard` |
| Vùng chạm tối thiểu | 32px | `{density.touch-target-min}` 48px |

### Grid & Container

- Bảng dùng lưới cột tự do theo nội dung: cột tiền căn phải, cột chữ căn trái, không cột nào căn giữa.
- Không có viền dọc giữa các cột; khoảng cách làm nhiệm vụ phân tách.
- Header bảng dính đỉnh khi cuộn, gạch chân 1px `{colors.hairline-input}`.
- Kẻ giữa các dòng 1px `{colors.hairline}`, và 1px `{colors.hairline-input}` cứ mỗi 5 dòng.
- Không dùng nền xen kẽ theo dòng: nó cạnh tranh với nền dòng đang chọn và làm pill trạng thái khó đọc.
- Ở breakpoint Expanded, panel chi tiết mở bên phải thay vì điều hướng sang màn khác.

### Whitespace Philosophy

Đây là sản phẩm dày dữ liệu, nên khoảng trắng là chi phí chứ không phải sự sang trọng. Khoảng cách giữa các khối giữ ở 16px, nới lên 24px ở density touch. Khoảng trắng lớn chỉ xuất hiện ở hai nơi: màn trống, và vùng số tổng của màn Thống kê — cả hai đều là nơi người dùng dừng lại thay vì quét.

## Elevation & Depth

| Level | Xử lý | Dùng ở |
|---|---|---|
| 0 | Phẳng, viền 1px `{colors.hairline}` | Mặc định cho card, panel, bảng |
| 1 | `box-shadow: rgba(0,55,112,0.08) 0 1px 3px` | Menu thả xuống, snackbar, nhóm đang chọn trong segmented control |
| 2 | `box-shadow: rgba(0,55,112,0.08) 0 8px 24px, rgba(0,55,112,0.04) 0 2px 6px` | Dialog, bottom sheet |

### Render Performance

Ứng dụng xử lý hàng chục nghìn giao dịch trong tiến trình nền và trưng ra chính độ mượt khung hình như một thuộc tính sản phẩm. Vì vậy bề mặt không được tự tiêu tốn ngân sách render:

| Không dùng | Lý do |
|---|---|
| Gradient động, nền chuyển màu diện rộng | Repaint mỗi frame |
| `BackdropFilter` và mọi hiệu ứng blur | Chi phí rất cao trên CanvasKit, là nền tảng chính của bản web |
| Đổ bóng vượt level 2 | Chi phí raster mỗi lần cuộn bảng dài |
| Animation trang trí chạy song song với xử lý nền | Che lấp tín hiệu thật về độ mượt |
| `Opacity` widget trên nhánh widget lớn | Ép `saveLayer`; dùng `Color.withValues(alpha:)` thay thế |

Bắt buộc: danh sách dài dùng `ListView.builder` hoặc `SliverList`, không dựng toàn bộ; `RepaintBoundary` bao quanh Frame Pulse.

## Shapes

### Border Radius Scale

| Token | Giá trị | Dùng ở |
|---|---|---|
| `{rounded.xs}` | 4px | Link, phần tử nhỏ |
| `{rounded.sm}` | 6px | Ô nhập |
| `{rounded.md}` | 8px | Card, banner, segmented control, panel Diagnostics |
| `{rounded.lg}` | 12px | Dialog, thẻ cặp đối soát |
| `{rounded.xl}` | 16px | Bottom sheet |
| `{rounded.pill}` | 9999px | Nút, pill trạng thái, badge, chip |

## Components

### Buttons

**`button-primary-pill`** — nút chính của hệ thống.
- Nền `{colors.primary}`, chữ `{colors.on-primary}`, kiểu chữ `{typography.button-md}`, padding `{spacing.sm} {spacing.lg}` (8px 16px), bo `{rounded.pill}`.
- Trạng thái nhấn `button-primary-pill-pressed` đổi nền sang `{colors.primary-press}`.
- Tối đa một nút filled trên mỗi màn hình.

**`button-secondary`** — dạng viền.
- Nền `{colors.canvas}`, chữ `{colors.primary}`, viền 1px `{colors.primary}`, cùng hình học pill.

**`button-destructive`** — hành động phá huỷ.
- Nền `{colors.canvas}`, chữ `{colors.ruby-ink}`, viền 1px `{colors.ruby-ink}`, kiểu chữ `{typography.button-sm}`.
- Không bao giờ tô nền ruby đặc: hành động phá huỷ cần được chọn có chủ ý, không cần được làm cho hấp dẫn.

**`button-on-dark`** — dùng trên bề mặt tối của màn Diagnostics.
- Nền `{colors.brand-dark-900}`, chữ `{colors.on-primary}`, cùng hình học pill.

### Data Table

**`table-header`** — nền `{colors.canvas-soft}`, chữ `{typography.micro-cap}` viết hoa màu `{colors.ink-secondary}`, gạch chân 1px `{colors.hairline-input}`, dính đỉnh khi cuộn.

**`table-row`** — nền `{colors.canvas-soft}`, chữ `{typography.body-sm}`, padding `8px 12px`, kẻ dưới 1px `{colors.hairline}` và `{colors.hairline-input}` cứ mỗi 5 dòng.

**`table-row-selected`** — nền `{colors.primary-wash}`, thêm chỉ báo dọc 3px `{colors.primary}` ở mép trái.

**`money-cell-in`** và **`money-cell-out`** — kiểu chữ `{typography.body-tabular}`, căn phải, dấu luôn hiện, màu `{colors.verdant}` hoặc `{colors.ruby-ink}`. Không nền, không viền.

### Cards & Containers

**`card-surface`** — khối nội dung chuẩn.
- Nền `{colors.canvas}`, viền 1px `{colors.hairline}`, bo `{rounded.md}`, padding 16px.

**`card-pair-swipe`** — thẻ cặp đối soát trên mobile.
- Nền `{colors.canvas}`, bo `{rounded.lg}`, padding 16px. Hai giao dịch xếp dọc, cả hai số tiền dùng `{typography.body-tabular}` căn phải.
- Khi thẻ mở rộng, khoá vuốt ngang: thẻ cao làm vuốt ngang xung đột với cuộn dọc.

**`row-account-select`** — dòng gán tài khoản cho từng tệp trong luồng Nhập.
- Nền `{colors.canvas}`, viền 1px `{colors.hairline}`, bo `{rounded.md}`, cao tối thiểu 52px.
- Nội dung: tên tệp `{typography.body-md}`, số tài khoản đọc được `{typography.caption}`, và dropdown chọn tài khoản.
- Khi số tài khoản không khớp, `banner-warning` chèn ngay dưới dòng đó chứ không đặt ở đầu màn.

**`empty-state`** — màn trống.
- Nền `{colors.canvas-soft}`, bo `{rounded.md}`, padding `32px 16px`, căn giữa.
- Icon nét mảnh 32px màu `{colors.hairline-input}`, một dòng `{typography.body-lg}` màu `{colors.ink-secondary}` nói điều gì sẽ đưa dữ liệu vào đây, và một `button-secondary` dẫn tới hành động đó.
- Màn trống là lời mời hành động, không phải lời xin lỗi: viết "Chưa có giao dịch nào. Nhập một tệp sao kê để bắt đầu." thay vì "Không tìm thấy dữ liệu".

**`dialog`** — nền `{colors.canvas}`, bo `{rounded.lg}`, padding 24px, elevation level 2. Tiêu đề `{typography.heading-lg}`.

### Inputs & Forms

**`text-input`** — ô nhập chuẩn.
- Nền `{colors.canvas}`, chữ `{colors.ink}`, kiểu chữ `{typography.body-md}`, padding `8px 12px`, bo `{rounded.sm}`, viền 1px `{colors.hairline-control}`.
- Trạng thái focus `text-input-focused` đổi viền sang `{colors.primary}`.

### Navigation

**`nav-bar-mobile`** — thanh điều hướng đáy, 4 ô ứng với bốn tác vụ hằng ngày.
- Nền `{colors.canvas}`, gạch trên 1px `{colors.hairline}`, nhãn `{typography.micro-cap}`, ô chưa chọn màu `{colors.ink-mute-2}`, ô đang chọn màu `{colors.primary}`.

**`nav-rail-web`** — nav rail bên trái.
- Nền `{colors.canvas-soft}`, viền phải 1px `{colors.hairline}`, chữ `{typography.body-sm}`, ô đang chọn nền `{colors.primary-wash}` chữ `{colors.primary-deep}`.

**`app-bar`** — nền `{colors.canvas}`, tiêu đề `{typography.heading-sm}`, gạch dưới 1px `{colors.hairline}`, padding ngang 16px.

### Pills, Tags, and Chips

**`pill-tag-soft`** — tag indigo dịu.
- Nền `{colors.primary-bg-subdued-hover}`, chữ `{colors.primary-press}`, kiểu chữ `{typography.micro-cap}`, padding `4px 8px`, bo `{rounded.pill}`.
- Dùng cho Context Chip mô tả bối cảnh đang xem, ví dụ lọc theo một lần nhập hoặc loại trừ giao dịch nội bộ. Nội dung chip phải được ghi vào phần đầu tệp khi xuất dữ liệu.

**`pill-pending`**, **`pill-confirmed`**, **`pill-rejected`** — ba trạng thái verdict, cùng hình học với `pill-tag-soft`, màu theo bảng Semantic.

**`badge-internal`** — nhãn giao dịch nội bộ.
- Viền 1px `{colors.hairline-control}`, không nền, chữ `{colors.ink-secondary}`, icon `⇄` dẫn đầu.
- Cố ý là hạng thị giác thứ ba, viền chứ không tô, để không cạnh tranh với pill trạng thái trên cùng một dòng.

**`chip-filter`** — chip lọc.
- Nền `{colors.canvas}`, viền 1px `{colors.hairline-control}`, chữ `{typography.micro}`. Khi đang bật: nền `{colors.primary-wash}`, viền `{colors.primary}`.

**`banner-warning`**, **`banner-danger`**, **`banner-info`**, **`banner-success`** — full-width, bo `{rounded.md}`, padding 12px, viền trái 3px đậm màu, icon 16px dẫn đầu, chữ `{typography.body-sm}`.
- Banner luôn có icon và pill không bao giờ có icon. Đây là quy tắc tách hai kênh ở tầng nhận biết.

### Import Stepper

Luồng Nhập là một stepper bốn bước, mỗi bước một quyết định và một nút chính.

**Tiêu đề bước** dùng `{typography.display-md}`, phụ đề `{typography.caption}` màu `{colors.ink-mute}`. Tiến độ hiển thị bằng thanh mảnh 2px chứ không phải chuỗi vòng tròn đánh số.

**Chân stepper** cố định ở đáy: một `button-primary-pill` bên phải, một `button-secondary` bên trái. Không bao giờ có hai nút cùng độ nổi.

### Reconciliation

**`segmented-control`** — ba nhóm verdict.
- Rãnh `{colors.canvas-soft}`, bo `{rounded.md}`, padding 3px. Nhóm đang chọn nền `{colors.canvas}` cộng elevation level 1.
- Mỗi nhãn kèm số đếm, ví dụ `Gợi ý (47)`. Nhãn `Đã từ chối (n)` luôn hiển thị kể cả khi n bằng 0: nó là lưới an toàn không hết hạn, không phải một tab có điều kiện.

### Signature Components

**`frame-pulse`** — phần tử chuyển động duy nhất của hệ thống.

Một dải 12 vạch (mỗi vạch 3×12px, cách nhau 3px) đặt cạnh `progress-bar`. Một con trỏ sáng chạy qua các vạch, tiến một vạch mỗi 2 frame. Vạch đang sáng dùng `{colors.primary}` đặc, các vạch còn lại dùng `{colors.hairline-input}`.

- Chuyển động phải do `Ticker` hoặc `AnimationController` điều khiển, tuyệt đối không do tiến độ dữ liệu.
- Bọc trong `RepaintBoundary`.
- Dùng `{colors.primary}` đặc, không dùng sắc độ nhạt, để giữ được tương phản sau khi nội dung được ghi hình và nén.
- Xuất hiện ở bước xử lý của luồng Nhập, ở màn Đối soát khi đang chạy, và ở màn Diagnostics. Khi người dùng chuyển sang tab khác trong lúc đang nhập, phiên bản thu nhỏ 6 vạch hiển thị trên app bar.

Frame Pulse tồn tại vì thanh tiến độ cập nhật theo lô dữ liệu, nên khi tiến trình chạy trên luồng giao diện nó chỉ đứng yên rồi nhảy — trạng thái đó không phân biệt được với xử lý bình thường. Frame Pulse chuyển động theo khung hình nên nó khựng lại đúng lúc luồng giao diện bị chặn, và đó là tín hiệu quan sát được.

**`progress-bar`** — cao 4px, rãnh `{colors.hairline}`, thanh `{colors.primary}`, bo `{rounded.pill}`. Kèm nhãn `{typography.caption}` dạng `1.240 / 3.000`.

**`snackbar`** — nền `{colors.ink}`, chữ `{colors.on-primary}`, bo `{rounded.md}`, padding `12px 16px`, elevation level 1.

**`link-on-light`** — chữ `{colors.primary}` ở `{typography.body-md}`, không gạch chân mặc định.

### Developer Diagnostics

**`diag-panel`** — nền `{colors.dark-surface}`, viền 1px `{colors.dark-hairline}`, bo `{rounded.md}`, padding 12px, log dùng `{typography.mono-log}`.

**`diag-metric`** — số đo `{typography.tabular-lg}` màu `{colors.primary-bg-subdued-hover}`, nhãn dưới `{typography.micro-cap}` màu `{colors.dark-ink-mute}`.

## Do's and Don'ts

### Do
- Giữ `{colors.primary}` cho nút filled và nhấn mạnh link; nó nên xuất hiện tiết chế, một nút filled trên mỗi màn.
- Render display tier ở weight 300 với tracking âm — đó là dấu ấn typographic của hệ thống.
- Dùng `font-feature-settings: "tnum"` trên mọi ô số, không chỉ ô tiền.
- Bật `font-feature-settings: "ss01"` toàn cục trên phần tử gốc.
- Luôn hiển thị dấu `+` và `−` trên số tiền, coi màu là lớp thông tin thứ hai.
- Giữ mỗi kênh ngữ nghĩa trong đúng hình thức của nó: tiền là chữ màu căn phải, trạng thái là pill có nền, phản hồi là banner có icon.
- Kẻ đường `{colors.hairline-input}` cứ mỗi 5 dòng trong bảng dài.
- Đặt Frame Pulse cạnh mọi thanh tiến độ.
- Cho phép chuyển tab trong lúc đang nhập, kèm chỉ báo tiến độ thu nhỏ trên app bar.

### Don't
- Không dùng weight 300 ở cỡ chữ nội dung: dấu tiếng Việt mất nét và biến mất khi nội dung bị nén.
- Không dùng gradient, blur, hay animation trang trí.
- Không tô nền `{colors.ruby-ink}` hoặc `{colors.verdant}` đặc cho nút; chúng là màu ngữ nghĩa, không phải màu hành động.
- Không tô nền cả dòng theo hướng tiền: bảng trở nên rối và pill trạng thái mất chỗ nổi lên.
- Không dùng `{colors.primary}` làm màu chữ ở cỡ nội dung.
- Không thêm màu mới khi cần phân biệt hai thứ; xét hình dạng và vị trí trước.
- Không thu nhỏ chữ xuống dưới 12px để tăng mật độ; giảm chiều cao dòng thay vào đó.
- Không thu padding nút xuống dưới `8px 16px`.
- Không thay hình pill của nút bằng hình chữ nhật bo góc.

## Responsive Behavior

### Breakpoints

| Tên | Bề rộng | Thay đổi chính |
|---|---|---|
| Expanded | ≥ 1024dp | `nav-rail-web` mở rộng kèm nhãn; bảng hiện đủ cột; panel chi tiết mở bên phải; số tổng ở `{typography.display-xxl}` |
| Medium | 600–1023dp | `nav-rail-web` thu gọn chỉ còn icon; bảng hiện đủ cột; số tổng hạ xuống `{typography.display-xl}` |
| Compact | < 600dp | `nav-bar-mobile` ở đáy; danh sách chuyển sang dạng card; một cột; số tổng hạ xuống `{typography.display-lg}` |

### Touch Targets
- Nút pill đạt tối thiểu 48×48px trên mobile nhờ padding co giãn.
- Ô nhập giữ chiều cao tối thiểu 48px trên mobile, 40px trên web.
- Dòng bảng ở density touch cao 52px, đủ cho thao tác chạm và vuốt.

### Collapsing Strategy
- Display tier hạ bậc 56 → 48 → 32px qua ba breakpoint.
- Bảng chuyển thành danh sách card ở Compact: mỗi giao dịch thành một card hai dòng, số tiền căn phải giữ nguyên `{typography.body-tabular}`.
- Danh sách cặp đối soát chuyển từ bảng có checkbox trên web sang `card-pair-swipe` trên mobile.
- Panel chi tiết ở Expanded trở thành màn hình riêng ở Medium và Compact.
- Không có màn hình nào chỉ tồn tại trên một nền tảng, ngoại trừ chỉ báo giới hạn xử lý của bản web.

## Flutter Mapping

```dart
// core/theme/ledger_colors.dart
@immutable
class LedgerColors extends ThemeExtension<LedgerColors> {
  final Color moneyIn, moneyOut;
  final Color pendingBg, pendingFg;
  final Color confirmedBg, confirmedFg;
  final Color rejectedBg, rejectedFg;
  final Color warningBg, dangerBg, infoBg, successBg;
  final Color canvasSoft, hairline, hairlineStrong;
  // ... + copyWith, lerp
}
```

| Hạng mục | Nơi khai báo |
|---|---|
| `ColorScheme.fromSeed(seedColor: Color(0xFF533AFD))` | `ThemeData` |
| Màu ngữ nghĩa nghiệp vụ | `ThemeExtension<LedgerColors>` |
| Density theo nền tảng | `ThemeData.visualDensity`, chọn theo breakpoint |
| `tnum` | `TextStyle(fontFeatures: [FontFeature.tabularFigures()])` |
| `ss01` | `FontFeature('ss01')` trong `TextTheme` gốc |
| Bảng màu Diagnostics | `Theme` cục bộ bọc riêng màn đó |

Màu là chính sách, không phải chi tiết của widget. Không viết `Color(0xFF...)` trong tệp widget; mọi truy cập đi qua `Theme.of(context).extension<LedgerColors>()`. Nhờ vậy giao diện tối chỉ cần thêm một bản `.dark` kèm `lerp`, và màu trở thành thứ kiểm thử được.

## Iteration Guide

1. Mỗi lần chỉ tập trung vào một component.
2. Tham chiếu trực tiếp bằng tên token (`{colors.primary}`, `{typography.body-tabular}`, `{rounded.pill}`).
3. Chạy `npx @google/design.md lint DESIGN.md` sau khi sửa.
4. Biến thể mới thêm thành entry riêng.
5. Mặc định chữ nội dung dùng `{typography.body-md}`; mọi phần tử chứa số dùng `{typography.body-tabular}` hoặc `{typography.caption}`.
6. `ss01` bật toàn cục; `tnum` áp theo từng phần tử số.
7. Trước khi thêm một màu mới, kiểm tra ba kênh ngữ nghĩa: khả năng cao thứ cần phân biệt nên tách bằng hình dạng thay vì bằng hue.