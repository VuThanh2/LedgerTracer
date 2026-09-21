import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../failures/feedback_message.dart';
import '../failures/severity_style.dart';
import '../responsive/breakpoints.dart';

/// Nơi mọi thông báo ngắn của ứng dụng hiện ra: một chồng thẻ ở **mép trên**,
/// bên phải khi màn đủ rộng.
///
/// ## Vì sao không dùng `SnackBar`
///
/// `SnackBar` neo cứng ở đáy màn hình và, ở chế độ nổi, kéo dài gần hết bề ngang
/// cửa sổ. Trên một cửa sổ desktop 1900px, một câu tám chữ trở thành một dải
/// ngang chạy suốt đáy màn — xa chỗ mắt đang nhìn, và xa chỗ vừa xảy ra thao tác
/// sinh ra nó.
///
/// ## Vì sao là một chồng, không phải một cái
///
/// Các điểm gọi trước đây đều `hideCurrentSnackBar()` rồi hiện cái mới, nên thao
/// tác thứ hai xoá mất kết quả của thao tác thứ nhất trước khi kịp đọc. Ở đây
/// chúng xếp chồng, tối đa [maxVisible] thẻ — cái cũ nhất bị đẩy ra khi quá số
/// đó, chứ không phải cái mới nhất bị nuốt.
///
/// Đặt một lần ở `MaterialApp.builder`, tức là **trên** `Navigator`, nên thông
/// báo vẫn nhìn thấy được khi có hộp thoại đang mở.
class NoticeOverlay extends StatefulWidget {
  const NoticeOverlay({required this.child, super.key});

  final Widget child;

  /// Số thẻ hiện cùng lúc ở bản rộng, nơi chồng thẻ nằm nép ở góc phải.
  static const int maxVisible = 2;

  /// Bản hẹp chỉ giữ **một** thẻ: ở đó thẻ trải hết bề ngang ngay dưới app bar,
  /// và hai ba thẻ chồng lên nhau là che mất thanh công cụ lẫn dòng đầu danh
  /// sách — đúng chỗ người dùng đang bấm tiếp trong một chuỗi thao tác nhanh
  /// (xác nhận/từ chối liên tục ở Đối soát). Thẻ mới nhất là kết quả của cú bấm
  /// mới nhất, nên nó là thẻ đáng giữ.
  static const int maxVisibleCompact = 1;

  /// Thời gian một thẻ tự ở lại trước khi biến mất.
  ///
  /// Ba giây đủ đọc một câu ngắn; bốn giây trước đây làm các thẻ của một chuỗi
  /// bấm nhanh dồn lại thành một chồng.
  static const Duration visibleFor = Duration(seconds: 3);

  /// Thẻ mang hành động (ví dụ Hoàn tác) ở lại lâu hơn: đọc một câu thì nhanh,
  /// quyết định có hoàn tác hay không thì không.
  static const Duration visibleWithActionFor = Duration(seconds: 5);

  /// Bề ngang tối đa của một thẻ ở bản rộng.
  static const double maxWidth = 380;

  @override
  State<NoticeOverlay> createState() => _NoticeOverlayState();
}

/// Hiện một thông báo ngắn ở [NoticeOverlay] gần nhất.
///
/// [actionLabel] và [onAction] đi thành cặp: một lối lùi cho thao tác vừa xảy
/// ra, ví dụ hoàn tác một lần từ chối. Thẻ mang hành động nên sống lâu hơn,
/// nên [visibleFor] cho phép kéo dài — đọc xong một câu là đủ nhanh, nhưng
/// quyết định có hoàn tác hay không thì không.
///
/// Không làm gì khi không tìm thấy host — một widget dựng lẻ trong test tiện
/// ích không nên chết chỉ vì nó báo cáo một kết quả.
void showNotice(
  BuildContext context,
  FeedbackMessage message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration? visibleFor,
}) {
  context.findRootAncestorStateOfType<_NoticeOverlayState>()?.push(
    _Notice(
      message,
      actionLabel: actionLabel,
      onAction: onAction,
      visibleFor:
          visibleFor ??
          (actionLabel != null && onAction != null
              ? NoticeOverlay.visibleWithActionFor
              : NoticeOverlay.visibleFor),
    ),
  );
}

class _NoticeOverlayState extends State<NoticeOverlay> {
  final List<_Notice> _notices = <_Notice>[];

  void push(_Notice notice) {
    final compact = WindowSizeClass.of(MediaQuery.sizeOf(context).width)
        .usesBottomNavigation;
    final limit = compact
        ? NoticeOverlay.maxVisibleCompact
        : NoticeOverlay.maxVisible;
    setState(() {
      // Cùng một câu đang hiện thì thay nó chứ không xếp thêm một bản sao: năm
      // lần "Pair confirmed." liên tiếp là một thông tin, không phải năm.
      for (final same in _notices.where(
        (shown) => shown.message.text == notice.message.text,
      )) {
        same.timer.cancel();
      }
      _notices
        ..removeWhere((shown) => shown.message.text == notice.message.text)
        ..add(notice);
      while (_notices.length > limit) {
        _notices.removeAt(0).timer.cancel();
      }
    });
    notice.timer = Timer(notice.visibleFor, () => _dismiss(notice));
  }

  void _dismiss(_Notice notice) {
    notice.timer.cancel();
    if (!mounted) return;
    setState(() => _notices.remove(notice));
  }

  @override
  void dispose() {
    for (final notice in _notices) {
      notice.timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_notices.isEmpty) return widget.child;

    final sizeClass = WindowSizeClass.of(MediaQuery.sizeOf(context).width);
    final topInset = MediaQuery.paddingOf(context).top;

    return Stack(
      children: <Widget>[
        widget.child,
        Positioned(
          top: topInset + Gap.screen,
          right: Gap.screen,
          // Bản hẹp không đủ chỗ cho một cột hẹp nằm nép bên phải, nên thẻ trải
          // hết bề ngang trừ đệm hai bên.
          left: sizeClass.usesBottomNavigation ? Gap.screen : null,
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: NoticeOverlay.maxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final notice in _notices) ...<Widget>[
                    _NoticeCard(
                      notice: notice,
                      onDismiss: () => _dismiss(notice),
                    ),
                    const SizedBox(height: Gap.sm),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Một thông báo đang hiển thị, cùng bộ đếm giờ đã hẹn cho nó.
class _Notice {
  _Notice(
    this.message, {
    required this.visibleFor,
    this.actionLabel,
    this.onAction,
  });

  final FeedbackMessage message;
  final Duration visibleFor;
  final String? actionLabel;
  final VoidCallback? onAction;

  late Timer timer;

  bool get hasAction => actionLabel != null && onAction != null;
}

/// Thẻ thông báo: cùng bảng màu và cùng icon với banner trong trang, khác ở chỗ
/// nó nổi lên và tự biến mất.
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice, required this.onDismiss});

  final _Notice notice;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final style = severityStyleOf(notice.message.severity, colors);

    return InkWell(
      // Bấm để đóng sớm: một chuỗi thao tác nhanh không phải chờ hết bốn giây
      // mới nhìn lại được góc màn hình.
      onTap: onDismiss,
      borderRadius: Corner.radiusMd,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.md,
        ),
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: Corner.radiusMd,
          border: Border.all(color: style.foreground.withValues(alpha: 0.4)),
          boxShadow: Elevations.level2(colors.shadowBlue),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(style.icon, size: 16, color: style.foreground),
            const SizedBox(width: Gap.sm),
            Flexible(
              child: Text(
                notice.message.text,
                style: LedgerText.bodySm.copyWith(color: colors.ink),
              ),
            ),
            if (notice.hasAction) ...<Widget>[
              const SizedBox(width: Gap.sm),
              TextButton(
                onPressed: () {
                  // Đóng trước khi chạy: hành động thường đổi trạng thái sinh
                  // ra chính thông báo này, và để nó nằm lại là mời bấm lần hai.
                  onDismiss();
                  notice.onAction!();
                },
                style: TextButton.styleFrom(
                  foregroundColor: style.foreground,
                  textStyle: LedgerText.buttonSm,
                  padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(notice.actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
