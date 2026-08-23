# Functional Requirement

## Quản lý Tài khoản Ngân hàng

- **FR-01 Thêm tài khoản:** Cho phép người dùng khai báo một tài khoản ngân hàng mới để nhập dữ liệu giao dịch vào.
- **FR-02 Xem danh sách tài khoản:** Cho phép người dùng xem toàn bộ tài khoản ngân hàng đã khai báo.
- **FR-03 Cập nhật / Xóa tài khoản:** Cho phép người dùng sửa thông tin hoặc xóa một tài khoản ngân hàng.

## Nhập Sao kê Giao dịch

- **FR-04 Nhập sao kê giao dịch:** Cho phép người dùng nhập file sao kê ở nhiều định dạng (CSV, Excel .xlsx/.xls, MT940, JSON).
- **FR-05 Nhập liệu không chặn giao diện:** Hiển thị tiến trình và giữ giao diện phản hồi khi xử lý file lớn.
- **FR-06 Báo lỗi và hủy nhập:** Báo lỗi khi file hỏng hoặc sai định dạng; cho phép hủy giữa chừng.
- **FR-07 Chống trùng lặp khi nhập lại:** Bỏ qua giao dịch đã tồn tại khi người dùng nhập lại cùng một file.
- **FR-08 Xem lịch sử nhập & hoàn tác một lượt nhập:** Cho phép xem các lượt nhập đã thực hiện và hoàn tác một lượt nhập bị sai mà không ảnh hưởng các dữ liệu khác.
- **FR-09 Nhập nhiều file trong một lượt:** Cho phép người dùng chọn nhiều file sao kê cùng lúc và xử lý song song trong một lượt nhập.

## Xem & Quản lý Giao dịch

- **FR-10 Xem danh sách giao dịch:** Cho phép người dùng duyệt giao dịch từ mọi tài khoản trên cùng một danh sách, không cần tìm kiếm.
- **FR-11 Xem chi tiết một giao dịch:** Cho phép người dùng xem đầy đủ thông tin của một giao dịch cụ thể.
- **FR-12 Sửa / Xóa một giao dịch:** Cho phép người dùng chỉnh sửa hoặc xóa một giao dịch đơn lẻ bị nhập sai.

## Tìm kiếm Giao dịch

- **FR-13 Tìm kiếm tức thời:** Cho phép tìm giao dịch theo tên hoặc nội dung chuyển khoản, kết quả cập nhật khi gõ.
- **FR-14 Lọc theo số tiền và thời gian:** Cho phép thu hẹp danh sách theo khoảng giá trị và khoảng ngày.
- **FR-15 Lọc theo tài khoản:** Cho phép thu hẹp danh sách về một tài khoản ngân hàng cụ thể.

## Đối soát Giao dịch Nội bộ

- **FR-16 Chạy đối soát:** Cho phép người dùng khởi chạy quá trình quét và ghép cặp các giao dịch chuyển–nhận nội bộ giữa các tài khoản.
- **FR-17 Xem kết quả đối soát:** Cho phép xem danh sách và chi tiết các cặp giao dịch đã được ghép.
- **FR-18 Xác nhận / Hủy một cặp ghép:** Cho phép xác nhận một cặp ghép đúng hoặc hủy một cặp ghép sai.

## Thống kê Tổng hợp

- **FR-19 Xem tổng dòng tiền theo thời gian:** Cho phép xem tổng tiền vào/ra theo mốc thời gian dưới dạng biểu đồ, có tùy chọn loại trừ giao dịch nội bộ đã đối soát.
- **FR-20 Xem tổng dòng tiền theo tài khoản:** Cho phép xem số liệu tổng hợp tách riêng theo từng tài khoản dưới dạng biểu đồ.

## Xuất Dữ liệu

- **FR-21 Xuất dữ liệu ra file:** Cho phép người dùng xuất danh sách giao dịch, kết quả đối soát, số liệu thống kê, hoặc danh sách dòng lỗi của một lượt nhập ra file CSV hoặc Excel.

## Hệ thống

- **FR-22 Khóa ứng dụng cục bộ:** Cho phép bật/tắt yêu cầu mã PIN hoặc sinh trắc học khi mở ứng dụng, mặc định tắt.
- **FR-23 Lưu trữ hoàn toàn offline:** Toàn bộ dữ liệu được lưu trữ cục bộ trên thiết bị, không gửi lên máy chủ bên thứ ba.
- **FR-24 Sao lưu & Khôi phục dữ liệu:** Cho phép xuất toàn bộ dữ liệu ra file đã mã hóa và khôi phục lại từ file đó khi cài lại ứng dụng, mất thiết bị, hoặc sau khi bị reset do quên PIN.
- **FR-25 Cảnh báo giới hạn xử lý nền trên Web:** Thể hiện rõ ràng khi chạy trên Flutter Web rằng cơ chế xử lý nền suy biến thành đồng bộ trên main thread.