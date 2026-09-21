/// Cờ mở khoá màn Developer Diagnostics, sống đúng bằng **một phiên chạy** ứng
/// dụng.
///
/// ## Vì sao không nằm trong `SettingsBloc`
///
/// `SettingsBloc` được tạo lại mỗi lần route Settings được đẩy lên, nên một cờ
/// đặt trong trạng thái của nó biến mất ngay khi người dùng rời màn — và họ phải
/// chạm lại bảy lần cho mỗi lần muốn đo. Cờ này sống ở gốc ứng dụng, nên mở một
/// lần là dùng được tới hết phiên.
///
/// ## Vì sao không lưu xuống cơ sở dữ liệu
///
/// Mục ẩn không có nút tắt. Ghi xuống đĩa nghĩa là một lần chạm nhầm bảy cái sẽ
/// để lại một lối vào workload nặng **vĩnh viễn**, không có đường lùi nào ngoài
/// việc xoá dữ liệu ứng dụng. Buộc nó chết theo tiến trình là cách rẻ nhất để
/// "mở nhầm" luôn có đường về: khởi động lại là hết.
final class DiagnosticsUnlock {
  DiagnosticsUnlock();

  bool _isUnlocked = false;

  bool get isUnlocked => _isUnlocked;

  /// Một chiều: đã mở thì ở lại tới khi tiến trình kết thúc. Không có `lock()`
  /// vì không có giao diện nào gọi nó — thêm vào là thêm một trạng thái không ai
  /// đọc.
  void unlock() => _isUnlocked = true;
}
