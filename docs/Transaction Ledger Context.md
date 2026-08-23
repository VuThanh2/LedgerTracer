# Transaction Ledger Context

**Brief Idea:** Toàn bộ hệ thống nằm trong **một Context duy nhất** — *Transaction Ledger Context*. Đây là hệ quả trực tiếp của kiến trúc: một ứng dụng Flutter, một cơ sở dữ liệu SQLite cục bộ, một người dùng, không có máy chủ. Context này quản lý tài khoản ngân hàng khai báo, vòng đời của Giao dịch (nhập từ sao kê nhiều định dạng, chống trùng, tra cứu, chỉnh sửa), nghiệp vụ đối soát chuyển tiền nội bộ giữa các tài khoản, và các số liệu thống kê phái sinh từ hai thứ đó.

<aside>
🧭

**Ranh giới của Domain Model này**

- Mô hình mô tả **dữ liệu bền vững trên thiết bị** — nơi duy nhất giữ source of truth. Không có bản sao nào ở nơi khác để phải hoà giải.
- Trạng thái sống trong bộ nhớ của một tác vụ nền (hàng đợi lô chờ ghi, cờ huỷ, bộ đếm tiến trình, kết quả phân tích chưa ghi) là **trạng thái thực thi**, không phải Domain. Chúng chết khi tác vụ kết thúc và được thiết kế ở trang kiến trúc, không ở đây.
- Màn hình đo đạc so sánh chiến lược concurrency (benchmark) **cố ý nằm ngoài Domain**: nó đọc dữ liệu có sẵn để chạy thí nghiệm, không sinh ra khái niệm nghiệp vụ nào. Thiết kế của nó nằm ở trang *Thiết kế Thực nghiệm*.
- Không có Domain Events. Không phải vì "chưa cần", mà vì **không có ranh giới tiến trình nào để một event phải vượt qua**: mọi side effect xảy ra trong cùng một transaction SQLite, trên cùng một luồng chính. Chúng được orchestrate tường minh ở Application Layer, và được mô tả tại chính Business Rules của từng Use Case liên quan thay vì chép lại ở đây.
</aside>

## 1. Ubiquitous Language

| Term | Meaning |
| --- | --- |
| Bank Account | Nhãn do người dùng tự khai báo để nhóm giao dịch; không có kết nối hay xác thực với ngân hàng thật |
| Transaction | Một dòng tiền vào hoặc ra của đúng một Bank Account, đến từ đúng một dòng trong file sao kê |
| Statement | File sao kê do ngân hàng cung cấp, ở một trong bốn định dạng được hỗ trợ (CSV, Excel, MT940, JSON) |
| Import Session | Một lượt nhập, gồm một hoặc nhiều file được người dùng chọn cùng lúc |
| Import File Record | Bản ghi kết quả nhập của **một file** trong một lượt; là đơn vị nhỏ nhất có thể hoàn tác |
| Error Row | Một dòng trong file gốc không đọc được, giữ lại kèm số thứ tự dòng và lý do để người dùng sửa rồi nhập lại |
| Fingerprint | Dấu vân tay của một giao dịch (tổ hợp tài khoản • ngày • số tiền • loại tiền • nội dung), là căn cứ duy nhất để nhận diện trùng lặp |
| Deduplication | Việc so khớp **theo số lượng** bản ghi cùng Fingerprint đã có, chỉ nhập thêm phần chênh lệch |
| Reconciliation | Quá trình quét toàn bộ giao dịch chưa ghép để tìm các cặp chuyển tiền nội bộ giữa hai tài khoản của cùng tổ chức |
| Reconciliation Pair | Hai giao dịch được ghép: một vế chuyển ra, một vế nhận vào, ở hai tài khoản khác nhau |
| Match Alternative | Ứng viên ghép hợp lệ nhưng không được chọn làm gợi ý chính; **được tính lại khi hiển thị, không lưu** |
| Rejected Match | Phán quyết "hai giao dịch này không phải một cặp"; được nhớ để lần quét sau không gợi ý lại |
| Match Window | Ngưỡng lệch thời gian tối đa giữa hai vế của một cặp (mặc định ±3 ngày); là tham số cấu hình được |
| Suggested / Confirmed | Hai trạng thái của một cặp: máy đề xuất và người xác nhận. Chỉ Confirmed mới có hiệu lực nghiệp vụ |
| Currency | Loại tiền của một giao dịch (mã ISO 4217); là thuộc tính của giao dịch chứ không phải của tài khoản |
| External Cash Flow | Dòng tiền thực với bên ngoài tổ chức — tổng giao dịch sau khi loại trừ các cặp đã xác nhận, tính riêng cho từng loại tiền |
| Search Text | Dạng chuẩn hoá của tên đối tác và nội dung chuyển khoản (hạ chữ thường, bỏ dấu tiếng Việt), tính một lần lúc nhập |
| Batch | Một lô bản ghi được xử lý liền mạch; ranh giới giữa các lô là nơi duy nhất tiến trình được báo và yêu cầu huỷ được kiểm |
| Parse Stage / Write Stage | Hai giai đoạn tách rời của một lượt nhập: phân tích chạy song song trong isolate, ghi chạy tuần tự trên luồng chính |
| Backpressure | Giới hạn số lô đang chờ ghi; khi đầy, isolate phân tích tạm dừng gửi để bộ nhớ không phình |
| Export | File CSV/Excel chứa một tập con dữ liệu do người dùng chủ động chọn, **không mã hoá**, để mở bằng công cụ khác |
| Backup | File chứa **toàn bộ** dữ liệu, **đã mã hoá**, chỉ để chính ứng dụng đọc lại |
| App Lock | Lớp chặn truy cập thiết bị bằng PIN, có thể thêm sinh trắc học trên native; không phải tài khoản người dùng |

# 2. Domain Model

## Entities

### BankAccount

- accountId *(khoá chính cục bộ, số nguyên tự tăng)*
- displayName *(nhãn tự đặt, không bắt buộc duy nhất)*
- accountNumber *(nullable — không phải trường người dùng nhập tay: hệ thống ghi nhận từ file đầu tiên có mang số tài khoản (UC-02 bước 4), sau đó dùng làm mốc đối chiếu cho các lần nhập sau; sửa được ở UC-01 khi học nhầm)*
- createdAt

### Transaction

- transactionId *(khoá chính cục bộ, số nguyên tự tăng)*
- accountId *(FK → BankAccount)*
- bookingDate *(ngày ghi nhận, lấy từ file, không phải đồng hồ thiết bị)*
- amount *(số nguyên có dấu, tính theo đơn vị nhỏ nhất của loại tiền ở dòng dưới; dương = tiền vào, âm = tiền ra)*
- currency *(mã ISO 4217 đọc từ file; mặc định VND khi định dạng nguồn không nêu. Là thuộc tính của giao dịch, không phải của tài khoản — một tài khoản có thể nhận nhiều loại tiền)*
- counterpartyName *(nullable — tên người chuyển/nhận)*
- description *(nội dung chuyển khoản)*
- searchText *(dạng chuẩn hoá không dấu của counterpartyName • description — có đánh chỉ mục)*
- fingerprint *(dấu vân tay chống trùng — có đánh chỉ mục, không ràng buộc duy nhất)*
- importFileRecordId *(FK → ImportFileRecord — nguồn gốc, là thứ làm cho hoàn tác khả thi)*
- sourceLineNumber *(nullable — số thứ tự dòng trong file gốc)*
- isManuallyEdited *(cờ đánh dấu đã bị sửa tay sau khi nhập)*
- importedAt *(thời điểm nhập theo đồng hồ thiết bị — tách bạch hoàn toàn với bookingDate)*

### ImportSession

- sessionId
- startedAt
- completedAt *(nullable)*
- status *(InProgress / Completed / Cancelled)*

### ImportFileRecord

- recordId
- sessionId *(FK → ImportSession)*
- accountId *(FK → BankAccount — tài khoản đích được gán cho riêng file này)*
- fileName
- detectedFormat *(Csv / Excel / Mt940 / Json)*
- orderIndex *(thứ tự người dùng chọn file — quyết định thứ tự ghi, xem Rule tương ứng)*
- importedCount • duplicateSkippedCount • errorRowCount
- status *(Completed / PartiallyFailed / Cancelled / Skipped)*
- revertedAt *(nullable — dấu đã hoàn tác; bản ghi lịch sử không bị xoá)*

### ImportErrorRow

- errorRowId
- recordId *(FK → ImportFileRecord)*
- sourceLineNumber *(số thứ tự dòng trong file gốc)*
- rawExcerpt *(trích đoạn dòng gốc, cắt ngắn)*
- reason *(lý do bị bỏ qua)*

### ReconciliationPair

- pairId
- outgoingTransactionId *(FK → Transaction — vế có amount âm)*
- incomingTransactionId *(FK → Transaction — vế có amount dương)*
- status *(Suggested / Confirmed)*
- createdAt
- confirmedAt *(nullable)*

### RejectedMatch

- rejectedMatchId
- transactionAId *(FK → Transaction)*
- transactionBId *(FK → Transaction — cặp không có thứ tự; luôn lưu theo định danh tăng dần để một lần tra là đủ)*
- rejectedAt
- *(Một giao dịch được phép xuất hiện trong nhiều RejectedMatch khác nhau — đây chính là lý do việc từ chối không thể là một trạng thái của ReconciliationPair, vốn giữ ràng buộc mỗi giao dịch thuộc tối đa một cặp.)*

### AppSettings *(bản ghi đơn nhất)*

- appLockEnabled
- pinHash *(nullable — chỉ tồn tại khi appLockEnabled = true; không bao giờ lưu PIN dạng thuần)*
- biometricEnabled *(chỉ có ý nghĩa trên native)*
- matchWindowDays *(mặc định 3)*

## Value Objects

- **Money** *(số nguyên có dấu ở đơn vị nhỏ nhất • mã loại tiền — không bao giờ là số thực; xem Rule tương ứng)*
- **Currency** *(mã ISO 4217; số chữ số thập phân của loại tiền quyết định đơn vị nhỏ nhất: VND và JPY là 0, USD và EUR là 2)*
- **Fingerprint** *(dẫn xuất từ accountId • bookingDate • amount • currency • description đã chuẩn hoá, qua đúng một hàm băm)*
- **SearchText** *(chỉ dựng được từ cặp counterpartyName • description qua đúng một thuật toán chuẩn hoá)*
- **StatementFormat** *(enum: Csv, Excel, Mt940, Json)*
- **PairStatus** *(enum: Suggested, Confirmed)*
- **ImportSessionStatus** *(enum: InProgress, Completed, Cancelled)*
- **ImportFileStatus** *(enum: Completed, PartiallyFailed, Cancelled, Skipped)*
- **MatchWindow** *(số ngày > 0; ràng buộc miền của tham số đối soát)*
- **DateRange • AmountRange** *(tiêu chí lọc ở UC-07; luôn đi theo cặp cận dưới/cận trên hợp lệ. AmountRange bắt buộc mang theo `currency` — một khoảng số tiền không có loại tiền là điều kiện vô nghĩa khi dữ liệu đa tệ)*

## Transient Types — dữ liệu đi qua ranh giới isolate, **không** phải Entity

Những kiểu dưới đây không được lưu, không có định danh nghiệp vụ, và tồn tại chỉ vì Dart isolate không chia sẻ bộ nhớ. Chúng phải là cấu trúc dữ liệu thuần, tuần tự hoá được:

- **ParsedRow** *(một dòng đã phân tích xong nhưng chưa là Transaction: chưa có accountId gán chắc, chưa có fingerprint đối chiếu, chưa có định danh)*
- **ParseBatch** *(một lô ParsedRow + số thứ tự lô + cờ lô cuối)*
- **ParseError** *(sourceLineNumber • reason — sau này mới trở thành ImportErrorRow)*
- **ProgressReport** *(số dòng đã xử lý • tổng ước lượng • recordId đang chạy)*
- **CancellationSignal** *(tín hiệu huỷ gửi vào isolate, chỉ được đọc tại ranh giới lô)*

# 3. Aggregates

- **BankAccount (Aggregate Root):** BankAccount — chỉ gồm chính nó
- **Transaction (Aggregate Root):** Transaction — **không** nằm trong BankAccount Aggregate
- **ImportSession (Aggregate Root):** ImportSession + ImportFileRecord + ImportErrorRow
- **ReconciliationPair (Aggregate Root):** ReconciliationPair
- **RejectedMatch (Aggregate Root):** RejectedMatch — bản ghi phán quyết, vòng đời chỉ phụ thuộc vào sự tồn tại của hai giao dịch nó trỏ tới
- **AppSettings (Aggregate Root):** bản ghi đơn nhất, vòng đời độc lập với mọi dữ liệu nghiệp vụ

⇒ **Transaction tách khỏi BankAccount là quyết định có chủ đích.** Về nghiệp vụ, giao dịch "thuộc về" tài khoản và xoá tài khoản thì xoá theo — nghe rất giống quan hệ Aggregate. Nhưng ranh giới Aggregate là ranh giới **nạp và ghi nhất quán**, mà một tài khoản có thể chứa hàng trăm nghìn giao dịch: gộp lại đồng nghĩa với việc mọi thao tác trên một giao dịch đều phải nạp cả tài khoản. Ràng buộc "xoá tài khoản thì xoá giao dịch" vì thế được thi hành **tường minh ở Application Layer** trong một transaction SQLite, không phải bằng cách nhét Transaction vào trong BankAccount.

⇒ Cùng lý do đó, đường đọc (danh sách giao dịch, tìm kiếm, lọc, thống kê) dùng **truy vấn trực tiếp** ở Application Layer, không nạp Aggregate. Đây là điều kiện bắt buộc để UC-04 hiển thị được tập dữ liệu lớn bằng cuộn lười.

# 4. Business Rules

### Rule – Single Context Is an Architectural Consequence

- Hệ thống chỉ có một Context vì chỉ có một tiến trình, một cơ sở dữ liệu SQLite cục bộ và một người dùng.
- Hệ quả có chủ đích: không có Context Map, không có Anti-Corruption Layer, không có eventual consistency, không có Domain Events. Đây là lựa chọn phù hợp quy mô, không phải thiếu sót.
- Ranh giới kỹ thuật thật sự của dự án **không phải** ranh giới service mà là **ranh giới isolate** — xem mục 5. Đó là chỗ duy nhất trong hệ thống mà dữ liệu phải được tuần tự hoá để đi qua.

### Rule – Money Is a Signed Integer, Never a Floating-Point Number

- Số tiền được lưu bằng **số nguyên ở đơn vị nhỏ nhất của loại tiền** (VND: đồng; USD: cent; JPY: yên), kèm dấu. Không dùng `double` ở bất kỳ đâu trong Domain.
- Số chữ số thập phân lấy theo **ISO 4217**, không đoán từ dữ liệu: `1,000,000.00` VND là một triệu đồng, còn `1,000.00` USD là một trăm nghìn cent. Parser đọc thấy nhiều chữ số thập phân hơn mức loại tiền cho phép thì ghi dòng lỗi, không làm tròn âm thầm.
- Lý do 1 — **chống trùng và đối soát đều so sánh bằng nhau tuyệt đối**. Với số thực, hai giá trị hiển thị giống hệt nhau vẫn có thể khác nhau ở bit cuối, khiến một giao dịch trùng lọt lưới hoặc một cặp đúng không ghép được. Đây không phải rủi ro lý thuyết: nó tấn công thẳng vào hai chức năng cốt lõi.
- Lý do 2 — thống kê cộng dồn trên hàng trăm nghìn dòng; sai số số thực tích luỹ theo số phép cộng, và số liệu tài chính lệch một đồng là số liệu sai.
- Việc quy đổi từ chuỗi trong file sang số nguyên diễn ra **trong isolate phân tích**, một lần duy nhất, và mọi tầng phía sau chỉ làm việc với số nguyên.

### Rule – Currency Belongs to the Transaction and Never Mixes

- `currency` là thuộc tính của **giao dịch**, không phải của tài khoản. Một tài khoản duy nhất có thể nhận cả VND, USD lẫn JPY — chuyện bình thường với doanh nghiệp có đối tác nước ngoài, và là lý do không thể gán cứng loại tiền vào `BankAccount`.
- Hai hệ quả: thống kê **tách theo từng loại tiền, không cộng gộp, không quy đổi** (UC-10); và **chỉ ghép cặp giữa hai giao dịch cùng loại tiền** (UC-08).
- Giới hạn phải ghi rõ: chuyển tiền nội bộ **có đổi loại tiền** (rút USD từ tài khoản ngoại tệ về tài khoản VND) nằm ngoài phạm vi đối soát. Hai vế khi đó lệch cả loại tiền lẫn giá trị vì tỷ giá và phí, nên không có cách nào ghép bằng đặc trưng số tiền. Đây là giới hạn có chủ đích, không phải sót.
- `currency` nằm trong `fingerprint`: hai giao dịch cùng ngày, cùng con số, khác loại tiền là hai giao dịch khác nhau.

### Rule – The Sign Carries the Direction

- Chiều tiền vào/ra được biểu diễn bằng **dấu của `amount`**, không bằng một cột loại giao dịch riêng.
- Lý do: các định dạng nguồn biểu diễn chiều rất khác nhau — MT940 dùng ký hiệu D/C, CSV thường tách hai cột ghi nợ/ghi có, JSON thì tuỳ hệ thống. Chuẩn hoá về một dạng chính tắc **ngay tại bước phân tích** là điều kiện để bốn parser khác nhau đổ chung vào một mô hình.
- Hệ quả trực tiếp: điều kiện ghép cặp ở UC-08 trở thành một phép kiểm đơn giản — hai giao dịch có `amount` đối nhau và khác tài khoản. Nếu để mỗi định dạng giữ cách biểu diễn riêng, luật ghép sẽ phải rẽ nhánh theo nguồn dữ liệu.

### Rule – Identity Is Local and Surrogate; Sameness Is Fingerprint

- Hệ thống có **hai khái niệm định danh tách bạch**: `transactionId` trả lời "đây là bản ghi nào", còn `fingerprint` trả lời "giao dịch này đã từng được nhập chưa".
- `transactionId` là số nguyên tự tăng cục bộ, **không** dùng UUID. Chỉ có một thiết bị sinh id nên không có nguy cơ đụng độ, trong khi khoá số nguyên rẻ hơn hẳn về bộ nhớ và tốc độ chỉ mục ở quy mô hàng trăm nghìn dòng — đúng quy mô mà dự án lấy làm trọng tâm. *(Khác với CK, nơi UUID v7 do client sinh là bắt buộc vì có nhiều thiết bị và có giai đoạn ngoại tuyến.)*
- `fingerprint` **không** phải ràng buộc duy nhất trong cơ sở dữ liệu, chỉ là chỉ mục. Hai dòng giống hệt nhau trong cùng một file là hai giao dịch thật khác nhau và phải được nhập đủ (UC-02). Đặt ràng buộc duy nhất lên đây là hiểu sai nghiệp vụ và sẽ **nuốt mất dữ liệu thật**.
- Vì vậy chống trùng là phép **đếm** chứ không phải phép kiểm tồn tại (cách đếm cụ thể ở UC-02).

### Rule – Deletion Is Physical, Not a Tombstone

- Xoá tài khoản, xoá giao dịch, xoá cặp đối soát đều **xoá vật lý** bản ghi. Không có `deletedAt`, không có tombstone.
- Lý do: tombstone tồn tại để **báo cho một bản sao khác biết rằng đã có thao tác xoá**. Ở đây không có bản sao nào — không đồng bộ, không nhiều thiết bị, không máy chủ. Giữ tombstone chỉ làm phình dữ liệu và bắt mọi truy vấn phải mang thêm điều kiện lọc, đổi lại không có ai được lợi.
- Ngoại lệ có chủ đích: `ImportFileRecord.revertedAt` **không phải** tombstone. Bản ghi vẫn hiển thị trong lịch sử với trạng thái đã hoàn tác, vì bản thân việc "tôi đã nhập file này rồi hoàn tác" là thông tin người dùng cần thấy, và dòng lỗi của nó vẫn phải xuất lại được (UC-11).
- `RejectedMatch` cũng **không phải** tombstone của cặp bị xoá: cặp vẫn bị xoá vật lý, thứ được giữ lại là **phán quyết của người dùng** — một bản ghi mới, tồn tại độc lập và sống lâu hơn cặp đã sinh ra nó.

### Rule – Provenance Is What Makes Undo Possible

- Mỗi Transaction bắt buộc trỏ về đúng một `ImportFileRecord`. Không có giao dịch "mồ côi": ứng dụng không có chức năng tạo giao dịch thủ công, chỉ có nhập từ file rồi sửa (UC-05).
- Lý do: hoàn tác ở UC-03 được định nghĩa là "xoá đúng những gì lượt nhập đó đã thêm". Không có liên kết nguồn gốc thì buộc phải suy đoán bằng thời gian nhập hoặc bằng fingerprint — cả hai đều xoá nhầm khi hai lượt nhập cùng tài khoản có phần giao nhau.

### Rule – Write Order Is Deterministic

- Trong một lượt nhiều file, thứ tự ghi vào cơ sở dữ liệu là **thứ tự người dùng đã chọn file** (`orderIndex`), không phải thứ tự isolate phân tích xong trước.
- Lý do: kết quả chống trùng phụ thuộc vào thứ tự ghi khi các file có khoảng thời gian chồng nhau. Để thứ tự ghi phụ thuộc vào tốc độ phân tích thì hai lần nhập cùng một tập file có thể cho ra hai kết quả khác nhau, và không lỗi nào loại này gỡ được vì không tái hiện được.
- Cùng một nguyên tắc lặp lại được đã được áp dụng cho việc chọn ứng viên ghép ở UC-08.

### Rule – Statistics Are Always Derived, Never Stored

- Không có bảng tổng hợp, không có cột tồn quỹ luỹ kế. Mọi số liệu ở UC-10 được tính bằng truy vấn tại thời điểm hiển thị.
- Lý do: một con số tổng đã lưu sẽ sai ngay khi bất kỳ đường nào trong **sáu** đường sau xảy ra — nhập thêm, hoàn tác lượt nhập, sửa giao dịch, xoá giao dịch, xác nhận cặp, từ chối cặp. Duy trì tính đúng đắn của nó đòi hỏi sáu chỗ vô hiệu hoá cache, và chỉ cần bỏ sót một chỗ là người dùng nhìn thấy số liệu tài chính sai mà không có dấu hiệu nào báo.
- Đánh đổi được chấp nhận vì dữ liệu nằm cục bộ và các cột tham gia đều có chỉ mục; nếu về sau chi phí tính toán trở thành vấn đề thật, đo được rồi hãy thêm cache — không thêm trước.

### Rule – Suggested Is Not Confirmed

- Chỉ cặp ở trạng thái **Confirmed** mới có hiệu lực nghiệp vụ: chỉ nó mới bị loại khỏi dòng tiền với bên ngoài ở UC-10, và chỉ nó mới sống sót qua một lần chạy lại đối soát.
- Lý do: thuật toán ghép dựa trên số tiền và cửa sổ thời gian **chắc chắn** sẽ trùng khớp ngẫu nhiên với những giao dịch không liên quan — đó là bản chất của việc ghép theo đặc trưng chứ không theo định danh. Để gợi ý tự động ảnh hưởng tới số liệu tài chính là để máy quyết một việc mà nó không có đủ căn cứ.
- Các ứng viên còn lại (UC-08) **không được lưu**: lưu sẵn là tạo một projection hỏng ngay khi bất kỳ cặp nào đổi trạng thái — đúng thứ Rule *Statistics Are Always Derived* cấm.
- Hệ quả kiến trúc: vị từ ghép cặp phải nằm ở **đúng một chỗ**, dùng chung cho lần quét theo lô và cho truy vấn ứng viên lúc hiển thị. Hai bản sao của cùng một điều kiện sẽ lệch nhau, và người dùng sẽ thấy một ứng viên xuất hiện ở màn hình này mà không xuất hiện ở màn hình kia.
- Ngược lại, việc **từ chối** một cặp phải được nhớ (`RejectedMatch`): đó là phán quyết về quá khứ, không phải hàm của trạng thái hiện tại. Không nhớ thì lần chạy lại đối soát sẽ gợi ý lại đúng cặp vừa bị từ chối, và người dùng không có đường nào thoát khỏi vòng lặp đó.

### Rule – Normalization Happens Once, at Import

- `searchText` và `fingerprint` đều được tính **một lần tại thời điểm nhập** và lưu thành cột có chỉ mục, không tính lại lúc truy vấn.
- Lý do: chi phí nặng được dồn về đúng nơi **đã có sẵn cơ chế xử lý nền, tiến trình và huỷ**; chuẩn hoá lúc gõ phím sẽ biến mỗi lần tìm kiếm thành một lần quét toàn bảng trên luồng chính.
- Cả hai giá trị phải được **tính lại khi giao dịch bị sửa tay** (UC-05), nếu không bản đã sửa sẽ vừa tìm không ra vừa bị coi là giao dịch mới ở lần nhập sau.

### Rule – File Time and Device Time Are Different Things

- `bookingDate` đến từ nội dung file và là **cơ sở duy nhất** cho mọi nghiệp vụ: sắp xếp danh sách, lọc theo khoảng ngày, gom nhóm thống kê, tính độ lệch trong cửa sổ ghép cặp.
- `importedAt` đến từ đồng hồ thiết bị và chỉ dùng cho lịch sử nhập.
- Lý do: sao kê được tải về và nhập vào bất cứ lúc nào sau khi giao dịch xảy ra, thường là hàng tuần sau. Lẫn hai mốc thời gian này sẽ làm hỏng đồng thời thống kê theo tháng và việc ghép cặp — hai giao dịch nhập cùng một buổi tối trông sẽ như xảy ra cùng lúc.

### Rule – The App Validates Identity, Never Content

- Ứng dụng chỉ kiểm được **file này có đúng là của tài khoản đích đã gán không** (đối chiếu `accountNumber` với số tài khoản nhúng trong file, ví dụ tag `:25:` của MT940). Nó **không có bất kỳ căn cứ nào** để xác minh nội dung giao dịch bên trong là đúng với thực tế.
- Đây là hệ quả trực tiếp của nguyên tắc offline: không có kết nối tới ngân hàng thì không có nguồn sự thật nào để đối chiếu.
- Hệ quả phải nói thẳng: người dùng sửa một giao dịch (UC-05) hay nhập một file bịa hoàn toàn thì hệ thống chấp nhận. Ứng dụng là công cụ **tổng hợp và đối chiếu dữ liệu do người dùng cung cấp**, không phải công cụ kiểm toán. Giới hạn này phải được ghi rõ ở mục Limitations của báo cáo thay vì để ngầm định.

# 5. Ranh giới Isolate — ràng buộc từ mô hình concurrency của Dart

Ràng buộc ở đây không đến từ một thư viện có thể thay thế, mà từ **mô hình bộ nhớ của chính ngôn ngữ** — không có đường vòng nào.

Dart isolate **không chia sẻ bộ nhớ**. Mọi thứ đi qua ranh giới đều phải tuần tự hoá được, và mọi thứ tuần tự hoá đều bị **sao chép**. Bảng dưới liệt kê các điểm mà ràng buộc này áp đặt ngược lên Domain Model.

| Điểm chạm | Quyết định | Vì sao — và hỏng ra sao nếu làm theo phản xạ tự nhiên |
| --- | --- | --- |
| Cái gì được đi qua ranh giới | Chỉ **ParsedRow / ParseBatch / ParseError / ProgressReport**. Entity của Domain **không bao giờ** đi qua. | 🔴 Phản xạ tự nhiên là để isolate trả thẳng về `List<Transaction>`. Nhưng Transaction cần `transactionId` do cơ sở dữ liệu cấp và cần đối chiếu fingerprint với dữ liệu đã có — hai thứ isolate không thể biết. Trả về Entity nửa vời sẽ tạo ra một loại đối tượng "trông như Transaction nhưng chưa hợp lệ" lây lan khắp hệ thống. |
| Hàm chạy trong isolate | Parser phải là **hàm top-level hoặc static**, không đóng gói (capture) bất kỳ trạng thái nào bên ngoài. | Đây là ràng buộc cứng của `compute` / `Isolate.run`. Kéo theo hệ quả kiến trúc thật: parser **không được** phụ thuộc vào repository, vào cấu hình toàn cục, hay vào bất cứ thứ gì trong container DI. Mọi thứ nó cần phải được truyền vào qua tham số. |
| Ghi vào cơ sở dữ liệu | SQLite **chỉ được ghi từ luồng chính**. Isolate phân tích không chạm vào tầng lưu trữ. | Đây là lý do gốc của việc tách hai giai đoạn ở UC-02. Nó cũng là lý do việc ghi tuần tự **không phải điểm nghẽn tự tạo ra**: phần tốn CPU (phân tích, chuẩn hoá, băm) đã được song song hoá toàn bộ, phần còn lại vốn dĩ đã buộc phải tuần tự. |
| Chi phí đi qua ranh giới | Truyền theo **lô**, không truyền từng dòng. | Mỗi lần gửi là một lần sao chép dữ liệu. Gửi từng dòng biến chi phí truyền thông điệp thành chi phí trội hơn cả chi phí phân tích — trường hợp mà việc dùng isolate làm mọi thứ *chậm đi*. Kích thước lô là tham số đánh đổi giữa độ mịn của tiến trình và chi phí điều phối, và là một trong những thứ đáng đo trong phần thực nghiệm. |
| Tiến trình và huỷ | Chỉ được đọc/báo **tại ranh giới giữa các lô**. | Isolate không bị ngắt được từ bên ngoài giữa chừng một phép tính. Hệ quả quan sát được: nút Huỷ phản hồi theo độ trễ bằng thời gian xử lý một lô, chứ không tức thì. Đây là hành vi được ghi nhận có chủ đích (UC-02, UC-14), không phải cam kết bị phá vỡ. |
| Bộ nhớ khi nhập nhiều file | **Hàng đợi lô chờ ghi có giới hạn** (backpressure); đầy thì isolate tạm dừng gửi. | Tốc độ phân tích nhanh hơn tốc độ ghi, và nhiều isolate cùng gửi về một luồng ghi duy nhất. Không có giới hạn này, nhập vài file lớn cùng lúc sẽ phình bộ nhớ cho tới khi ứng dụng bị hệ điều hành kết liễu — và lỗi chỉ hiện ra ở đúng kịch bản mà đề tài lấy làm trọng tâm. |
| Lan truyền lỗi | Lỗi từng dòng đi về như **dữ liệu** (`ParseError`), không phải như exception ném qua ranh giới. | Exception qua ranh giới isolate mất stack trace và làm chết cả tác vụ. Nhưng UC-02 yêu cầu một dòng hỏng **không được** làm dừng các dòng còn lại. Coi lỗi là dữ liệu là điều kiện để có được hành vi đó — và cũng là thứ làm cho ImportErrorRow tồn tại được. |
| Nền tảng Web | Không có `dart:isolate`; `compute()` suy biến thành gọi đồng bộ trên luồng chính. | 🔴 Đây là **điểm phân tích bắt buộc của báo cáo**, không phải khiếm khuyết cần giấu (UC-14). Suy biến xảy ra theo **hai chiều khác nhau**: mất isolate ⇒ giảm **độ mượt giao diện**; mất song song nhiều file ⇒ tăng **tổng thời gian hoàn tất**. Ngoài ra backpressure trở nên **thừa** trên Web vì phân tích và ghi cùng một luồng nên không bên nào chạy nhanh hơn bên kia — một kỹ thuật điều phối cần thiết trên nền tảng này và vô nghĩa trên nền tảng khác. |