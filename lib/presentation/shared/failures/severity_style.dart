import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'feedback_message.dart';

/// Ba thứ mà một mức độ phản hồi quyết định: nền, mực, icon.
typedef SeverityStyle = ({Color background, Color foreground, IconData icon});

/// Bảng tra duy nhất từ [FeedbackSeverity] sang hình thức hiển thị.
///
/// Sống riêng một file vì có **hai** chỗ đọc nó — banner trong dòng chảy trang
/// và thông báo nổi ở góc màn. Hai bản sao của cùng bảng này là cách một lỗi
/// hiện màu đỏ ở banner và màu vàng ở toast, và không ai phát hiện cho tới khi
/// nhìn thấy cả hai cùng lúc.
SeverityStyle severityStyleOf(FeedbackSeverity severity, LedgerColors colors) =>
    switch (severity) {
      FeedbackSeverity.info => (
        background: colors.primaryWash,
        foreground: colors.primaryDeep,
        icon: Icons.info_outline,
      ),
      FeedbackSeverity.success => (
        background: colors.moneyInSoft,
        foreground: colors.moneyIn,
        icon: Icons.check_circle_outline,
      ),
      FeedbackSeverity.warning => (
        background: colors.creamWash,
        foreground: colors.lemonInk,
        icon: Icons.warning_amber_outlined,
      ),
      FeedbackSeverity.danger => (
        background: colors.rubyWash,
        foreground: colors.moneyOut,
        icon: Icons.error_outline,
      ),
    };
