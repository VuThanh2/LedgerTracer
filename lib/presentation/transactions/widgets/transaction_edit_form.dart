import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../shared/failures/feedback_message.dart';
import '../../shared/formatting/date_formatter.dart';
import '../../shared/widgets/banner_message.dart';
import '../../shared/widgets/section_card.dart';
import '../bloc/transaction_edit_state.dart';
import '../view_models/transaction_edit_draft.dart';

/// Form sửa một giao dịch (UC-05).
///
/// Cảnh báo về cặp đối soát nằm **trên** các ô nhập chứ không cạnh nút Lưu: nó
/// là điều kiện để quyết định có sửa hay không, nên nó phải được đọc trước khi
/// người dùng bỏ công gõ.
///
/// Loại tiền hiển thị nhưng **không sửa được** ở màn này, dù
/// `TransactionEditBloc` có sẵn sự kiện đổi loại tiền. Bản thiết kế cho form sửa
/// đúng ba trường — đối tác, số tiền, nội dung — và loại tiền không nằm trong
/// đó. Nó cũng là trường nguy hiểm nhất để mở: đổi loại tiền của một dòng đã
/// nhập làm mọi con số tổng ở màn Thống kê nhảy sang một bảng khác, mà không có
/// gì trên màn này nói ra điều đó. Khi nào thật sự cần, sự kiện đã có sẵn để
/// dùng.
class TransactionEditForm extends StatefulWidget {
  const TransactionEditForm({
    required this.state,
    required this.onDateChanged,
    required this.onAmountChanged,
    required this.onDirectionChanged,
    required this.onCounterpartyChanged,
    required this.onDescriptionChanged,
    super.key,
  });

  final TransactionEditState state;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<String> onAmountChanged;
  final ValueChanged<MoneyDirection> onDirectionChanged;
  final ValueChanged<String> onCounterpartyChanged;
  final ValueChanged<String> onDescriptionChanged;

  @override
  State<TransactionEditForm> createState() => _TransactionEditFormState();
}

class _TransactionEditFormState extends State<TransactionEditForm> {
  late final TextEditingController _date;
  late final TextEditingController _amount;
  late final TextEditingController _counterparty;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    final draft = widget.state.draft;
    _date = TextEditingController(
      text: draft == null ? '' : DateFormatter.day(draft.bookingDate),
    );
    _amount = TextEditingController(text: draft?.amountText ?? '');
    _counterparty = TextEditingController(text: draft?.counterpartyName ?? '');
    _description = TextEditingController(text: draft?.description ?? '');
  }

  @override
  void didUpdateWidget(TransactionEditForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final draft = widget.state.draft;
    if (draft == null || oldWidget.state.draft != null) return;
    // Bản nháp vừa nạp xong: điền các ô đúng một lần. Sau đó ô là nguồn của
    // chuỗi đang gõ, và ghi đè nó ở mỗi state mới sẽ nhảy con trỏ về cuối.
    _date.text = DateFormatter.day(draft.bookingDate);
    _amount.text = draft.amountText;
    _counterparty.text = draft.counterpartyName;
    _description.text = draft.description;
  }

  @override
  void dispose() {
    _date.dispose();
    _amount.dispose();
    _counterparty.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final state = widget.state;
    final draft = state.draft;
    if (draft == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.all(Gap.screen),
      children: <Widget>[
        if (state.isInReconciledPair) ...<Widget>[
          const BannerMessage(
            FeedbackMessage.warning(
              'This row belongs to a reconciliation pair. Saving drops the '
              'pair, and because that is not recorded as a rejection, the next '
              'scan can suggest a similar pair again.',
            ),
          ),
          const SizedBox(height: Gap.lg),
        ],
        if (state.error case final FeedbackMessage error) ...<Widget>[
          BannerMessage(error),
          const SizedBox(height: Gap.lg),
        ],

        SectionCard(
          title: 'Transaction',
          subtitle: 'Account: ${state.accountName}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SectionLabel('Booking date'),
              TextField(
                controller: _date,
                keyboardType: TextInputType.datetime,
                style: LedgerText.bodyMd.copyWith(color: colors.ink),
                decoration: const InputDecoration(helperText: 'dd/mm/yyyy'),
                onChanged: (value) {
                  final parsed = DateFormatter.tryParseDay(value);
                  if (parsed != null) widget.onDateChanged(parsed);
                },
              ),
              const SizedBox(height: Gap.lg),

              const SectionLabel('Direction'),
              _DirectionToggle(
                direction: draft.direction,
                onChanged: widget.onDirectionChanged,
              ),
              const SizedBox(height: Gap.lg),

              SectionLabel('Amount (${draft.currency.code})'),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: LedgerText.bodyTabular.copyWith(color: colors.ink),
                decoration: InputDecoration(
                  errorText: state.validation?.amountError,
                ),
                onChanged: widget.onAmountChanged,
              ),
              const SizedBox(height: Gap.lg),

              const SectionLabel('Counterparty'),
              TextField(
                controller: _counterparty,
                style: LedgerText.bodyMd.copyWith(color: colors.ink),
                onChanged: widget.onCounterpartyChanged,
              ),
              const SizedBox(height: Gap.lg),

              const SectionLabel('Memo'),
              TextField(
                controller: _description,
                maxLines: 3,
                minLines: 1,
                style: LedgerText.bodyMd.copyWith(color: colors.ink),
                onChanged: widget.onDescriptionChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Chọn hướng tiền. Hai ô có màu ngữ nghĩa của chính chúng ở phần chữ, nhưng ô
/// đang chọn **không** tô nền đặc bằng màu đó: verdant và ruby là màu ngữ nghĩa,
/// không phải màu hành động.
class _DirectionToggle extends StatelessWidget {
  const _DirectionToggle({required this.direction, required this.onChanged});

  final MoneyDirection direction;
  final ValueChanged<MoneyDirection> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    Widget option(MoneyDirection value, String label, Color tone) {
      final selected = direction == value;
      return Expanded(
        child: InkWell(
          onTap: () => onChanged(value),
          borderRadius: Corner.radiusSm,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? colors.canvas : Colors.transparent,
              borderRadius: Corner.radiusSm,
              boxShadow: selected ? Elevations.level1(colors.shadowBlue) : null,
            ),
            child: Text(
              label,
              style: LedgerText.bodySm.copyWith(
                color: selected ? tone : colors.inkSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.canvasSoft,
        borderRadius: Corner.radiusMd,
      ),
      child: Row(
        children: <Widget>[
          option(MoneyDirection.incoming, 'Money in (+)', colors.moneyIn),
          option(MoneyDirection.outgoing, 'Money out (−)', colors.moneyOut),
        ],
      ),
    );
  }
}
