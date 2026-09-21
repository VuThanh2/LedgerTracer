import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../responsive/breakpoints.dart';

/// Khung của những màn **đẩy chồng** lên khung điều hướng — Cài đặt, Tài khoản
/// ngân hàng, Sao lưu, Diagnostics.
///
/// ## Vì sao hai hình thái
///
/// Ở bản hẹp, app bar là đường lùi: nó chở mũi tên Back mà điều hướng trên điện
/// thoại dựa vào, nên nó ở lại nguyên vẹn.
///
/// Ở bản rộng thì cùng một app bar trở thành một dải ngang chiếm trọn bề ngang
/// màn hình để chở đúng hai thứ nhỏ — một mũi tên và một dòng tiêu đề. Phần còn
/// lại là khoảng trống, và bên dưới nó là một danh sách thiết lập bị kéo giãn
/// hết cỡ: bố cục của điện thoại đem phóng to, không phải bố cục của web.
///
/// Bản rộng vì vậy bỏ app bar và dựng một **đầu trang** nằm trong chính cột nội
/// dung: lối lùi là một liên kết "Back" phía trên tiêu đề, và cả cột bị giới hạn
/// ở [contentMaxWidth] rồi căn giữa. Dòng chữ thiết lập khi ấy dài vừa tầm đọc
/// thay vì trải ngang 1900px.
class PushedPageScaffold extends StatelessWidget {
  const PushedPageScaffold({
    required this.title,
    required this.body,
    this.actions = const <Widget>[],
    this.contentMaxWidth = 880,
    super.key,
  });

  final String title;

  final Widget body;

  /// Hành động của màn. Ở bản hẹp chúng là `actions` của app bar, ở bản rộng
  /// chúng đứng cuối hàng tiêu đề — cùng một thứ tự đọc, hai chỗ đứng.
  final List<Widget> actions;

  /// Bề rộng tối đa của cột nội dung ở bản rộng.
  ///
  /// [double.infinity] cho màn thực sự cần cả bề ngang, ví dụ một bảng số liệu.
  final double contentMaxWidth;

  @override
  Widget build(BuildContext context) {
    final sizeClass = WindowSizeClass.of(MediaQuery.sizeOf(context).width);

    if (sizeClass.usesBottomNavigation) {
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          // Đệm mép phải là việc của khung, không của người gọi: ở bản rộng các
          // hành động này đứng trong một hàng đã có đệm riêng, nên một lớp
          // `Padding` gói sẵn ở chỗ gọi sẽ lệch khỏi nội dung bên dưới.
          actions: actions.isEmpty
              ? null
              : <Widget>[...actions, const SizedBox(width: Gap.lg)],
        ),
        body: body,
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _PageHeader(title: title, actions: actions),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Đầu trang của bản rộng: lối lùi, tiêu đề, và các hành động của màn.
class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.actions});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    // Màn Diagnostics chạy dưới bảng màu tối; lấy màu chữ từ chính theme của app
    // bar để đầu trang này đi theo, thay vì đóng đinh một màu sáng.
    final ink = Theme.of(context).appBarTheme.foregroundColor ?? colors.ink;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.screen, Gap.lg, Gap.screen, Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              style: TextButton.styleFrom(
                foregroundColor: ink,
                textStyle: LedgerText.bodySm,
                padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Back'),
            ),
          ),
          const SizedBox(height: Gap.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: LedgerText.headingLg.copyWith(color: ink),
                ),
              ),
              ...actions,
            ],
          ),
        ],
      ),
    );
  }
}
