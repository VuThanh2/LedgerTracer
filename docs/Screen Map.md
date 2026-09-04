# Screen Map

Trang này ánh xạ **Use Case → màn hình thực tế**. Quan hệ không phải 1:1: nhiều UC dồn về một màn hình (UC-04+06+07, UC-08+09), một UC trải thành nhiều bước (UC-02), và một UC không có màn hình riêng mà là thành phần dùng chung nhiều điểm vào (UC-11).

Cột **Nền tảng** ghi nơi màn hình *có mặt*. Khác biệt về **hình thái** giữa mobile và web ghi bằng ký hiệu ⇄ trong cột mô tả; chỗ trống nghĩa là dùng chung một layout.

# 1. Khung điều hướng

| Màn hình | Nền tảng | UC | Mục đích / Chức năng chính |
| --- | --- | --- | --- |
| App Shell | Cả 2 | — (khung chứa) | Khung điều hướng bao ngoài toàn bộ màn hình chính, 4 mục: Giao dịch, Nhập, Đối soát, Thống kê. ⇄ Mobile: bottom navigation; Web: navigation rail dọc bên trái |
| — Settings Entry | Cả 2 | — (điểm vào) | Không phải màn hình riêng — icon bánh răng dẫn tới Settings Screen. ⇄ Mobile: góc phải AppBar; Web: chân navigation rail |
| App Lock Screen | Cả 2 | UC-12 | Chặn toàn bộ ứng dụng khi App Lock bật; nhập PIN để vào, hiện trước App Shell. ⇄ Native: thêm nút mở khoá bằng sinh trắc học nếu đã bật; Web: chỉ PIN |
| — Forgot PIN Action | Cả 2 | UC-12 | Không phải màn hình riêng — liên kết "Quên PIN?" mở dialog xoá toàn bộ dữ liệu cục bộ (yêu cầu gõ chuỗi xác nhận), nêu rõ chỉ khôi phục lại được nếu đã có backup (UC-13) |

# 2. Nhập Sao kê

| Màn hình | Nền tảng | UC | Mục đích / Chức năng chính |
| --- | --- | --- | --- |
| Import Screen | Cả 2 | UC-02, UC-03, UC-14 | Một route duy nhất chứa hai tab: *Nhập mới* và *Lịch sử* |
| — Tab: Nhập mới | Cả 2 | UC-02, UC-14 | Luồng nhập sao kê dạng stepper 4 bước; các bước là state của cùng một tab, không phải route riêng |
| · Bước 1: Chọn file | Cả 2 | UC-02 (b1, b2) | Chọn một hoặc nhiều file từ thiết bị; hệ thống nhận diện định dạng và hiển thị badge CSV/Excel/MT940/JSON. ⇄ Web: qua file picker của trình duyệt, không có đường dẫn |
| · Bước 2: Gán tài khoản | Cả 2 | UC-02 (b3, b4), UC-01 | Gán tài khoản đích cho từng file, tạo tài khoản mới ngay tại chỗ nếu cần; nếu số tài khoản đọc được từ file lệch với số đã ghi nhận thì cảnh báo với 3 lựa chọn (gán lại / vẫn nhập / bỏ qua file này). ⚠️ Bước này **bắt buộc chặn** trước bước 3 |
| · Bước 3: Tiến trình | Cả 2 | UC-02 (b5, b6, b7), UC-14 | Thanh tiến trình theo lô + jank surface, nút Huỷ chỉ phản hồi tại ranh giới lô. Trên Web hiện chỉ báo suy biến của UC-14. ⚠️ Huỷ xong vẫn đi tiếp sang bước 4, không quay về bước 1 |
| · Bước 4: Tổng kết | Cả 2 | UC-02 (b8), UC-11 | Bảng kết quả theo từng file và tổng cộng: số giao dịch mới / bỏ qua do trùng / dòng lỗi; nút xuất danh sách dòng lỗi |
| · Nút "Chạy đối soát" ở bước 4 | Cả 2 | UC-02 → UC-08 | Không phải màn hình riêng — nút phụ **điều hướng** sang Reconciliation Screen (không tự chạy), chỉ hiện khi toàn hệ thống có từ 2 tài khoản có giao dịch trở lên |
| — Tab: Lịch sử | Cả 2 | UC-03, UC-11 | Danh sách lượt nhập theo thời gian gần nhất, mỗi lượt là nhóm bản ghi con theo từng file; hoàn tác được từng file hoặc cả nhóm, xuất lại được danh sách dòng lỗi. Lượt đã hoàn tác / bị huỷ / bị gián đoạn vẫn ở lại danh sách với trạng thái tương ứng |
| · Xem giao dịch của file | Cả 2 | UC-03 → UC-04 | Không phải màn hình riêng — hành động trên mỗi bản ghi file, mở Transaction List kèm chip lọc theo lượt nhập |

# 3. Giao dịch

| Màn hình | Nền tảng | UC | Mục đích / Chức năng chính |
| --- | --- | --- | --- |
| Transaction List Screen | Cả 2 | UC-04, UC-06, UC-07 | Màn hình chính của ứng dụng: danh sách gộp mọi tài khoản, cuộn lười, sắp theo ngày giảm dần, dùng chung ô tìm kiếm và bộ lọc. Mỗi dòng hiển thị tài khoản, số tiền kèm mã loại tiền, chỉ báo "đã đối soát". Ba điểm vào: nav, khoan xuống từ Thống kê, xem giao dịch của một lượt nhập. ⇄ Web: two-pane; Mobile: push sang màn hình chi tiết |
| — Filter Panel | Cả 2 | UC-07 | Lọc theo khoảng số tiền, khoảng ngày, tài khoản, loại tiền (kết hợp theo VÀ); chip hiển thị bộ lọc đang áp dụng, xoá được từng cái. Bật bộ lọc số tiền thì tự động bật kèm tiêu chí loại tiền. ⇄ Mobile: bottom sheet; Web: panel cố định bên phải |
| — Context Chips | Cả 2 | UC-03 → UC-04, UC-10 → UC-04 | Chip ngữ cảnh chỉ sinh ra khi vào từ màn hình khác, nằm ngoài Filter Panel nhưng xoá được như chip thường: **"Lượt nhập: <tên file>"** và **"Không gồm chuyển khoản nội bộ"** |
| — Transaction Detail | Cả 2 | UC-04 (b3, b4) | Đầy đủ thông tin một giao dịch: ngày, số tiền + loại tiền, tài khoản, đối tác, nội dung, trạng thái đối soát, số thứ tự dòng trong file gốc. Chỉ báo "đã đối soát" là liên kết mở Reconciliation Screen tới đúng cặp đó. ⇄ Web: pane phải; Mobile: route riêng |
| — Edit Transaction Form | Cả 2 | UC-05 | Sửa các trường của một giao dịch; cảnh báo nếu giao dịch đang thuộc cặp đối soát (cặp sẽ bị huỷ, không ghi thành phán quyết từ chối) |
| — Delete Confirm Dialog | Cả 2 | UC-05 | Xác nhận xoá một giao dịch, không có ngoại lệ; nêu rõ cặp đối soát liên quan sẽ bị huỷ |

# 4. Đối soát Nội bộ

| Màn hình | Nền tảng | UC | Mục đích / Chức năng chính |
| --- | --- | --- | --- |
| Reconciliation Screen | Cả 2 | UC-08, UC-09, UC-14 | Một màn hình cho cả chạy đối soát lẫn duyệt kết quả: nút Chạy, tiến trình theo lô, danh sách cặp. Hai điểm vào: nav và liên kết từ Transaction Detail. Mở được cả khi không còn cặp nào chờ quyết định. ⚠️ Nút Chạy phải cảnh báo khi nhóm *Chờ quyết định* khác rỗng, vì chạy lại sẽ xoá sạch mọi cặp chưa xác nhận. ⇄ Mobile: thẻ vuốt trái/phải; Web: bảng hai cột, thao tác bằng nút |
| — Segmented Control | Cả 2 | UC-09 | Ba nhóm phán quyết luôn nhìn thấy kèm số đếm: *Chờ quyết định (n)* / *Đã xác nhận (n)* / *Đã từ chối (n)* |
| — Empty State: chưa đủ tài khoản | Cả 2 | UC-08 (tiền điều kiện) | Khi có dưới 2 tài khoản có giao dịch: thay nút Chạy bằng giải thích rằng đối soát cần hai tài khoản khác nhau, kèm CTA sang Nhập |
| — Match Window Control | Cả 2 | UC-08 | Chỉnh `matchWindowDays` ngay trên màn hình này (không nằm trong Settings); chỉ ảnh hưởng lần chạy sau, không đụng cặp đã xác nhận |
| — Pair Detail | Cả 2 | UC-09 (b2, b3, b4) | Hiển thị đầy đủ hai vế của một cặp ngay tại chỗ (đối tác, nội dung, số dòng file gốc) kèm danh sách ứng viên thay thế; hai hành động Xác nhận / Từ chối. ⇄ Mobile: thẻ mở rộng thì khoá cử chỉ vuốt, chỉ thao tác bằng nút |
| — Rejection Snackbar | Cả 2 | UC-09 (b3) | Không phải màn hình riêng — hiện sau mỗi lần từ chối, nói rõ phán quyết đã được ghi nhớ và cặp này sẽ không được gợi ý lại, kèm nút Hoàn tác |
| — Confirmed Pair Actions | Cả 2 | UC-09 | Trong nhóm *Đã xác nhận*, hành động khả dụng vẫn là **Từ chối** — không có nút "bỏ xác nhận" riêng |

# 5. Thống kê

| Màn hình | Nền tảng | UC | Mục đích / Chức năng chính |
| --- | --- | --- | --- |
| Statistics Screen | Cả 2 | UC-10 | Biểu đồ tổng tiền vào/ra theo mốc thời gian (mặc định theo tháng) và theo tài khoản, tách riêng theo từng loại tiền qua dãy tab luôn nhìn thấy. Công tắc loại trừ giao dịch nội bộ đã đối soát mặc định bật, không ghi nhớ giữa các lần mở, biểu đồ cập nhật ngay. ⇄ Mobile: biểu đồ xếp dọc; Web: hai biểu đồ cạnh nhau |
| — Drill-down Action | Cả 2 | UC-10 → UC-04 | Không phải màn hình riêng — bấm vào một cột mở Transaction List với khoảng ngày + loại tiền điền sẵn, mang theo trạng thái công tắc loại trừ dưới dạng Context Chip |
| — Zero-effect Notice | Cả 2 | UC-10 | Ghi chú khi công tắc loại trừ đang bật nhưng chưa có cặp nào được xác nhận; liên kết dẫn sang **Nhập** nếu dưới 2 tài khoản có giao dịch, sang **Đối soát** nếu từ 2 trở lên |

# 6. Quản lý & Hệ thống

| Màn hình | Nền tảng | UC | Mục đích / Chức năng chính |
| --- | --- | --- | --- |
| Settings Screen | Cả 2 | UC-12 | Trang gom toàn bộ cấu hình, chia ba nhóm: **Tài khoản ngân hàng** (→ Account Management), **Bảo mật** (App Lock, đổi PIN — bắt buộc nhập PIN hiện tại trước), **Dữ liệu** (→ Backup & Restore). ⇄ Native: thêm công tắc sinh trắc học, chỉ bật được khi đã có PIN; Web: không hiển thị công tắc này |
| Account Management Screen | Cả 2 | UC-01 | Danh sách tài khoản đã khai báo kèm số tài khoản hệ thống đã học từ file; thêm/sửa tên, sửa hoặc xoá số tài khoản khi học nhầm. Xoá tài khoản có hộp thoại xác nhận nêu rõ số giao dịch bị ảnh hưởng và số cặp đối soát sẽ bị huỷ. Vào từ Settings |
| — Account Form Dialog | Cả 2 | UC-01 | Thêm hoặc sửa một tài khoản; dùng lại nguyên vẹn ở Import Screen bước 2 — một component, hai điểm vào |
| Backup & Restore Screen | Cả 2 | UC-13 | Sao lưu: đặt mật khẩu riêng cho file (độc lập với PIN), cảnh báo mất mật khẩu là mất luôn file. Khôi phục: chọn file, nhập mật khẩu, cảnh báo ghi đè toàn bộ trước khi tiến hành. ⇄ Android: chọn được vị trí lưu; Web: qua cơ chế tải xuống/tải lên của trình duyệt |

# 7. Thành phần dùng chung

| Thành phần | Nền tảng | UC | Mục đích / Chức năng chính |
| --- | --- | --- | --- |
| Export Dialog | Cả 2 | UC-11 | Không phải màn hình riêng — dialog chọn định dạng (CSV/Excel) với **năm điểm vào**: tổng kết lượt nhập (UC-02), lịch sử nhập (UC-03), danh sách giao dịch (UC-04), kết quả đối soát (UC-09), thống kê (UC-10). Nêu ngay trong dialog rằng file xuất không mã hoá. File ghi ở đầu mọi tiêu chí đang áp dụng: bộ lọc, từ khoá, loại tiền, công tắc loại trừ, nhóm phán quyết đang chọn, **và cả Context Chip đang bật** |
| Web Degradation Indicator | Chỉ Web | UC-14 | Không phải màn hình riêng — một chỉ báo thống nhất nhúng vào Import Screen bước 3 và Reconciliation Screen, nói rõ hai hệ quả: mất isolate ⇒ giao diện có thể giật; mất song song nhiều file ⇒ tổng thời gian dài hơn |

# 8. Màn hình phục vụ thực nghiệm

| Màn hình | Nền tảng | UC | Mục đích / Chức năng chính |
| --- | --- | --- | --- |
| Developer Diagnostics Screen | Cả 2 | — (ngoài Domain) | Chạy thử một workload (import UC-02 / đối soát UC-08) theo từng chiến lược concurrency và kích thước lô, hiển thị kết quả đo: tổng thời gian, thống kê frame time, số lô đã xử lý. Vào từ mục ẩn cuối Settings. Thiết kế chi tiết nằm ở trang *Thiết kế Thực nghiệm* |

# 9. Không có màn hình

| Yêu cầu | Vì sao không cần màn hình |
| --- | --- |
| FR-23 — Lưu trữ hoàn toàn offline | Ràng buộc kiến trúc xuyên suốt, không phải hành vi kích hoạt được; thể hiện gián tiếp qua việc không có màn hình đăng nhập, đồng bộ hay tài khoản người dùng nào |
| UC-14 — Cảnh báo giới hạn trên Web | Là chỉ báo nhúng vào hai màn hình có tác vụ nền, không phải màn hình riêng |

# Ghi chú thiết kế

> **Bốn ô nav chọn theo tần suất, không theo phân loại chức năng.** Giao dịch / Nhập / Đối soát / Thống kê là bốn việc lặp lại hằng ngày; Account Management, Settings và Backup & Restore nằm dưới Settings, Lịch sử nhập là tab trong Import.
> 

> **Context Chip — mọi đường điều hướng phải mang theo đủ ngữ cảnh** để tập dữ liệu ở đích trùng với thứ người dùng vừa bấm vào. Chip sinh ra từ màn hình nguồn, nằm ngoài Filter Panel, xoá được, và bắt buộc ghi vào đầu file xuất.
> 

> **Không có màn hình nào riêng cho một nền tảng, trừ chỉ báo suy biến trên Web.** Khác biệt mobile/web nằm ở hình thái trình bày, không ở tập tính năng — đây là adaptive UI thật, không phải hai ứng dụng chung repo.
> 

> **Thứ tự làm.** Đợt 1 — App Shell, Transaction List (+ filter, detail), Import tab Nhập mới, Developer Diagnostics. Đợt 2 — Reconciliation, Statistics, tab Lịch sử, Account Management. Đợt 3 — Settings, App Lock, Backup & Restore.
>