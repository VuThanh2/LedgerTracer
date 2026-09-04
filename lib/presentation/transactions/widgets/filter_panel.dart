import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../domain/repositories/transaction_repository.dart';
import '../../shared/failures/feedback_message.dart';
import '../../shared/formatting/date_formatter.dart';
import '../../shared/widgets/banner_message.dart';
import '../../shared/widgets/filter_chip_bar.dart';
import '../../shared/widgets/section_card.dart';
import '../bloc/transactions_state.dart';
import '../view_models/transaction_filter_draft.dart';

/// Bộ lọc của UC-07: khoảng tiền, loại tiền, khoảng ngày, tài khoản — kết hợp
/// theo VÀ.
///
/// Cùng một widget cho hai hình thái: panel cố định bên phải ở Expanded, và nội
/// dung của bottom sheet ở Compact. Chỉ khung chứa khác nhau, còn các ô và luật
/// kiểm tra thì không — hai bản sao là hai chỗ để luật trôi khỏi nhau.
///
/// Ô ngày là ô **chữ** `dd/mm/yyyy` chứ không phải lịch bật lên, đúng như bản
/// thiết kế: người dùng ở đây gõ nhanh hơn chọn, và một hộp lịch phủ kín màn
/// hình che mất chính danh sách mà họ đang thu hẹp.
class FilterPanel extends StatefulWidget {
  const FilterPanel({
    required this.state,
    required this.onDraftChanged,
    required this.onApply,
    required this.onClear,
    this.onClose,
    super.key,
  });

  final TransactionsState state;
  final ValueChanged<TransactionFilterDraft> onDraftChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;

  /// `null` ở bottom sheet, nơi cử chỉ kéo xuống đã đóng được.
  final VoidCallback? onClose;

  static const double panelWidth = 312;

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  late final TextEditingController _minAmount = TextEditingController(
    text: widget.state.draft.minAmountText,
  );
  late final TextEditingController _maxAmount = TextEditingController(
    text: widget.state.draft.maxAmountText,
  );
  late final TextEditingController _from = TextEditingController(
    text: _dayTextOf(widget.state.draft.dateFrom),
  );
  late final TextEditingController _to = TextEditingController(
    text: _dayTextOf(widget.state.draft.dateTo),
  );

  static String _dayTextOf(DateTime? value) =>
      value == null ? '' : DateFormatter.day(value);

  TransactionFilterDraft get _draft => widget.state.draft;

  @override
  void dispose() {
    _minAmount.dispose();
    _maxAmount.dispose();
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  void _emit(TransactionFilterDraft draft) => widget.onDraftChanged(draft);

  void _onDateChanged({required bool isFrom, required String raw}) {
    final trimmed = raw.trim();
    // Chuỗi rỗng là "bỏ mốc này", nên nó phải đi qua cờ `clearDateRange` — truyền
    // `null` vào `copyWith` chỉ có nghĩa "giữ nguyên".
    if (trimmed.isEmpty) {
      _emit(
        TransactionFilterDraft(
          accountId: _draft.accountId,
          dateFrom: isFrom ? null : _draft.dateFrom,
          dateTo: isFrom ? _draft.dateTo : null,
          minAmountText: _draft.minAmountText,
          maxAmountText: _draft.maxAmountText,
          currency: _draft.currency,
          filterByCurrency: _draft.filterByCurrency,
        ),
      );
      return;
    }

    final parsed = DateFormatter.tryParseDay(trimmed);
    if (parsed == null) return;
    _emit(
      isFrom
          ? _draft.copyWith(dateFrom: parsed)
          : _draft.copyWith(dateTo: parsed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final validation = widget.state.validation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.onClose != null)
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.hairline)),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Filters',
                    style: LedgerText.headingSm.copyWith(color: colors.ink),
                  ),
                ),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Close filters',
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(Gap.lg),
            children: <Widget>[
              const SectionLabel('Amount range'),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _AmountField(
                      controller: _minAmount,
                      hint: 'From',
                      error: validation?.minAmountError,
                      onChanged: (value) =>
                          _emit(_draft.copyWith(minAmountText: value)),
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: _AmountField(
                      controller: _maxAmount,
                      hint: 'To',
                      error: validation?.maxAmountError,
                      onChanged: (value) =>
                          _emit(_draft.copyWith(maxAmountText: value)),
                    ),
                  ),
                ],
              ),
              if (validation?.amountRangeError case final String error) ...[
                const SizedBox(height: Gap.sm),
                BannerMessage(FeedbackMessage.warning(error)),
              ],
              const SizedBox(height: Gap.sm),
              const BannerMessage(
                FeedbackMessage.info(
                  'An amount filter always applies together with a currency, so '
                  'figures stay comparable.',
                ),
              ),
              const SizedBox(height: Gap.xl),

              const SectionLabel('Currency'),
              _CurrencyChips(
                currencies: widget.state.currencies,
                draft: _draft,
                onChanged: _emit,
              ),
              if (validation?.currencyError case final String error) ...[
                const SizedBox(height: Gap.sm),
                BannerMessage(FeedbackMessage.warning(error)),
              ],
              const SizedBox(height: Gap.xl),

              const SectionLabel('Date range'),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _DateField(
                      controller: _from,
                      hint: 'From',
                      onChanged: (value) =>
                          _onDateChanged(isFrom: true, raw: value),
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: _DateField(
                      controller: _to,
                      hint: 'To',
                      onChanged: (value) =>
                          _onDateChanged(isFrom: false, raw: value),
                    ),
                  ),
                ],
              ),
              if (validation?.dateRangeError case final String error) ...[
                const SizedBox(height: Gap.sm),
                BannerMessage(FeedbackMessage.warning(error)),
              ],
              const SizedBox(height: Gap.xl),

              const SectionLabel('Accounts'),
              _AccountPicker(
                accountNames: widget.state.accountNames,
                selectedId: _draft.accountId,
                onSelected: (accountId) => _emit(
                  accountId == null
                      ? _draft.copyWith(clearAccount: true)
                      : _draft.copyWith(accountId: accountId),
                ),
              ),
              const SizedBox(height: Gap.xl),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.lg,
            vertical: Gap.md,
          ),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.hairline)),
          ),
          child: Row(
            children: <Widget>[
              OutlinedButton(
                onPressed: widget.onClear,
                child: const Text('Clear all'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: widget.onApply,
                child: const Text('Apply'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.error,
  });

  final TextEditingController controller;
  final String hint;
  final String? error;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    style: LedgerText.bodyMd.copyWith(color: context.ledger.ink),
    decoration: InputDecoration(hintText: hint, errorText: error),
  );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    keyboardType: TextInputType.datetime,
    style: LedgerText.bodyMd.copyWith(color: context.ledger.ink),
    decoration: InputDecoration(hintText: hint, helperText: 'dd/mm/yyyy'),
  );
}

class _CurrencyChips extends StatelessWidget {
  const _CurrencyChips({
    required this.currencies,
    required this.draft,
    required this.onChanged,
  });

  final List<CurrencyUsage> currencies;
  final TransactionFilterDraft draft;
  final ValueChanged<TransactionFilterDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    if (currencies.isEmpty) {
      return Text(
        'No transactions yet, so no currency is in use.',
        style: LedgerText.micro.copyWith(color: context.ledger.inkMute),
      );
    }
    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: <Widget>[
        for (final usage in currencies)
          ToggleChip(
            label: usage.currency.code,
            selected:
                draft.filterByCurrency && draft.currency == usage.currency,
            onTap: () {
              final isSelected =
                  draft.filterByCurrency && draft.currency == usage.currency;
              onChanged(
                isSelected
                    ? draft.copyWith(filterByCurrency: false)
                    : draft.copyWith(
                        currency: usage.currency,
                        filterByCurrency: true,
                      ),
              );
            },
          ),
      ],
    );
  }
}

/// Chọn **một** tài khoản.
///
/// Bản thiết kế vẽ dãy ô tích, nhưng `TransactionFilter` của tầng dưới chỉ mang
/// một `accountId`. Vẽ ô tích cho một tiêu chí đơn trị là hứa với người dùng một
/// khả năng không có: họ sẽ tích hai ô rồi thấy một ô tự bỏ. Ở đây dùng dạng
/// chọn một, và bổ sung một dòng "Tất cả tài khoản" để bỏ chọn — hình thức khác,
/// nhưng đúng thứ hệ thống làm được.
class _AccountPicker extends StatelessWidget {
  const _AccountPicker({
    required this.accountNames,
    required this.selectedId,
    required this.onSelected,
  });

  final Map<int, String> accountNames;
  final int? selectedId;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    if (accountNames.isEmpty) {
      return Text(
        'No accounts declared yet.',
        style: LedgerText.micro.copyWith(color: colors.inkMute),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _AccountRow(
          label: 'All accounts',
          selected: selectedId == null,
          onTap: () => onSelected(null),
        ),
        for (final MapEntry<int, String>(key: id, value: name)
            in accountNames.entries)
          _AccountRow(
            label: name,
            selected: selectedId == id,
            onTap: () => onSelected(id),
          ),
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return InkWell(
      onTap: onTap,
      borderRadius: Corner.radiusSm,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
        child: Row(
          children: <Widget>[
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 16,
              color: selected ? colors.primary : colors.hairlineControl,
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LedgerText.bodySm.copyWith(color: colors.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
