/// Vòng đời của một cặp đối soát (UC-08, UC-09).
///
/// Chỉ [confirmed] mới có hiệu lực nghiệp vụ: chỉ nó bị loại khỏi dòng tiền với
/// bên ngoài (UC-10) và chỉ nó sống sót qua một lần chạy lại đối soát
/// (Rule – Suggested Is Not Confirmed).
///
/// Ở đây không có giá trị "đã từ chối": từ chối là xoá cặp và ghi lại một
/// `RejectedMatch` riêng, vì một giao dịch có thể bị từ chối với nhiều giao dịch
/// khác nhau trong khi nó chỉ thuộc tối đa một cặp.
enum PairStatus {
  /// Máy đề xuất, đang chờ người dùng quyết.
  suggested,

  /// Người dùng đã xác nhận.
  confirmed,
}
