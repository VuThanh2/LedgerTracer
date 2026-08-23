/// Các định dạng sao kê ứng dụng đọc được (UC-02).
///
/// PDF cố ý vắng mặt: sao kê PDF là văn bản bán cấu trúc, mỗi ngân hàng trình
/// bày một kiểu, việc trích xuất thuộc về OCR/heuristic chứ không thuộc trọng
/// tâm xử lý dữ liệu lớn của đề tài.
///
/// Người dùng không bao giờ phải chọn định dạng — việc nhận diện dựa trên nội
/// dung file (tầng Infrastructure); enum này chỉ ghi lại kết quả nhận diện.
enum StatementFormat { csv, excel, mt940, json }
