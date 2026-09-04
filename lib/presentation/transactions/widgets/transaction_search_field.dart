import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../shared/responsive/breakpoints.dart';

/// Ô tìm kiếm sống của UC-06.
///
/// Không tự debounce: khoảng lặng đã được `EventTransformers.searchInput` xử lý
/// ở BLoC, cùng chỗ với việc huỷ truy vấn cũ. Đặt thêm một bộ đếm giờ ở đây là
/// tạo hai nguồn thời gian cho cùng một hành vi, và chỉ một trong hai biết cách
/// huỷ lượt đang chạy.
class TransactionSearchField extends StatefulWidget {
  const TransactionSearchField({
    required this.keyword,
    required this.onChanged,
    super.key,
  });

  /// Từ khoá hiện tại theo BLoC. Dùng để đồng bộ khi ô được điền từ nơi khác
  /// (ví dụ xoá chip "Từ khoá"), không phải để vẽ mỗi lần gõ.
  final String keyword;

  final ValueChanged<String> onChanged;

  @override
  State<TransactionSearchField> createState() => _TransactionSearchFieldState();
}

class _TransactionSearchFieldState extends State<TransactionSearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.keyword,
  );

  @override
  void didUpdateWidget(TransactionSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Chỉ ghi đè khi BLoC và ô đã lệch nhau: gán vô điều kiện sẽ nhảy con trỏ về
    // cuối chuỗi ở mỗi ký tự gõ vào.
    if (widget.keyword != _controller.text) {
      _controller.text = widget.keyword;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final sizeClass = WindowSizeClass.of(MediaQuery.sizeOf(context).width);
    final height = sizeClass.usesBottomNavigation ? 48.0 : 40.0;

    return SizedBox(
      height: height,
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
        style: LedgerText.bodyMd.copyWith(color: colors.ink),
        decoration: InputDecoration(
          hintText: 'Search counterparty, memo…',
          prefixIcon: Icon(Icons.search, size: 16, color: colors.inkMute),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 36,
          ),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close, size: 16, color: colors.inkMute),
                  tooltip: 'Clear the keyword',
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}
