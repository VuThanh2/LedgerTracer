import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Một ô tiền: chữ màu, căn phải, dấu luôn hiện, không nền và không viền.
///
/// Đây là kênh ngữ nghĩa "hướng tiền" của DESIGN.md, và hình thức của nó là
/// **bắt buộc** chứ không phải một lựa chọn trình bày. Dấu `+`/`−` do
/// `MoneyFormatter` sinh ra và luôn nằm trong [text]; màu chỉ là lớp thông tin
/// thứ hai, vì khoảng 8% nam giới không phân biệt được đỏ với lục và quy ước màu
/// tài chính Việt Nam không trùng với phương Tây.
///
/// Widget này cố ý **không** nhận `Money`: mọi định dạng đã xảy ra ở view model,
/// nên một dòng bảng không phải chạy lại bộ định dạng ở mỗi lần vẽ.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.text, {
    required this.isIncoming,
    this.style,
    this.textAlign = TextAlign.right,
    super.key,
  });

  /// Chuỗi đã định dạng, kể cả dấu.
  final String text;

  /// Quyết định màu. Lấy từ view model chứ không suy ra từ [text].
  final bool isIncoming;

  /// Ghi đè kiểu chữ; mặc định là `body-tabular`.
  final TextStyle? style;

  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Text(
      text,
      textAlign: textAlign,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: (style ?? LedgerText.bodyTabular).copyWith(
        color: colors.moneyColorOf(isIncoming: isIncoming),
      ),
    );
  }
}
