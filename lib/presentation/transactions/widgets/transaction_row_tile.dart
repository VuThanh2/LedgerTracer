import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../shared/widgets/money_text.dart';
import '../../shared/widgets/verdict_pill.dart';
import '../view_models/transaction_row_view_model.dart';

/// Bề rộng các cột của bảng giao dịch, khai báo một lần cho cả header lẫn dòng.
///
/// Header và dòng là hai widget khác nhau nhưng phải thẳng cột tuyệt đối — một
/// pixel lệch là mất khả năng quét dọc, thứ mà toàn bộ màn hình này phục vụ. Để
/// mỗi bên tự viết số của mình là để chúng trôi khỏi nhau ở lần sửa thứ hai.
abstract final class TransactionColumns {
  /// Đủ cho `dd/MM/yyyy` ở `caption` **trên một dòng**, sau khi trừ 24dp đệm
  /// ngang và 3dp chỉ báo dòng đang chọn — còn 85dp cho một chuỗi cần ~71dp.
  ///
  /// Con số cũ là 84dp, tức 57dp cho chuỗi ấy: ngày gãy làm hai dòng và mỗi
  /// dòng bảng cao thêm một nửa, 36dp thành 53dp. Bảng vẫn dựng được và không
  /// test nào đỏ — thứ mất đi là đúng cái mật độ mà nó tồn tại để có.
  static const double date = 112;
  static const double account = 176;

  /// Memo được ưu tiên chỗ hơn đối tác.
  ///
  /// Hai cột này từng chia 12/10 theo phía đối tác. Nhưng sao kê Việt Nam gần
  /// như không có cột tên đối tác riêng — nội dung nằm hết ở memo — nên tỉ lệ cũ
  /// để lại một khoảng trống rộng giữa bảng trong khi memo bị cắt bằng dấu ba
  /// chấm ngay cạnh nó.
  static const int counterpartyFlex = 8;
  static const int memoFlex = 14;
  static const double status = 152;
  static const double amount = 160;

  /// Bề ngang hẹp nhất mà bảng còn dựng được: bốn cột cố định, một sàn cho hai
  /// cột chữ co giãn, và lề + viền của panel bao quanh.
  ///
  /// Hẹp hơn mức này bốn cột cố định đã ăn hết chỗ và dòng bảng tràn phải. Đo
  /// theo bề ngang **thực** của vùng chứa chứ không theo cỡ cửa sổ, vì nav rail
  /// và các panel bên cạnh đều lấy bớt chỗ của bảng.
  ///
  /// Sàn 170px cho cột chữ chọn để cửa sổ 1024px (breakpoint Expanded, nav rail
  /// 216px, còn 174px cho cột chữ) vẫn ra bảng — đó là điểm thiết kế hẹp nhất
  /// mà bảng đã chạy đúng từ trước.
  static const double minTableWidth =
      date + account + status + amount + 170 + 2 * Gap.screen + 2;

  /// Kẻ đậm mỗi 5 dòng để mắt bám hàng khi cuộn qua hàng nghìn dòng.
  static bool isRulerRow(int index) => index % 5 == 4;

  /// Một đường kẻ dọc duy nhất, ngay trước cột Trạng thái.
  ///
  /// Bảng này cố ý **không** kẻ lưới: DESIGN.md dựng nó trên khoảng trắng và
  /// canh cột, không trên đường viền. Nhưng một đường ở đúng chỗ thì khác một
  /// cái lưới: nó cắt bảng thành hai vùng có nghĩa khác nhau — bên trái là chữ
  /// đọc theo dòng, bên phải là phán quyết và con số quét theo cột — và cho mắt
  /// một mốc dọc để bám khi lướt qua hàng nghìn dòng. Dùng `hairline` chứ không
  /// phải `hairline-structure`: lặp trên mọi dòng thì sắc độ đậm sẽ thành một
  /// cái lưới thật.
  static Border ruleBefore(Color color) =>
      Border(left: BorderSide(color: color));
}

/// Header dính đỉnh của bảng giao dịch.
class TransactionTableHeader extends StatelessWidget {
  const TransactionTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    Widget cell(String label, {TextAlign align = TextAlign.left}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
      child: Text(
        label.toUpperCase(),
        textAlign: align,
        style: LedgerText.microCap.copyWith(color: colors.inkSecondary),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: colors.canvasSoft,
        border: Border(bottom: BorderSide(color: colors.hairlineStructure)),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(width: TransactionColumns.date, child: cell('Date')),
          SizedBox(width: TransactionColumns.account, child: cell('Account')),
          Expanded(
            flex: TransactionColumns.counterpartyFlex,
            child: cell('Counterparty'),
          ),
          Expanded(flex: TransactionColumns.memoFlex, child: cell('Memo')),
          Container(
            width: TransactionColumns.status,
            decoration: BoxDecoration(
              border: TransactionColumns.ruleBefore(colors.hairline),
            ),
            child: cell('Status'),
          ),
          SizedBox(
            width: TransactionColumns.amount,
            child: cell('Amount', align: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

/// Một dòng bảng ở density compact (web).
///
/// Dòng đang chọn đổi nền sang `primary-wash` **và** thêm một chỉ báo dọc 3px ở
/// mép trái: chỉ đổi nền thì ở nền gần trắng này khác biệt quá mảnh để bắt mắt
/// khi đang cuộn nhanh.
class TransactionRowTile extends StatelessWidget {
  const TransactionRowTile({
    required this.row,
    required this.index,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final TransactionRowViewModel row;

  /// Vị trí trong danh sách, chỉ dùng để quyết định kẻ đậm mỗi 5 dòng.
  final int index;

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    Widget text(String value, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: LedgerText.bodySm.copyWith(color: color ?? colors.ink),
      ),
    );

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        decoration: BoxDecoration(
          color: selected ? colors.primaryWash : colors.canvasSoft,
          border: Border(
            left: BorderSide(
              color: selected ? colors.primary : Colors.transparent,
              width: 3,
            ),
            bottom: BorderSide(
              color: TransactionColumns.isRulerRow(index)
                  ? colors.hairlineStructure
                  : colors.hairline,
            ),
          ),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: TransactionColumns.date - 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.md,
                  vertical: Gap.sm,
                ),
                // Không bao giờ xuống dòng, kể cả khi bề rộng hụt vì một cỡ
                // chữ hệ thống lớn hơn: cắt bằng dấu ba chấm còn giữ được chiều
                // cao dòng, gãy dòng thì không.
                child: Text(
                  row.dateText,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: LedgerText.caption.copyWith(
                    color: colors.inkSecondary,
                  ),
                ),
              ),
            ),
            // Hai bậc chữ, không ba: `ink-mute` chỉ đạt tương phản 4.5:1 trên
            // `canvas`, mà dòng bảng nằm trên `canvas-soft`. Bậc đậm dành cho
            // thứ người dùng quét tìm — đối tác và số tiền; ngày, tài khoản và
            // memo là ngữ cảnh. Tài khoản đặc biệt đáng hạ bậc: nó lặp lại y
            // nguyên trên hàng nghìn dòng, nên in đậm bằng đối tác chỉ làm nhiễu
            // đúng cột mà mắt đang tìm.
            SizedBox(
              width: TransactionColumns.account,
              child: text(row.accountName, color: colors.inkSecondary),
            ),
            Expanded(
              flex: TransactionColumns.counterpartyFlex,
              child: text(row.counterpartyText),
            ),
            Expanded(
              flex: TransactionColumns.memoFlex,
              child: text(row.descriptionText, color: colors.inkSecondary),
            ),
            Container(
              width: TransactionColumns.status,
              decoration: BoxDecoration(
                border: TransactionColumns.ruleBefore(colors.hairline),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.md,
                vertical: Gap.xs,
              ),
              child: _StatusCell(row: row),
            ),
            SizedBox(
              width: TransactionColumns.amount,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.md,
                  vertical: Gap.sm,
                ),
                child: MoneyText(row.amountText, isIncoming: row.isIncoming),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cùng một giao dịch ở density touch: bảng thu lại thành card hai dòng, số tiền
/// vẫn căn phải và vẫn `body-tabular`.
class TransactionCardTile extends StatelessWidget {
  const TransactionCardTile({
    required this.row,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final TransactionRowViewModel row;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return InkWell(
      onTap: onTap,
      borderRadius: Corner.radiusMd,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: colors.canvas,
          borderRadius: Corner.radiusMd,
          border: Border.all(
            color: selected ? colors.primary : colors.hairline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Expanded(
                  child: Text(
                    row.counterpartyText.isEmpty
                        ? row.descriptionText
                        : row.counterpartyText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LedgerText.bodyMd.copyWith(color: colors.ink),
                  ),
                ),
                const SizedBox(width: Gap.md),
                MoneyText(row.amountText, isIncoming: row.isIncoming),
              ],
            ),
            const SizedBox(height: Gap.xs),
            Text(
              '${row.dateText} · ${row.accountName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LedgerText.caption.copyWith(color: colors.inkMute),
            ),
            if (row.isReconciled || row.isManuallyEdited) ...<Widget>[
              const SizedBox(height: Gap.sm),
              _StatusCell(row: row),
            ],
          ],
        ),
      ),
    );
  }
}

/// Cột trạng thái: badge "nội bộ" viền, pill "đã đối soát" nền, và dấu hiệu đã
/// sửa tay. Ba nhãn cùng chỗ nên chúng phải khác nhau ở hình dạng.
class _StatusCell extends StatelessWidget {
  const _StatusCell({required this.row});

  final TransactionRowViewModel row;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Wrap(
      spacing: Gap.xs,
      runSpacing: Gap.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        if (row.isReconciled) ...<Widget>[
          const InternalBadge(),
          const VerdictPill(tone: VerdictTone.confirmed, label: 'Matched'),
        ],
        if (row.isManuallyEdited)
          Tooltip(
            message: 'Edited by hand after the import',
            child: Icon(Icons.edit_outlined, size: 13, color: colors.inkMute),
          ),
      ],
    );
  }
}
