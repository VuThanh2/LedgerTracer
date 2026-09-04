import 'package:flutter/material.dart';

import '../failures/platform_notices.dart';
import 'banner_message.dart';

/// Chỉ báo suy biến của bản Web (UC-14).
///
/// Là **một** widget dùng ở cả hai nơi có tác vụ nền — bước 3 của luồng Nhập và
/// màn Đối soát khi đang chạy — chứ không phải hai câu chữ viết riêng, vì hai
/// nơi đó phải nói cùng một điều: không có isolate thì việc phân tích chia chung
/// luồng giao diện nên màn hình có thể giật, và không có song song nhiều file
/// nên tổng thời gian dài hơn.
///
/// Tự ẩn khi nền tảng có isolate, nên điểm gọi không phải tự viết điều kiện.
class WebLimitationBanner extends StatelessWidget {
  const WebLimitationBanner({required this.supportsIsolates, super.key});

  final bool supportsIsolates;

  @override
  Widget build(BuildContext context) {
    if (supportsIsolates) return const SizedBox.shrink();
    return const BannerMessage(PlatformNotices.webDegradation);
  }
}
