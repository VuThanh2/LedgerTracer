# Use Case

**Actor trong hệ thống**

- **Người dùng:** người duy nhất sử dụng ứng dụng trên thiết bị, đóng vai trò chủ sở hữu toàn bộ tài khoản ngân hàng, giao dịch và thiết lập. Ứng dụng offline, không có khái niệm nhiều tài khoản người dùng hay đăng nhập từ xa.
- **Hệ thống:** tác vụ chạy tự động như một phần của luồng xử lý (đối soát, phát hiện nền tảng), không do người dùng chủ động kích hoạt từng bước riêng lẻ.

**Quy ước gộp/tách so với danh sách FR**

| Quyết định | Use Case | Lý do |
| --- | --- | --- |
| Gộp | UC-01 (FR-01, 02, 03) | Cùng một màn hình quản lý danh sách tài khoản, chỉ khác thao tác CRUD |
| Gộp | UC-02 (FR-04, 05, 06, 07, 09) | Cùng một luồng nhập file: chọn file → xử lý nền → báo lỗi/hủy → chống trùng. Nhập nhiều file (FR-09) là cùng luồng đó với N file, dùng chung toàn bộ quy tắc — tách riêng sẽ phải chép lại rồi lệch nhau |
| Gộp | UC-04 (FR-10, 11) | Xem danh sách và xem chi tiết là cùng một luồng duyệt dữ liệu thụ động |
| Gộp | UC-07 (FR-14, 15) | Cùng cơ chế lọc, chỉ khác tiêu chí, luôn dùng kết hợp với nhau và với tìm kiếm |
| Gộp | UC-09 (FR-17, 18) | Xem kết quả ghép cặp và xác nhận/từ chối là một luồng liên tục trên cùng màn hình |
| Gộp | UC-10 (FR-19, 20) | Cùng màn hình thống kê, chỉ khác trục nhóm (thời gian vs tài khoản) |
| Tách | UC-03 (FR-08) | Xem lịch sử & hoàn tác có tiền điều kiện khác hẳn (đã từng nhập ít nhất 1 lần) và là thao tác phá hủy cần xác nhận riêng |
| Tách | UC-05 (FR-12) | Sửa/xóa 1 giao dịch là thao tác có xác nhận riêng, khác luồng xem thụ động ở UC-04 |
| Tách | UC-11 (FR-21) | Xuất dữ liệu có nhiều điểm vào từ nhiều màn hình (UC-02, UC-03, UC-04, UC-09, UC-10) nhưng cùng một luồng và cùng bộ quy tắc; đặt tập trung một chỗ để các UC nguồn tham chiếu, tránh mô tả lặp ở từng màn hình rồi lệch nhau |
| Không tách UC riêng | FR-23 | Là ràng buộc kiến trúc xuyên suốt (offline-only), không phải hành vi có thể kích hoạt riêng lẻ — được nhắc lại trong Business Rules của các UC liên quan thay vì tách UC riêng |

# Quản lý Tài khoản Ngân hàng

## UC-01: Quản lý tài khoản ngân hàng

**Actor:**

- Người dùng

**Pre-Condition:**

- Người dùng đang ở màn hình Quản lý tài khoản.

**Main Flow:**

1. Hệ thống hiển thị danh sách toàn bộ tài khoản ngân hàng đã khai báo kèm tên hiển thị và số tài khoản đã ghi nhận (nếu có).
2. Người dùng có thể thêm tài khoản mới bằng cách nhập tên hiển thị.
3. Người dùng có thể sửa tên hiển thị của một tài khoản đã có, hoặc sửa / xóa số tài khoản mà hệ thống đã ghi nhận trước đó.
4. Người dùng có thể xóa một tài khoản sau khi xác nhận qua hộp thoại.
5. Hệ thống cập nhật danh sách và hiển thị thông báo tương ứng.

**Business Rules / Constraints:**

- Tên tài khoản là nhãn tự đặt để nhận diện trong ứng dụng (ví dụ "Tài khoản vận hành - Vietinbank"); không có kết nối hay xác thực với ngân hàng thật.
- Tên tài khoản không bắt buộc phải duy nhất, nhưng nên khác nhau để tránh nhầm lẫn khi chọn tài khoản đích lúc nhập file.
- Số tài khoản **không phải trường người dùng tự khai khi tạo tài khoản**: hệ thống tự ghi nhận từ file sao kê đầu tiên có mang nó (UC-02 bước 4). Màn hình này hiển thị số đã ghi nhận và cho sửa hoặc xóa, phòng khi lần nhập đầu gán nhầm file khiến hệ thống học sai.
- Xóa một tài khoản đồng thời xóa toàn bộ giao dịch của nó và **các bản ghi nhập của từng file có tài khoản đích là tài khoản này** (UC-03); hộp thoại xác nhận phải nêu rõ số giao dịch bị ảnh hưởng. Đơn vị bị xóa theo là bản ghi của từng file, không phải cả lượt — một lượt nhiều file có thể gán nhiều tài khoản khác nhau, xóa nguyên lượt sẽ xóa oan lịch sử của file thuộc tài khoản khác. Lượt nhập chỉ biến mất khi không còn bản ghi con nào.
- Giao dịch bị xóa theo tài khoản cũng phải tuân bất biến về cặp đối soát nêu tại UC-09.
- Việc thêm tài khoản cũng có thể được thực hiện trực tiếp ngay trong luồng nhập sao kê (UC-02) khi người dùng chưa có sẵn tài khoản phù hợp; không bắt buộc phải vào màn hình này trước.

# Nhập Sao kê Giao dịch

## UC-02: Nhập sao kê giao dịch

**Actor:**

- Người dùng

**Pre-Condition:**

- Người dùng đang ở màn hình Nhập sao kê. Người dùng đã có ít nhất một tài khoản, hoặc sẽ tạo tài khoản ngay trong luồng này.

**Main Flow:**

1. Người dùng chọn một hoặc nhiều file sao kê từ thiết bị.
2. Hệ thống tự động nhận diện định dạng của từng file (CSV, Excel, MT940, hoặc JSON).
3. Hệ thống hiển thị danh sách file đã chọn và yêu cầu gán tài khoản đích cho từng file: chọn tài khoản đã có, hoặc tạo tài khoản mới ngay tại chỗ.
4. Nếu định dạng file có chứa số tài khoản (ví dụ MT940): tài khoản đích chưa có số thì hệ thống **tự ghi nhận** số đó; đã có rồi thì **so khớp**. Nếu lệch, hệ thống cảnh báo và để người dùng chọn một trong ba: gán lại tài khoản đích khác, vẫn nhập vào tài khoản đang chọn, hoặc bỏ qua file này. Người dùng không phải gõ số tài khoản ở bất kỳ đâu.
5. Hệ thống xử lý các file trên luồng nền, hiển thị tiến trình theo thời gian thực, giữ giao diện phản hồi trong suốt quá trình.
6. Hệ thống bỏ qua các giao dịch đã tồn tại của cùng tài khoản — kể cả từ những lượt nhập trước lẫn từ file khác đã ghi xong trong chính lượt này.
7. Người dùng có thể hủy giữa chừng; các giao dịch đã xử lý xong trước thời điểm hủy vẫn được giữ lại.
8. Hệ thống hiển thị kết quả tổng kết theo từng file và tổng cộng: số giao dịch mới, số bị bỏ qua do trùng, số dòng lỗi; cho phép xuất danh sách dòng lỗi ra file (UC-11).

**Business Rules / Constraints:**

- Định dạng hỗ trợ: CSV, Excel (.xlsx/.xls), MT940, JSON; PDF nằm ngoài phạm vi (đã ghi trong Overview).
- Việc xử lý file không được làm đứng giao diện, kể cả với file có khối lượng giao dịch lớn — đây là workload chính dùng để chứng minh hiệu quả concurrency trong báo cáo.
- Workload được chia thành **các lô nhỏ**; sau mỗi lô, hệ thống báo tiến trình và kiểm tra yêu cầu hủy. Trên native vòng lặp này chạy trong isolate phụ; trên Web nó chạy trên luồng chính và nhường lượt giữa các lô. Hệ quả: tiến trình và nút Hủy **chỉ phản hồi tại ranh giới giữa các lô** — hành vi có chủ đích, chi tiết ở UC-14.
- Chống trùng dựa trên tổ hợp ngày, số tiền, loại tiền và nội dung của giao dịch trong cùng một tài khoản; đây không phải cơ chế xác thực giao dịch có thật ngoài đời.
- Phạm vi chống trùng là **giữa các lượt nhập, và giữa các file khác nhau trong cùng một lượt**, không áp dụng cho các dòng bên trong cùng một file. Hai dòng giống hệt nhau trong cùng một file là hai giao dịch thật khác nhau (ví dụ hai lần thanh toán cùng số tiền, cùng nội dung trong một ngày) và phải được nhập đủ.
- So khớp theo **số lượng bản ghi**, không phải theo sự tồn tại: đã có n bản ghi trùng khớp, file mang tới m bản ghi, chỉ nhập thêm phần chênh lệch. Vừa tránh nhân đôi khi nhập lại cùng file, vừa không nuốt mất giao dịch thật.
- Trong một lượt nhiều file, **giai đoạn phân tích và giai đoạn ghi được tách rời**: mọi file đều được phân tích song song — kể cả các file cùng một tài khoản — còn việc đối chiếu chống trùng và ghi vào cơ sở dữ liệu diễn ra tuần tự trên luồng chính. Nhờ tách hai giai đoạn, mỗi lô khi đến lượt ghi luôn nhìn thấy đầy đủ những gì đã ghi trước đó, kể cả từ file khác trong cùng lượt — hai sao kê có khoảng thời gian chồng nhau (ví dụ tháng 1–3 và tháng 2–4) vì thế không thể cùng nhìn thấy dữ liệu cũ rồi nhập trùng phần giao nhau.
- Thứ tự ghi phải **xác định được** (theo thứ tự file người dùng đã chọn), để hai lần nhập cùng một tập file cho ra cùng một kết quả — cùng nguyên tắc lặp lại được như ở UC-08.
- Các isolate phân tích gửi kết quả về theo từng lô và bị **giới hạn số lô đang chờ ghi**; khi hàng đợi đầy, isolate tạm dừng gửi cho đến khi luồng chính ghi bớt. Không có giới hạn này, nhập đồng thời nhiều file lớn sẽ phình bộ nhớ, vì tốc độ phân tích nhanh hơn tốc độ ghi.
- Hai file gán cho **hai tài khoản khác nhau** không bao giờ được coi là trùng nhau, kể cả khi cùng số tiền và thời điểm: đó là hai vế của một giao dịch chuyển tiền nội bộ, thuộc nghiệp vụ đối soát (UC-08), không phải trùng lặp.
- Cảnh báo sai tài khoản ở bước 4 chỉ nhằm phát hiện chọn nhầm tài khoản đích, không xác minh nội dung giao dịch, và chỉ có giá trị từ lần nhập thứ hai trở đi (số tài khoản được học từ chính lần nhập đầu). Nó áp dụng cho riêng file liên quan và xuất hiện **trước khi bắt đầu xử lý nền**, khi hệ thống mới chỉ đọc phần đầu file — nhờ vậy việc chờ người dùng quyết định không làm nghẽn hàng đợi ghi tuần tự ở bước 5.
- **Không chặn cứng** khi số tài khoản lệch, vì có lý do hợp lệ: ngân hàng cấp lại số, hoặc hệ thống đã học sai từ lần nhập đầu. Chọn "vẫn nhập" **không** ghi đè số đã ghi nhận — muốn đổi mốc đối chiếu thì sửa tường minh ở UC-01. Chọn "bỏ qua file này" được ghi nhận là file bị bỏ qua trong lịch sử nhập (UC-03), không phải lỗi đọc file.
- Hủy giữa chừng trong lượt nhiều file: file đã hoàn tất giữ nguyên, file đang xử lý giữ phần đã xong, file chưa bắt đầu bị bỏ qua hoàn toàn.
- Mỗi file được ghi nhận thành **một bản ghi riêng** trong lịch sử nhập (UC-03), nhóm dưới cùng một lượt.
- **Loại tiền đọc từ file theo từng giao dịch**, mặc định VND khi nguồn không nêu. Một tài khoản được phép chứa nhiều loại tiền; hệ thống không quy đổi và không từ chối giao dịch ngoại tệ.
- File hỏng, sai định dạng, hoặc chứa dòng dữ liệu không đọc được phải được báo lỗi rõ ràng theo từng dòng, không làm dừng toàn bộ quá trình nhập nếu các dòng khác vẫn hợp lệ.
- Kết quả nhập, kể cả khi có lỗi từng phần, phải được ghi nhận vào lịch sử nhập (UC-03) để có thể hoàn tác.
- Nhập lại chính file đã hủy giữa chừng là hợp lệ: chống trùng bỏ qua phần đã xong, chỉ nhận phần còn thiếu; ghi nhận thành một lượt nhập mới, không nối vào lượt đã hủy.

## UC-03: Xem lịch sử nhập & hoàn tác một lượt nhập

**Actor:**

- Người dùng

**Pre-Condition:**

- Đã có ít nhất một lượt nhập sao kê được thực hiện trước đó.

**Main Flow:**

1. Người dùng mở màn hình Lịch sử nhập.
2. Hệ thống hiển thị danh sách các lượt nhập theo thời gian gần nhất, mỗi lượt kèm tên file, tài khoản đích, số giao dịch đã thêm, thời điểm nhập.
3. Người dùng chọn một lượt nhập muốn hoàn tác.
4. Hệ thống hiển thị hộp thoại xác nhận, nêu rõ số giao dịch sẽ bị xóa.
5. Người dùng xác nhận.
6. Hệ thống xóa đúng các giao dịch thuộc lượt nhập đó, không ảnh hưởng đến giao dịch từ các lượt nhập khác.

**Business Rules / Constraints:**

- Nếu người dùng đã chỉnh sửa thủ công một giao dịch thuộc lượt nhập đó (UC-05), hệ thống cảnh báo trước khi hoàn tác vì thao tác có thể xóa luôn phần chỉnh sửa.
- Hoàn tác không được xóa nhầm giao dịch của lượt nhập khác, kể cả khi hai lượt nhập cùng tài khoản có giao dịch trùng thời gian.
- Giao dịch bị xóa do hoàn tác cũng phải tuân bất biến về cặp đối soát nêu tại UC-09; hộp thoại xác nhận ở bước 4 phải báo thêm số cặp đối soát sẽ bị hủy nếu có.
- Lượt nhập đã hoàn tác vẫn ở lại trong danh sách với trạng thái "đã hoàn tác", không biến mất: bản thân việc đã nhập rồi hoàn tác là thông tin người dùng cần thấy, và danh sách dòng lỗi của nó vẫn phải xuất lại được (UC-11).
- Lượt nhập bị hủy giữa chừng (UC-02 bước 7) vẫn xuất hiện trong lịch sử với trạng thái "chưa hoàn tất".
- Lượt nhập nhiều file hiển thị thành một nhóm gồm các bản ghi con theo từng file. Người dùng hoàn tác được từng file riêng lẻ hoặc cả nhóm; hoàn tác cả nhóm là lần lượt hoàn tác từng bản ghi con theo đúng quy tắc ở trên, không phải một cơ chế xóa riêng.
- Cho phép xuất lại danh sách dòng lỗi của một lượt nhập đã thực hiện (UC-11), vì người dùng có thể đã đóng màn hình tổng kết ở UC-02 bước 8 trước khi cần đến nó.

# Xem & Quản lý Giao dịch

## UC-04: Xem danh sách & chi tiết giao dịch

**Actor:**

- Người dùng

**Pre-Condition:**

- Người dùng đang ở màn hình danh sách giao dịch.

**Main Flow:**

1. Hệ thống tải và hiển thị giao dịch của toàn bộ tài khoản, sắp theo thời gian gần nhất trước.
2. Người dùng cuộn qua danh sách.
3. Người dùng chọn một giao dịch để xem chi tiết.
4. Hệ thống hiển thị đầy đủ thông tin: ngày, số tiền kèm loại tiền, tài khoản, nội dung, trạng thái đối soát nếu có, và số thứ tự dòng trong file gốc nếu xác định được.

**Business Rules / Constraints:**

- Danh sách phải hiển thị được ngay cả khi có hàng trăm nghìn giao dịch, không tải toàn bộ vào bộ nhớ cùng lúc (phân trang hoặc cuộn lười).
- Mỗi dòng trong danh sách phải hiển thị rõ giao dịch thuộc tài khoản nào, vì danh sách gộp chung mọi tài khoản; thiếu thông tin này người dùng không đọc hiểu được dữ liệu.
- Mọi số tiền hiển thị ở bất kỳ đâu đều phải **kèm loại tiền**: danh sách gộp chung nhiều loại tiền, một dòng ghi "1.000" trống trơn sẽ bị mặc định hiểu là VND.
- Khi danh sách rỗng, hệ thống hiển thị trạng thái trống có ý nghĩa, gợi ý người dùng nhập sao kê.
- Giao dịch đã được ghép cặp đối soát (UC-09) phải hiển thị chỉ báo tương ứng ngay trên danh sách.
- Danh sách mặc định gồm mọi tài khoản; thu hẹp về một tài khoản là việc của bộ lọc (UC-07), không phải một màn hình riêng — giữ cho duyệt/tìm/lọc dùng chung một danh sách, và hợp với bản chất xuyên tài khoản của đối soát (UC-08).

## UC-05: Sửa / xóa một giao dịch

**Actor:**

- Người dùng

**Pre-Condition:**

- Người dùng đang xem chi tiết một giao dịch.

**Main Flow:**

1. Người dùng chọn thao tác Sửa hoặc Xóa.
2. (Sửa) Hệ thống hiển thị biểu mẫu chỉnh sửa với dữ liệu hiện tại; người dùng thay đổi và lưu.
3. (Xóa) Hệ thống hiển thị hộp thoại xác nhận; người dùng xác nhận.
4. Hệ thống cập nhật hoặc xóa giao dịch và làm mới danh sách hiển thị.

**Business Rules / Constraints:**

- Xóa giao dịch luôn cần hộp thoại xác nhận, không có ngoại lệ.
- Sửa/xóa một giao dịch đang thuộc cặp đối soát (UC-09) phải hủy cặp đó và thông báo — áp dụng cho **cả cặp đã xác nhận lẫn cặp mới chỉ là gợi ý**, vì gợi ý sinh ra từ chính số tiền và thời điểm vừa bị thay đổi.
- Hủy cặp do sửa dữ liệu **không** được ghi thành phán quyết từ chối (UC-09): người dùng đang chỉnh dữ liệu sai, không phủ nhận rằng hai giao dịch là một cặp. Gộp hai tình huống sẽ khiến mỗi lần sửa là vô tình chặn vĩnh viễn giao dịch khỏi đối tác cũ.
- Đây là cơ chế duy nhất để sửa dữ liệu sai do lỗi phân tích file hoặc trùng lặp không bị chống trùng tự động phát hiện (ví dụ hai giao dịch thật trùng số tiền, trùng ngày với đối tác khác nhau); ứng dụng không có cơ chế nào khác xác minh tính đúng đắn của nội dung giao dịch.
- Vì lý do đó, màn hình chi tiết (UC-04) hiển thị **số thứ tự dòng trong file gốc** khi xác định được, để người dùng đối chiếu với file gốc trước khi sửa.

# Tìm kiếm Giao dịch

## UC-06: Tìm kiếm giao dịch tức thời

**Actor:**

- Người dùng

**Pre-Condition:**

- Người dùng đang ở màn hình có ô tìm kiếm.

**Main Flow:**

1. Người dùng gõ từ khóa.
2. Hệ thống chờ khoảng 300ms sau lần gõ cuối rồi bắt đầu tìm.
3. Hệ thống lọc giao dịch theo từ khóa xuất hiện trong tên người chuyển/nhận hoặc nội dung chuyển khoản.
4. Hệ thống hiển thị kết quả ngay trên danh sách; nếu không có kết quả, hiển thị trạng thái trống.

**Business Rules / Constraints:**

- Tìm kiếm bắt đầu ngay khi gõ, không cần nút riêng.
- Không phân biệt hoa/thường và dấu tiếng Việt.
- Chuỗi được chuẩn hóa **một lần tại thời điểm nhập** (UC-02) và lưu thành trường phụ có chỉ mục, không tính lại mỗi lần gõ — nhờ vậy tìm kiếm là truy vấn có chỉ mục thay vì quét toàn bảng.
- Tìm kiếm không được chặn giao diện. Khi người dùng gõ tiếp trong lúc một lượt tìm chưa xong, lượt cũ phải bị hủy và kết quả của nó bị bỏ qua, tránh kết quả của từ khóa cũ đến muộn rồi ghi đè kết quả của từ khóa mới.
- Kết hợp được với bộ lọc (UC-07).

## UC-07: Lọc giao dịch

**Actor:**

- Người dùng

**Pre-Condition:**

- Người dùng đang ở màn hình danh sách giao dịch.

**Main Flow:**

1. Người dùng mở bộ lọc.
2. Người dùng chọn khoảng số tiền và/hoặc khoảng thời gian, và/hoặc giới hạn theo một tài khoản cụ thể, và/hoặc theo một loại tiền.
3. Hệ thống áp dụng đồng thời các tiêu chí và cập nhật danh sách.
4. Hệ thống hiển thị rõ bộ lọc đang áp dụng và cho phép xóa từng tiêu chí.

**Business Rules / Constraints:**

- Các tiêu chí lọc kết hợp với nhau theo logic VÀ (giao dịch phải thỏa mãn tất cả tiêu chí đang bật).
- **Bộ lọc số tiền bắt buộc đi kèm một loại tiền**, vì so sánh hai con số khác đơn vị là phép toán vô nghĩa — khoảng "từ 1 triệu đến 5 triệu" sẽ loại nhầm giao dịch 1.000 USD. Khi dữ liệu có nhiều loại tiền, bật bộ lọc số tiền sẽ tự động bật kèm tiêu chí loại tiền (mặc định là loại tiền phổ biến nhất), người dùng đổi được; chỉ có một loại tiền thì ràng buộc này không hiện ra.
- Bộ lọc kết hợp được với từ khóa tìm kiếm (UC-06).
- Nếu không có giao dịch nào khớp, hiển thị trạng thái trống có ý nghĩa.

# Đối soát Giao dịch Nội bộ

## UC-08: Chạy đối soát nội bộ

**Actor:**

- Người dùng

**Pre-Condition:**

- Có ít nhất 2 tài khoản, mỗi tài khoản đã có giao dịch.

**Main Flow:**

1. Người dùng nhấn Chạy đối soát.
2. Hệ thống quét toàn bộ giao dịch chưa được ghép cặp, băm theo tổ hợp số tiền và khoảng thời gian để tìm ứng viên ghép nhanh.
3. Hệ thống ghép các cặp giao dịch **cùng loại tiền**, có số tiền đối nghịch (một bên âm, một bên dương) và thời điểm gần nhau, giữa hai tài khoản khác nhau.
4. Hệ thống hiển thị tiến trình và tổng số cặp tìm được khi hoàn tất.

**Business Rules / Constraints:**

- Việc quét và ghép cặp không được chặn giao diện, đặc biệt với khối lượng giao dịch lớn — đây là workload thứ hai dùng làm bằng chứng concurrency, khác đặc tính xử lý so với UC-02 (CPU-bound thuần túy thay vì I/O + parsing).
- Áp dụng cùng cơ chế chia lô và cùng hệ quả về độ mịn của tiến trình/hủy như mô tả tại UC-02, kể cả trên Web.
- Kết quả ghép chỉ là gợi ý; không tự động loại giao dịch khỏi thống kê cho đến khi được xác nhận (UC-09).
- Một giao dịch chỉ được ghép vào tối đa một cặp tại một thời điểm.
- Hai vế của một cặp phải **cùng loại tiền**. Chuyển tiền nội bộ có đổi loại tiền (ví dụ rút USD về tài khoản VND) nằm ngoài phạm vi đối soát: hai vế lệch cả loại tiền lẫn giá trị vì tỷ giá và phí, không ghép được bằng đặc trưng số tiền. Đây là giới hạn có chủ đích, ghi vào Limitations của báo cáo.
- Ngưỡng lệch thời gian mặc định ±3 ngày, phản ánh độ trễ xử lý giữa các ngân hàng; là tham số cấu hình được và người dùng chỉnh **ngay trên màn hình đối soát** — chỉ sau khi nhìn kết quả một lần chạy mới biết cần nới hay thu. Đổi ngưỡng chỉ ảnh hưởng lần chạy sau và **không** đụng tới cặp đã xác nhận, vì cặp đã xác nhận mang phán quyết của người dùng còn cửa sổ chỉ là tham số dò tìm.
- Khi một giao dịch có nhiều ứng viên ghép hợp lệ, hệ thống chọn ứng viên có độ lệch thời gian nhỏ nhất; nếu vẫn bằng nhau thì chọn theo thứ tự định danh giao dịch để kết quả lặp lại được giữa các lần chạy. Các ứng viên còn lại không bị loại âm thầm mà vẫn hiển thị ở UC-09 để người dùng tự quyết; danh sách này được **tính lại tại thời điểm hiển thị** bằng chính điều kiện ghép cặp ở bước 3, không lưu sẵn thành bản ghi.
- Chạy đối soát lại sẽ xóa toàn bộ cặp gợi ý **chưa xác nhận** và tính lại từ đầu, nhưng giữ nguyên mọi cặp **đã xác nhận**; nếu không, chạy nhiều lần sẽ tích lũy gợi ý trùng nhau.
- Các cặp đã bị **từ chối** (UC-09) bị loại khỏi tập ứng viên và không được gợi ý lại — phán quyết "không phải một cặp" là thông tin về quá khứ, không suy ra được từ dữ liệu hiện tại; không nhớ thì mỗi lần chạy lại sẽ đề xuất y nguyên cặp vừa bị từ chối.

## UC-09: Xem & xác nhận/từ chối kết quả đối soát

**Actor:**

- Người dùng

**Pre-Condition:**

- Đã chạy đối soát (UC-08). Màn hình vẫn mở được khi không còn cặp nào chờ quyết định, vì người dùng cần vào đây để xem lại và gỡ các phán quyết từ chối đã ghi.

**Main Flow:**

1. Hệ thống hiển thị danh sách các cặp đã ghép, mỗi cặp kèm 2 giao dịch, số tiền, và độ lệch thời gian.
2. Người dùng xem chi tiết một cặp.
3. Người dùng **xác nhận** cặp đúng, hoặc **từ chối** nếu cặp ghép sai.
4. Hệ thống cập nhật trạng thái: cặp đã xác nhận được loại khỏi dòng tiền "với bên ngoài" trong thống kê (UC-10); cặp bị từ chối biến khỏi danh sách và 2 giao dịch trở về trạng thái chưa ghép.
5. Người dùng mở danh sách **Đã từ chối** trên cùng màn hình để xem lại và gỡ một phán quyết nếu bấm nhầm; cặp được gỡ sẽ trở lại làm ứng viên ở lần chạy đối soát kế tiếp.

**Business Rules / Constraints:**

- Cặp ghép tự động không được coi là chính thức cho đến khi người dùng xác nhận, vì thuật toán ghép dựa trên số tiền/thời gian có thể trùng khớp ngẫu nhiên với giao dịch không liên quan.
- **Từ chối** là hành động duy nhất để loại một cặp, dùng chung cho cặp gợi ý lẫn cặp đã xác nhận — **không có thao tác "bỏ xác nhận" riêng**, để một nút chỉ mang một ý nghĩa. Đường lùi khi bấm nhầm là gỡ phán quyết ở bước 5.
- Từ chối một cặp ở bước 3 là **phán quyết "hai giao dịch này không phải một cặp"** và phải được ghi nhớ, tồn tại độc lập với cặp vừa bị xóa và sống sót qua các lần chạy lại đối soát (UC-08).
- Giao dịch thuộc cặp đã xác nhận hiển thị chỉ báo "đã đối soát" trong danh sách giao dịch (UC-04).
- Từ chối một cặp đã xác nhận trước đó phải cập nhật lại ngay số liệu thống kê nếu người dùng đang xem (UC-10).
- **Bất biến về cặp đối soát:** một cặp chỉ tồn tại khi cả hai giao dịch của nó còn tồn tại. Mọi đường dẫn xóa giao dịch — xóa lẻ (UC-05), xóa theo tài khoản (UC-01), hoàn tác lượt nhập (UC-03) — đều phải hủy cặp liên quan và trả giao dịch còn lại về trạng thái chưa ghép, đồng thời loại nó khỏi phần bị trừ trong thống kê (UC-10). Bất biến này áp dụng cho cả **phán quyết từ chối**: xóa một giao dịch cũng xóa mọi phán quyết từ chối có liên quan tới nó, vì phán quyết chỉ có nghĩa khi cả hai vế còn tồn tại. Quy tắc được đặt tập trung tại đây để các UC khác tham chiếu, tránh mô tả lặp ở nhiều nơi rồi lệch nhau.

# Thống kê Tổng hợp

## UC-10: Xem thống kê dòng tiền

**Actor:**

- Người dùng

**Pre-Condition:**

- Có ít nhất một tài khoản có giao dịch.

**Main Flow:**

1. Người dùng mở màn hình Thống kê.
2. Hệ thống hiển thị biểu đồ tổng tiền vào/ra theo mốc thời gian (mặc định theo tháng), **tách riêng theo từng loại tiền**. Nếu dữ liệu có nhiều loại tiền, các loại tiền hiện thành một dãy tab luôn nhìn thấy; mặc định mở ở loại tiền có nhiều giao dịch nhất.
3. Người dùng chuyển sang xem tách theo từng tài khoản.
4. Người dùng bật/tắt tùy chọn loại trừ các giao dịch nội bộ đã đối soát khỏi số liệu tổng.

**Business Rules / Constraints:**

- Khi bật loại trừ, các giao dịch thuộc cặp đã xác nhận đối soát (UC-09) không được cộng vào tổng dòng tiền, tránh đếm trùng dòng tiền tự luân chuyển nội bộ.
- Tùy chọn loại trừ **mặc định ở trạng thái bật**, vì dòng tiền thực với bên ngoài mới là con số người dùng cần; để mặc định tắt sẽ hiển thị số liệu bị đếm trùng cho đến khi người dùng tự mò ra chỗ bật.
- Vẫn giữ tùy chọn thay vì bỏ hẳn: tắt nó cho ra tổng thô trùng với sao kê gốc (cần khi đối chiếu lại với ngân hàng), và chênh lệch giữa hai chế độ chính là thứ cho thấy đối soát đã làm được gì.
- Số liệu của các loại tiền khác nhau **không bao giờ được cộng gộp và không được quy đổi**: tỷ giá đòi hỏi nguồn dữ liệu ngoài, trái với nguyên tắc offline, và tỷ giá tại thời điểm nào cũng là câu hỏi chưa có lời đáp.
- Sự tồn tại của các loại tiền khác phải **nhìn thấy được ngay**, không giấu sau một thao tác — người chủ yếu thu VND rất dễ nhìn một con số rồi tưởng đó là toàn bộ dòng tiền. Chỉ có một loại tiền thì không hiển thị bộ chọn, nhưng tiêu đề và trục **vẫn ghi mã loại tiền** (UC-04).
- Trạng thái tùy chọn loại trừ **không được ghi nhớ** giữa các lần mở màn hình; mỗi lần vào đều bắt đầu ở trạng thái bật, đúng theo quy tắc trên.
- Biểu đồ phải cập nhật ngay khi bật/tắt tùy chọn loại trừ, không cần tải lại màn hình.
- Số liệu chỉ phản ánh dữ liệu người dùng đã nhập; ứng dụng không có cơ sở nào để xác minh số liệu đó đúng với thực tế ngoài đời.

# Xuất Dữ liệu

## UC-11: Xuất dữ liệu ra file

**Actor:**

- Người dùng

**Pre-Condition:**

- Người dùng đang ở một màn hình có dữ liệu xuất được: danh sách giao dịch (UC-04), kết quả đối soát (UC-09), thống kê (UC-10), hoặc tổng kết/lịch sử một lượt nhập (UC-02, UC-03).

**Main Flow:**

1. Người dùng chọn thao tác Xuất ngay tại màn hình đang xem.
2. Người dùng chọn định dạng xuất (CSV hoặc Excel).
3. Hệ thống sinh file trên luồng nền, hiển thị tiến trình nếu khối lượng lớn.
4. Người dùng lưu file về thiết bị (Android) hoặc nhận file qua cơ chế tải xuống của trình duyệt (Web).

**Business Rules / Constraints:**

- Bốn nguồn dữ liệu xuất được: danh sách giao dịch (UC-04), kết quả đối soát (UC-09), số liệu thống kê (UC-10), và danh sách dòng lỗi của một lượt nhập (UC-02 bước 8 hoặc UC-03).
- File xuất phải phản ánh **đúng trạng thái người dùng đang xem**: danh sách giao dịch xuất theo từ khóa tìm kiếm và bộ lọc đang áp dụng (UC-06, UC-07); thống kê xuất theo loại tiền đang mở và theo trạng thái tùy chọn loại trừ giao dịch nội bộ (UC-10). Các tiêu chí này **kèm loại tiền** phải được ghi ở đầu file — nếu không, người nhận file không có cách nào biết dữ liệu đã bị thu hẹp bởi điều kiện gì, và một bảng số liệu không ghi đơn vị tiền tệ sẽ bị mặc định hiểu là VND.
- Danh sách dòng lỗi phải kèm **số thứ tự dòng trong file gốc** và lý do bị bỏ qua, để người dùng sửa trên file gốc rồi nhập lại — luồng này khả thi nhờ chống trùng ở UC-02.
- File xuất **không được mã hóa**, khác với file sao lưu ở UC-13: nó tồn tại để mở bằng Excel hoặc gửi cho kế toán, mã hóa sẽ triệt tiêu chính mục đích đó. Nguyên tắc riêng tư ngăn dữ liệu bị gửi tới bên thứ ba, không ngăn người dùng lấy dữ liệu của chính họ ra. Việc không mã hóa được nêu ngay trong hộp thoại chọn định dạng ở bước 2.
- Việc sinh file không được chặn giao diện.
- Khác biệt nền tảng: trên Android người dùng chọn được vị trí lưu; trên Web file đi qua cơ chế tải xuống của trình duyệt, không chọn được đường dẫn (giống UC-13).
- Xuất là thao tác **chỉ đọc**: không thay đổi, không đánh dấu, không xóa bất kỳ dữ liệu nào trong ứng dụng.

# Hệ thống

## UC-12: Khóa ứng dụng cục bộ

**Actor:**

- Người dùng

**Pre-Condition:**

- Người dùng đang ở màn hình Thiết lập.

**Main Flow:**

1. Người dùng bật tùy chọn khóa ứng dụng.
2. Hệ thống yêu cầu thiết lập mã PIN. Trên native, người dùng có thể bật thêm sinh trắc học nếu thiết bị hỗ trợ.
3. Từ lần mở ứng dụng sau, hệ thống yêu cầu xác thực trước khi hiển thị bất kỳ dữ liệu nào.
4. Người dùng có thể đổi mã PIN hoặc tắt hẳn tính năng khóa tại cùng màn hình Thiết lập.

**Business Rules / Constraints:**

- Mặc định tắt; đây là lớp bảo vệ truy cập thiết bị, không phải tài khoản người dùng đám mây.
- **PIN là bắt buộc khi bật khóa; sinh trắc học là lớp mở khóa nhanh đặt lên trên nó**, không phải lựa chọn thay thế. Ở bước mở khóa trên native hai cách dùng được như nhau; không có PIN thì cảm biến hỏng là mất đường vào, và cùng dữ liệu đó trên Web không có gì mở được.
- Khác biệt nền tảng: sinh trắc học chỉ có trên native, Web chỉ dùng PIN; "reset ứng dụng" trên Web là xóa dữ liệu lưu trong trình duyệt, khác với gỡ ứng dụng trên Android.
- Mã PIN không được lưu ở dạng văn bản thuần trên thiết bị.
- Đổi PIN và tắt khóa đều bắt buộc nhập đúng PIN hiện tại trước; không được tắt chỉ bằng một thao tác đơn không xác thực, vì như vậy người cầm thiết bị đang mở sẽ vô hiệu hóa được lớp bảo vệ.
- Quên PIN thì lối thoát duy nhất là reset ứng dụng — xóa toàn bộ dữ liệu cục bộ, lấy lại bằng cách khôi phục từ bản sao lưu đã mã hóa (UC-13). Không có cơ chế bỏ qua PIN nào, vì như vậy sẽ vô hiệu hóa chính lớp bảo vệ này.

## UC-13: Sao lưu & khôi phục dữ liệu

**Actor:**

- Người dùng

**Pre-Condition:**

- Sao lưu: đã có dữ liệu trong ứng dụng. Khôi phục: có sẵn file sao lưu hợp lệ.

**Main Flow:**

1. Người dùng chọn Sao lưu và **đặt một mật khẩu cho file sao lưu**; hệ thống xuất toàn bộ dữ liệu (tài khoản, giao dịch, kết quả đối soát, phán quyết từ chối) ra một file được mã hóa bằng khóa dẫn xuất từ mật khẩu đó, người dùng tự lưu file này ở nơi họ chọn.
2. Người dùng chọn Khôi phục, chọn file sao lưu và nhập mật khẩu của file đó.
3. Hệ thống giải mã và kiểm tra tính toàn vẹn của file; sai mật khẩu thì báo lỗi và không đụng tới dữ liệu hiện có.
4. Hệ thống cảnh báo rằng toàn bộ dữ liệu hiện có sẽ bị thay thế, và chỉ tiến hành ghi đè sau khi người dùng xác nhận.

**Business Rules / Constraints:**

- File sao lưu phải được mã hóa. Quy tắc này áp dụng riêng cho **sao lưu** — nơi toàn bộ dữ liệu rời khỏi ứng dụng và chỉ để chính ứng dụng đọc lại; nó **không** áp dụng cho file xuất báo cáo ở UC-11, vốn là tập con do người dùng chủ động chọn và tồn tại để mở bằng công cụ khác.
- Mật khẩu sao lưu **hoàn toàn độc lập với mã PIN khóa ứng dụng** (UC-12) và ứng dụng không giữ bản sao nào của nó. Lý do bắt buộc: lối thoát khi quên PIN là reset ứng dụng rồi khôi phục từ sao lưu — nếu file sao lưu được mã hóa bằng khóa dẫn xuất từ chính PIN đã quên thì hai use case triệt tiêu nhau, quên PIN là mất trắng cả dữ liệu lẫn bản sao lưu.
- Mất mật khẩu sao lưu thì không có đường khôi phục file đó; cảnh báo này phải hiện ngay tại bước 1.
- Khác biệt nền tảng: trên Web, xuất/nhập file đi qua cơ chế tải xuống và tải lên của trình duyệt, không chọn được đường dẫn lưu như trên Android.
- Khôi phục từ file sai định dạng hoặc bị hỏng phải báo lỗi rõ ràng, không được làm hỏng dữ liệu hiện có trong ứng dụng.
- Khôi phục chỉ hỗ trợ **ghi đè toàn bộ**, không hợp nhất với dữ liệu đang có. Lý do: cả ba tình huống khôi phục thực tế (cài lại ứng dụng, mất thiết bị, reset do quên PIN) đều diễn ra trên một ứng dụng trống, nơi ghi đè và hợp nhất cho kết quả như nhau.

## UC-14: Cảnh báo giới hạn xử lý nền trên Web

**Actor:**

- Hệ thống

**Pre-Condition:**

- Ứng dụng đang chạy trên Flutter Web.

**Main Flow:**

1. Khi người dùng kích hoạt một tác vụ vốn dùng isolate trên nền tảng native (nhập sao kê UC-02 hoặc đối soát UC-08), hệ thống phát hiện đang chạy trên Web.
2. Hệ thống hiển thị rõ ràng rằng cơ chế xử lý nền trên Web suy biến thành đồng bộ trên luồng chính.
3. Tác vụ vẫn được thực thi, có thể gây giật giao diện tạm thời trên Web — đây là hành vi được ghi nhận có chủ đích, không phải lỗi.

**Business Rules / Constraints:**

- Không được che giấu giới hạn này; đây là điểm phân tích bắt buộc trong báo cáo (so sánh mô hình isolate của Dart trên native vs. Web).
- Giới hạn này kéo theo hệ quả quan sát được ở UC-02 và UC-08: tiến trình và nút Hủy vẫn hoạt động nhưng chỉ phản hồi tại ranh giới giữa các lô xử lý. Chỉ báo phải nói đúng điều này thay vì chỉ nói chung chung rằng "Web chậm hơn".
- Chỉ dùng một chỉ báo thống nhất, xuất hiện tại các luồng thực sự có tác vụ nền (UC-02, UC-08); không lặp lại thông báo ở nhiều nơi gây nhiễu trải nghiệm.
- Trên Web, việc **phân tích song song nhiều file** (UC-02) cũng suy biến: các file được phân tích nối tiếp nhau trên luồng chính thay vì song song. Đây là chiều suy biến thứ hai bên cạnh việc mất isolate cho từng file; hai chiều có cùng nguyên nhân nhưng biểu hiện khác nhau — mất song song làm **tổng thời gian hoàn tất** dài hơn, còn mất isolate làm **độ mượt giao diện** giảm. Báo cáo phải tách bạch hai hệ quả này thay vì gộp thành "Web chậm hơn".
- Trên Web, cơ chế giới hạn số lô chờ ghi ở UC-02 không còn ý nghĩa thực tiễn, vì phân tích và ghi cùng nằm trên một luồng nên không bên nào chạy nhanh hơn bên kia để gây dồn ứ. Đây là ví dụ cho thấy một kỹ thuật điều phối có thể cần thiết trên nền tảng này nhưng thừa trên nền tảng khác.