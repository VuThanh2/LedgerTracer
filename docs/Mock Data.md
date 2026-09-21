# Mock sao kê ngân hàng — bộ test cho LedgerTracer

Toàn bộ dữ liệu là **synthetic**. Tên người, số tài khoản, MST, địa chỉ, số tiền đều được sinh ngẫu nhiên có seed cố định (`1001`, `2002`, `3003`) → chạy lại `build_all.py` cho ra file y hệt.

---

## 1. Danh sách file

| Mức | File | Ngân hàng | Số dòng | Kỳ |
|---|---|---|---:|---|
| **L1 — Cá nhân** | `L1-canhan-VCB-082026.xlsx` | Vietcombank | 27 | 01/08 – 31/08/2026 |
| **L2 — Hộ kinh doanh** | `L2-hokinhdoanh-VCB-072026-082026.xlsx` | Vietcombank | 1.100 | 01/07 – 31/08/2026 |
| **L2 — Hộ kinh doanh** | `L2-hokinhdoanh-TECHCOMBANK-072026-082026.xlsx` | Techcombank | 183 | 01/07 – 31/08/2026 |
| **L3 — Doanh nghiệp** | `L3-doanhnghiep-VCB-062026-082026.xlsx` | Vietcombank | 8.018 | 01/06 – 31/08/2026 |
| **L3 — Doanh nghiệp** | `L3-doanhnghiep-VCB-082026-092026-GIAONHAU.xlsx` | Vietcombank | 3.657 | 01/08 – 15/09/2026 |
| **L3 — Doanh nghiệp** | `L3-doanhnghiep-BIDV-062026-082026.xlsx` | BIDV | 1.137 | 01/06 – 31/08/2026 |
| **L3 — Doanh nghiệp** | `L3-doanhnghiep-ACB-USD-062026-082026.xlsx` | ACB (USD) | 611 | 01/06 – 31/08/2026 |

Kèm theo: `gen_mock.py` (4 writer theo từng format) và `build_all.py` (kịch bản 3 mức). Muốn đổi quy mô thì chỉnh các `rng.randint(...)` trong `build_all.py` rồi chạy `python3 build_all.py`.

---

## 2. Độ trung thực của format

**Vietcombank — mô phỏng 1:1 file thật.** Đã đối chiếu và khớp: tên sheet `Vietcombank_Account_Statement`, cột A ẩn (width 4.71), độ rộng 8 cột, merge range của khối header/footer, font Times New Roman, tiêu đề 14pt bold màu `#006600`, header bảng ở dòng 13, dữ liệu từ dòng 14, chiều cao dòng 60, border thin, và các quirk:

- **Mọi số tiền lưu dưới dạng TEXT** (`"163,000"`), không phải number. Ô không phát sinh là chuỗi rỗng `''`, không phải `None`.
- **Ngày và số chứng từ nằm chung một ô** `C`, ngăn bởi `\n`: `"04/08/2026\n5285 - 82284"`.
- Cột `B` (STT) mang `number_format = "mm-dd-yy"` dù chứa text — quirk có thật của file gốc, giữ nguyên để parser không dựa vào number_format.
- Dòng phí dùng tiền tố chứng từ `9914 - …`, dòng lãi dùng `9701 - <số tài khoản>` và nội dung `INTEREST PAYMENT`.
- Giao dịch thẻ quốc tế giữ nguyên kiểu `UHHT..…DG:<MERCHANT>…<số>USD` — số tiền VND lẻ, không tròn nghìn.

**Techcombank / BIDV / ACB — tái dựng hợp lý, không phải file thật.** Mình không có mẫu thật nên đây là *reconstruction*, cố ý khác nhau ở đúng những trục hay làm vỡ parser. Khi có file thật thì chỉnh lại writer tương ứng trong `gen_mock.py` là đủ.

| Trục | Vietcombank | Techcombank | BIDV | ACB |
|---|---|---|---|---|
| Dòng header bảng | 13 | 9 | 10 | 8 |
| Cột bắt đầu | B (A ẩn) | A | A | A |
| Nợ/Có | 2 cột tách | **1 cột số tiền có dấu ±** | 2 cột tách | 1 cột + **cột `Loại` D/C** |
| Kiểu số tiền | text, dấu `,` | **number (float)** | **text, dấu `.`** | number, 2 chữ số thập phân |
| Kiểu ngày | text `dd/mm/yyyy` gộp với số CT | **Excel date thật** | text `dd/mm/yyyy hh:mm:ss` | text `yyyy-MM-dd`, **2 cột ngày** (hiệu lực / ghi sổ) |
| Vị trí cột nội dung | cuối | cuối | **trước cột tiền** | giữa |
| Khác | có STT, footer pháp lý | không STT ở footer | không có STT | có **cột TK đối ứng** |
| Loại tiền | VND | VND | VND | **USD** |

Nếu app chạy được cả 4 file này thì gần như chắc chắn parser không bị bias vào layout Vietcombank.

---

## 3. Các tình huống đã cài sẵn để test

### 3.1 Bất biến số dư (đã verify bằng script)
Ở cả 4 format: `số dư đầu kỳ + Σ(số tiền có dấu) = số dư cuối kỳ`, và mỗi dòng thoả `balance[i] = balance[i-1] ± amount[i]`. Dùng làm assertion sau import — nếu lệch thì lỗi ở parser chứ không phải ở data.

### 3.2 Đối soát nội bộ (UC-08)

**L2 — 14 cặp sạch** TCB → VCB (rút tiền quán về tài khoản kinh doanh), lệch ngày **0–2 ngày** ngẫu nhiên → dùng để kiểm tra `matchWindowDays`. Hạ cửa sổ về 0 thì số cặp khớp phải giảm.

**L3 — 6 cặp sạch** VCB ↔ BIDV:
- 3 cặp *cấp vốn chi lương* (VCB → BIDV, ngày 04 hàng tháng, lệch 0–2 ngày)
- 3 cặp *quét số dư cuối tháng* (BIDV → VCB, ngày 26 hàng tháng, lệch 0–3 ngày) — cặp lệch 3 ngày là **biên** của cửa sổ ±3

### 3.3 Trường hợp âm — phải KHÔNG khớp chính xác
- **Lệch số tiền do phí:** L2 ngày 12/08 (TCB ghi nợ 5.000.000 / VCB ghi có 4.988.900); L3 ngày 18 hàng tháng, 3 cặp bị trừ đúng 11.000 VND phí. Đây là ca để quyết định app xử lý tolerance thế nào — hiện tại theo ruling "money = integer, so khớp chính xác" thì phải rơi vào *gợi ý sai* hoặc *không gợi ý*, và người dùng phải từ chối được (UC-09).
- **Mồi false-positive:** L2 có 2 giao dịch ghi có **đúng bằng** số tiền một lần chuyển nội bộ (2.000.000 ngày 09/07 và 1.500.000 ngày 05/08) nhưng đối tác là người ngoài → nếu thuật toán chỉ match theo (số tiền, cửa sổ ngày) thì sẽ đề xuất nhầm. Đây chính là dữ liệu để test `RejectedMatch`.
- **Chuyển khoản khác loại tiền:** L3 ngày 14/07, VCB ghi nợ 528.400.000 VND ↔ ACB ghi có 20.000,00 USD. Theo ruling hiện tại đây là Limitation đã ghi nhận — app **không được** cộng gộp hay quy đổi; test xem thống kê có tách đúng theo currency không.

### 3.4 Import nhiều file & khử trùng lặp (FR-09 / UC-02)
Hai file VCB của L3 là **cùng một tài khoản**, kỳ giao nhau 01/08–31/08/2026, chứa **2.404 dòng trùng khớp tuyệt đối** (cùng số CT, số tiền, nội dung).
- Import cả hai → tổng dòng phải là `8.018 + 3.657 − 2.404 = 9.271`, không phải 11.675.
- Đảo thứ tự import phải cho kết quả y hệt (ruling: parse song song, ghi tuần tự theo thứ tự người dùng chọn).
- File thứ hai có `Số dư đầu kỳ` khác file thứ nhất — kiểm tra app không lấy nhầm opening balance khi gộp.

### 3.5 Benchmark concurrency
- **L1 (27 dòng)** — chạy trên main isolate cũng không jank; dùng để chứng minh "ở quy mô nhỏ ba chiến lược tương đương", đúng với định vị sản phẩm.
- **L2 (~1.300 dòng, 2 file)** — vùng bắt đầu thấy khác biệt.
- **L3 (~13.400 dòng, 4 file, 3 tài khoản, 2 loại tiền)** — tải chính cho Developer Diagnostics. Import 4 file một lượt là workload tốt nhất cho so sánh naive / `compute()` / `Isolate.run()`, và cũng là lúc bounded queue backpressure có ý nghĩa. Trên Web thì cả ba suy biến — đúng điểm phân tích của bài.

Nếu cần nặng hơn nữa cho benchmark, sửa `rng.randint(55, 130)` (dòng thu tiền khách của L3) lên là ra vài chục nghìn dòng.

---

## 4. Ghi chú

- Nội dung giao dịch cố ý giữ kiểu viết không dấu, viết hoa, chen số tham chiếu — giống hệt sao kê thật, nên full-text search (UC-06) test trên đây mới có ý nghĩa.
- Không có file MT940/CSV/JSON trong bộ này; nếu cần mình dựng thêm để phủ hết 4 định dạng import.
