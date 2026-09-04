/// Ba lớp bề rộng cửa sổ, và các quyết định hình thái đi kèm.
///
/// Ứng dụng là **một** ứng dụng adaptive, không phải hai ứng dụng chung repo:
/// không màn hình nào chỉ có ở một nền tảng, và không tính năng nào bị cắt bớt
/// theo bề rộng. Thứ thay đổi chỉ là hình thái trình bày — danh sách đẩy sang
/// màn hình chi tiết hay mở ra pane bên phải, bộ lọc là bottom sheet hay panel
/// cố định, điều hướng là thanh dưới hay rail dọc.
///
/// Vì vậy các vị từ dưới đây trả lời câu hỏi **hình thái**, không trả lời câu
/// hỏi "đây có phải điện thoại không". Hỏi nền tảng để quyết định bố cục là chỗ
/// một cửa sổ hẹp trên máy tính để bàn bị vẽ như màn hình rộng.
enum WindowSizeClass {
  /// Dưới 600dp: điện thoại dựng đứng, hoặc cửa sổ web thu hẹp.
  compact,

  /// 600–1023dp: máy tính bảng, hoặc cửa sổ web cỡ vừa.
  medium,

  /// Từ 1024dp: máy tính bàn và máy tính bảng nằm ngang.
  expanded;

  /// Ranh giới lấy từ hệ thiết kế; đọc theo chiều rộng khả dụng của **khung
  /// chứa**, không phải của thiết bị.
  static const double mediumMinWidth = 600;
  static const double expandedMinWidth = 1024;

  static WindowSizeClass of(double width) {
    if (width >= expandedMinWidth) return WindowSizeClass.expanded;
    if (width >= mediumMinWidth) return WindowSizeClass.medium;
    return WindowSizeClass.compact;
  }

  /// Danh sách và chi tiết cùng nhìn thấy được. Chỉ [expanded] đủ chỗ cho hai
  /// pane mà cột số tiền không bị bóp.
  bool get usesTwoPane => this == WindowSizeClass.expanded;

  /// Điều hướng bằng thanh dưới ([compact]) hay rail dọc bên trái.
  bool get usesBottomNavigation => this == WindowSizeClass.compact;

  /// Rail chỉ hiện nhãn khi đủ rộng; ở [medium] nó thu về chỉ còn icon.
  bool get showsNavigationLabels => this == WindowSizeClass.expanded;

  /// Bộ lọc là panel cố định bên phải khi có hai pane, còn lại là bottom sheet.
  bool get usesFilterPanel => usesTwoPane;

  /// Mật độ dòng của bảng giao dịch, tính bằng dp.
  ///
  /// Hai con số khác nhau vì lý do khác nhau chứ không phải vì thẩm mỹ: dòng
  /// hẹp cho phép nhìn thấy nhiều giao dịch hơn trong một màn hình — điều đáng
  /// giá ở màn hình chính của một công cụ dày dữ liệu — còn dòng cao là vùng
  /// chạm tối thiểu để ngón tay không bấm nhầm sang dòng bên cạnh.
  double get rowHeight => this == WindowSizeClass.compact ? 52 : 36;

  /// Vùng chạm tối thiểu của một điều khiển.
  double get minTouchTarget => this == WindowSizeClass.compact ? 48 : 32;

  /// Đệm trong của thẻ.
  double get cardPadding => this == WindowSizeClass.compact ? 24 : 16;

  /// Số dòng nạp mỗi lần cuộn lười.
  ///
  /// Gắn với mật độ dòng chứ không phải một hằng số duy nhất: một trang phải phủ
  /// được nhiều hơn một màn hình, nếu không thì cuộn tới đâu chờ tới đó. Ở
  /// [expanded] một màn hình chứa được nhiều dòng hơn hẳn, nên trang cũng phải
  /// dày hơn.
  int get pageSize => switch (this) {
    WindowSizeClass.compact => 50,
    WindowSizeClass.medium => 80,
    WindowSizeClass.expanded => 120,
  };
}
