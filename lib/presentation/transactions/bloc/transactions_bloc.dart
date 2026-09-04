import 'package:bloc/bloc.dart';

import '../../../application/accounts/manage_accounts/manage_accounts_use_case.dart';
import '../../../application/transactions/delete_transaction/delete_transaction_use_case.dart';
import '../../../application/transactions/query_transactions/query_transactions_dto.dart';
import '../../../application/transactions/query_transactions/query_transactions_use_case.dart';
import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/repositories/transaction_repository.dart';
import '../../../domain/value_objects/search_text.dart';
import '../../shared/bloc/event_transformers.dart';
import '../../shared/bloc/load_status.dart';
import '../../shared/bloc/transient_notice.dart';
import '../../shared/failures/failure_presenter.dart';
import '../view_models/filter_chip_view_model.dart';
import '../view_models/transaction_filter_draft.dart';
import '../view_models/transaction_row_view_model.dart';
import 'transactions_event.dart';
import 'transactions_state.dart';

/// Màn hình chính của ứng dụng: duyệt, tìm kiếm, lọc, xem chi tiết và xoá giao
/// dịch (UC-04, UC-05, UC-06, UC-07).
///
/// Ba use case được ghép ở đây chứ không ở ba màn hình rời, vì chúng chia nhau
/// **một** danh sách: tìm kiếm và lọc chỉ là hai cách thu hẹp cùng tập dữ liệu,
/// và chi tiết là một dòng của chính tập đó. Tách ra thành ba BLoC nghĩa là ba
/// bản sao của cùng bộ tiêu chí, và ba lần chúng đi lệch nhau.
///
/// Nạp theo trang và **cộng dồn** thay vì thay thế: danh sách này chạy trên tập
/// hàng trăm nghìn dòng, nên nó không bao giờ được nạp trọn (UC-04).
final class TransactionsBloc
    extends Bloc<TransactionsEvent, TransactionsState> {
  TransactionsBloc({
    required QueryTransactionsUseCase queryTransactions,
    required DeleteTransactionUseCase deleteTransaction,
    required ManageAccountsUseCase manageAccounts,
    this.pageSize = defaultPageSize,
  }) : _query = queryTransactions,
       _delete = deleteTransaction,
       _accounts = manageAccounts,
       super(const TransactionsState()) {
    // Mỗi nhóm sự kiện có một cách xử lý dòng riêng, và cả ba đều là quyết định
    // chứ không phải mặc định: mặc định của `bloc` là chạy song song, thứ sẽ
    // trộn hai trang vào nhau ở phân trang và để hai lệnh xoá chồng lên nhau.
    on<TransactionsStarted>(
      _onStarted,
      transformer: EventTransformers.restartable(),
    );
    on<TransactionsRefreshed>(
      _onRefreshed,
      transformer: EventTransformers.restartable(),
    );
    on<TransactionsInvalidated>(
      _onInvalidated,
      transformer: EventTransformers.restartable(),
    );
    on<TransactionsKeywordChanged>(
      _onKeywordChanged,
      transformer: EventTransformers.searchInput(),
    );
    on<TransactionsFilterDraftChanged>(_onDraftChanged);
    on<TransactionsFilterApplied>(
      _onFilterApplied,
      transformer: EventTransformers.restartable(),
    );
    on<TransactionsFilterCleared>(
      _onFilterCleared,
      transformer: EventTransformers.restartable(),
    );
    on<TransactionsChipRemoved>(
      _onChipRemoved,
      transformer: EventTransformers.restartable(),
    );
    on<TransactionsNextPageRequested>(
      _onNextPage,
      // Bỏ qua chứ không xếp hàng: cuộn nhanh phát ra rất nhiều sự kiện, và xếp
      // hàng chúng lại nghĩa là nạp thêm mười trang mà người dùng đã lướt qua.
      transformer: EventTransformers.droppable(),
    );
    on<TransactionSelected>(
      _onSelected,
      transformer: EventTransformers.restartable(),
    );
    on<TransactionDetailRequested>(
      _onDetailRequested,
      transformer: EventTransformers.restartable(),
    );
    on<TransactionDeleteRequested>(
      _onDeleteRequested,
      transformer: EventTransformers.sequential(),
    );
    on<TransactionDeleteDismissed>(_onDeleteDismissed);
    on<TransactionDeleteConfirmed>(
      _onDeleteConfirmed,
      transformer: EventTransformers.sequential(),
    );
  }

  final QueryTransactionsUseCase _query;
  final DeleteTransactionUseCase _delete;
  final ManageAccountsUseCase _accounts;

  /// Số dòng đọc lên mỗi lần.
  ///
  /// Là tham số chứ không phải hằng số vì nó phụ thuộc vào bố cục: một cửa sổ
  /// rộng hiển thị được nhiều dòng hơn hẳn một điện thoại, và một trang không
  /// phủ nổi màn hình nghĩa là cuộn tới đâu chờ tới đó
  /// (`WindowSizeClass.pageSize`).
  final int pageSize;

  final NoticeSink _notices = NoticeSink();

  /// Đủ dày để một màn hình rộng không phải nạp thêm ngay khi mở.
  static const int defaultPageSize = 80;

  Future<void> _onStarted(
    TransactionsStarted event,
    Emitter<TransactionsState> emit,
  ) async {
    final accountNames = await _loadAccountNames();
    final currencies = await _loadCurrencies();

    // Loại tiền mặc định của bộ lọc số tiền là loại tiền phổ biến nhất, để người
    // dùng không phải chọn thứ họ đã có sẵn 99% dữ liệu ở đó (UC-07).
    final draft = event.draft.currency == null && currencies.isNotEmpty
        ? event.draft.copyWith(currency: currencies.first.currency)
        : event.draft;
    final validation = draft.validate(keyword: _keywordOf(state.keyword));

    emit(
      state.copyWith(
        status: LoadStatus.loading,
        accountNames: accountNames,
        currencies: currencies,
        draft: draft,
        context: event.context,
        filter: validation.filter ?? TransactionFilter.none,
        clearValidation: true,
      ),
    );
    await _reload(emit);
  }

  Future<void> _onRefreshed(
    TransactionsRefreshed event,
    Emitter<TransactionsState> emit,
  ) => _reload(emit);

  /// Sau một lần sửa ở biểu mẫu riêng: đọc lại danh sách, và đọc lại cả chi tiết
  /// đang mở nếu đúng là dòng vừa đổi.
  Future<void> _onInvalidated(
    TransactionsInvalidated event,
    Emitter<TransactionsState> emit,
  ) async {
    await _reload(emit);
    final changed = event.changedTransactionId;
    if (changed != null && changed == state.selectedId) {
      await _loadDetail(changed, emit);
    }
  }

  Future<void> _onKeywordChanged(
    TransactionsKeywordChanged event,
    Emitter<TransactionsState> emit,
  ) async {
    final keyword = event.keyword;
    final validation = state.draft.validate(keyword: _keywordOf(keyword));
    // Từ khoá không bao giờ làm bản nháp hỏng, nên bản nháp sai chỉ giữ nguyên
    // bộ lọc cũ và để lỗi của nó nằm yên ở Filter Panel.
    emit(
      state.copyWith(
        status: LoadStatus.loading,
        keyword: keyword,
        filter: validation.filter ?? state.filter,
      ),
    );
    await _reload(emit);
  }

  void _onDraftChanged(
    TransactionsFilterDraftChanged event,
    Emitter<TransactionsState> emit,
  ) => emit(state.copyWith(draft: event.draft, clearValidation: true));

  Future<void> _onFilterApplied(
    TransactionsFilterApplied event,
    Emitter<TransactionsState> emit,
  ) async {
    final validation = state.draft.validate(keyword: _keywordOf(state.keyword));
    if (!validation.isValid) {
      // Bản nháp sai thì danh sách **giữ nguyên** thứ đang hiển thị: xoá sạch
      // kết quả vì một ô gõ sai là phạt người dùng cho một lỗi họ sửa được ngay.
      emit(state.copyWith(validation: validation));
      return;
    }
    emit(
      state.copyWith(
        status: LoadStatus.loading,
        filter: validation.filter,
        clearValidation: true,
      ),
    );
    await _reload(emit);
  }

  Future<void> _onFilterCleared(
    TransactionsFilterCleared event,
    Emitter<TransactionsState> emit,
  ) async {
    // Loại tiền mặc định được đặt lại chứ không bỏ trống: nó là tiền đề của bộ
    // lọc số tiền, không phải một tiêu chí người dùng vừa gỡ (UC-07).
    final draft = state.currencies.isEmpty
        ? TransactionFilterDraft.empty
        : TransactionFilterDraft(currency: state.currencies.first.currency);
    emit(
      state.copyWith(
        status: LoadStatus.loading,
        draft: draft,
        filter: TransactionFilter(keyword: _keywordOf(state.keyword)),
        clearValidation: true,
      ),
    );
    await _reload(emit);
  }

  Future<void> _onChipRemoved(
    TransactionsChipRemoved event,
    Emitter<TransactionsState> emit,
  ) async {
    var keyword = state.keyword;
    var draft = state.draft;
    var context = state.context;

    switch (event.kind) {
      case FilterChipKind.keyword:
        keyword = '';
      case FilterChipKind.account:
        draft = draft.copyWith(clearAccount: true);
      case FilterChipKind.dateRange:
        draft = draft.copyWith(clearDateRange: true);
      // Gỡ khoảng số tiền cũng gỡ luôn tiêu chí loại tiền đi kèm nó: một khoảng
      // số tiền không có loại tiền là so sánh hai con số khác đơn vị, nên hai
      // thứ này không tách rời được (UC-07). Giá trị trong ô loại tiền thì vẫn
      // giữ — nó là tiền đề cho lần gõ số tiền kế tiếp, không phải một tiêu chí.
      case FilterChipKind.amountRange:
        draft = draft.copyWith(clearAmount: true, filterByCurrency: false);
      case FilterChipKind.currency:
        draft = draft.copyWith(filterByCurrency: false);
      case FilterChipKind.importFile:
        context = context.withoutImport();
      case FilterChipKind.internalTransfers:
        context = context.withoutInternalExclusion();
    }

    final validation = draft.validate(keyword: _keywordOf(keyword));
    emit(
      state.copyWith(
        status: LoadStatus.loading,
        keyword: keyword,
        draft: draft,
        context: context,
        filter: validation.filter ?? state.filter,
        clearValidation: true,
      ),
    );
    await _reload(emit);
  }

  Future<void> _onNextPage(
    TransactionsNextPageRequested event,
    Emitter<TransactionsState> emit,
  ) async {
    if (!state.hasMore || state.isLoadingMore || state.status.isLoading) return;
    emit(state.copyWith(isLoadingMore: true, clearLoadError: true));

    final collected = await _collect(
      filter: state.context.narrow(state.filter),
      fromOffset: state.loadedCount,
    );

    switch (collected) {
      case Err<_CollectedPage>(:final failure):
        emit(
          state.copyWith(
            isLoadingMore: false,
            loadError: FailurePresenter.of(failure, context: 'transaction'),
          ),
        );
      case Ok<_CollectedPage>(:final value):
        emit(
          state.copyWith(
            rows: <TransactionRowViewModel>[...state.rows, ...value.rows],
            loadedCount: value.loadedCount,
            totalCount: value.totalCount,
            hasMore: value.hasMore,
            isLoadingMore: false,
          ),
        );
    }
  }

  Future<void> _onSelected(
    TransactionSelected event,
    Emitter<TransactionsState> emit,
  ) async {
    final id = event.transactionId;
    if (id == null) {
      emit(
        state.copyWith(
          clearSelection: true,
          clearDetail: true,
          detailStatus: LoadStatus.initial,
        ),
      );
      return;
    }
    emit(state.copyWith(selectedId: id));
    await _loadDetail(id, emit);
  }

  Future<void> _onDetailRequested(
    TransactionDetailRequested event,
    Emitter<TransactionsState> emit,
  ) async {
    emit(state.copyWith(selectedId: event.transactionId));
    await _loadDetail(event.transactionId, emit);
  }

  /// Hỏi trước khi hỏi người dùng: hộp thoại xác nhận phải biết cặp đối soát nào
  /// sẽ bị huỷ trước khi nó hiện lên (UC-05).
  Future<void> _onDeleteRequested(
    TransactionDeleteRequested event,
    Emitter<TransactionsState> emit,
  ) async {
    final result = await _delete.isInPair(event.transactionId);
    switch (result) {
      case Err<bool>(:final failure):
        emit(state.copyWith(notice: _noticeOf(failure, 'transaction')));
      case Ok<bool>(:final value):
        emit(
          state.copyWith(
            pendingDelete: DeleteConfirmation(
              transactionId: event.transactionId,
              cancelsReconciliation: value,
            ),
          ),
        );
    }
  }

  void _onDeleteDismissed(
    TransactionDeleteDismissed event,
    Emitter<TransactionsState> emit,
  ) => emit(state.copyWith(clearPendingDelete: true));

  Future<void> _onDeleteConfirmed(
    TransactionDeleteConfirmed event,
    Emitter<TransactionsState> emit,
  ) async {
    final pending = state.pendingDelete;
    if (pending == null || pending.isDeleting) return;
    emit(state.copyWith(pendingDelete: pending.deleting()));

    final result = await _delete.execute(pending.transactionId);
    switch (result) {
      case Err<bool>(:final failure):
        emit(
          state.copyWith(
            clearPendingDelete: true,
            notice: _noticeOf(failure, 'transaction'),
          ),
        );
      case Ok<bool>(value: final cancelledPair):
        final wasSelected = state.selectedId == pending.transactionId;
        emit(
          state.copyWith(
            clearPendingDelete: true,
            clearSelection: wasSelected,
            clearDetail: wasSelected,
            status: LoadStatus.loading,
            notice: _notices.success(
              cancelledPair
                  ? 'Transaction deleted. The reconciliation pair it belonged '
                        'to was dropped.'
                  : 'Transaction deleted.',
            ),
          ),
        );
        await _reload(emit);
    }
  }

  /// Đọc lại từ trang đầu với tiêu chí hiện tại.
  Future<void> _reload(Emitter<TransactionsState> emit) async {
    emit(
      state.copyWith(
        status: LoadStatus.loading,
        chips: _chipsOf(state),
        clearLoadError: true,
      ),
    );

    final collected = await _collect(
      filter: state.context.narrow(state.filter),
      fromOffset: 0,
    );

    switch (collected) {
      case Err<_CollectedPage>(:final failure):
        emit(
          state.copyWith(
            status: LoadStatus.failed,
            loadError: FailurePresenter.of(failure, context: 'transaction'),
          ),
        );
      case Ok<_CollectedPage>(:final value):
        emit(
          state.copyWith(
            status: LoadStatus.ready,
            rows: value.rows,
            loadedCount: value.loadedCount,
            totalCount: value.totalCount,
            hasMore: value.hasMore,
            isLoadingMore: false,
          ),
        );
    }
  }

  /// Đọc đúng **một** trang từ [fromOffset].
  ///
  /// Không còn lớp lọc nào chạy sau khi đọc lên: ngữ cảnh đã được `narrow` gộp
  /// vào chính bộ tiêu chí gửi xuống, nên mọi dòng trả về đều là dòng sẽ hiển
  /// thị, và `totalCount` là con số đúng chứ không phải cận trên.
  Future<Result<_CollectedPage>> _collect({
    required TransactionFilter filter,
    required int fromOffset,
  }) async {
    final result = await _query.execute(
      QueryTransactionsRequest(
        filter: filter,
        limit: pageSize,
        offset: fromOffset,
      ),
    );
    switch (result) {
      case Err<TransactionsPage>(:final failure):
        return Err<_CollectedPage>(failure);
      case Ok<TransactionsPage>(value: final page):
        final loaded = fromOffset + page.items.length;
        return Ok<_CollectedPage>(
          _CollectedPage(
            rows: <TransactionRowViewModel>[
              for (final item in page.items) TransactionRowViewModel.of(item),
            ],
            loadedCount: loaded,
            totalCount: page.totalCount,
            // Trang ngắn hơn giới hạn là dấu hiệu chắc chắn đã hết; phép so với
            // tổng là lưới thứ hai cho trường hợp dữ liệu đổi giữa hai trang.
            hasMore: page.items.length == pageSize && loaded < page.totalCount,
          ),
        );
    }
  }

  Future<void> _loadDetail(int id, Emitter<TransactionsState> emit) async {
    emit(state.copyWith(detailStatus: LoadStatus.loading));

    final result = await _query.findById(id);
    switch (result) {
      case Err<Transaction?>(:final failure):
        emit(
          state.copyWith(
            detailStatus: LoadStatus.failed,
            notice: _noticeOf(failure, 'transaction'),
          ),
        );
      case Ok<Transaction?>(value: final tx):
        if (tx == null) {
          emit(
            state.copyWith(
              detailStatus: LoadStatus.failed,
              clearDetail: true,
              notice: _notices.warning(
                'That transaction no longer exists. The list has been '
                'reloaded.',
              ),
            ),
          );
          await _reload(emit);
          return;
        }
        emit(
          state.copyWith(
            detailStatus: LoadStatus.ready,
            detail: TransactionDetailViewModel.of(
              tx,
              accountName: state.accountNames[tx.accountId] ?? '',
              confirmedPairId: await _confirmedPairIdOf(tx),
            ),
          ),
        );
    }
  }

  /// Cặp **đã xác nhận** đang chứa giao dịch này, nếu có (UC-04 bước 4 → UC-09).
  ///
  /// Một lời gọi cho cả hai thứ màn hình chi tiết cần: chỉ báo "đã đối soát" và
  /// định danh cặp để mở thẳng tới nó. Không đọc từ [TransactionsState.rows] dù
  /// dòng có thể đang nằm sẵn ở đó — danh sách chỉ mang cờ boolean, và vào thẳng
  /// bằng route thì nó còn rỗng.
  Future<int?> _confirmedPairIdOf(Transaction tx) async {
    final id = tx.transactionId;
    if (id == null) return null;
    // Đọc hỏng thì báo "chưa đối soát": màn hình đang dựng một chỉ báo, và một
    // chỉ báo vắng mặt ít gây hại hơn một chỉ báo sai xuất hiện.
    return (await _query.findConfirmedPairId(id)).valueOrNull;
  }

  Future<Map<int, String>> _loadAccountNames() async {
    final result = await _accounts.list();
    return <int, String>{
      for (final account in result.valueOrNull ?? const [])
        if (account.accountId != null) account.accountId!: account.displayName,
    };
  }

  Future<List<CurrencyUsage>> _loadCurrencies() async {
    final result = await _query.availableCurrencies();
    return result.valueOrNull ?? const <CurrencyUsage>[];
  }

  /// Từ khoá rỗng **không phải** một tiêu chí. `TransactionFilter` cũng bỏ nó,
  /// nhưng dựng `SearchText` ở đây cho một chuỗi rỗng vẫn là một lần chuẩn hoá
  /// thừa ở mỗi phím gõ.
  SearchText? _keywordOf(String raw) {
    if (raw.trim().isEmpty) return null;
    final keyword = SearchText.query(raw);
    return keyword.isEmpty ? null : keyword;
  }

  List<FilterChipViewModel> _chipsOf(TransactionsState current) =>
      FilterChips.of(
        filter: current.filter,
        context: current.context,
        accountNames: current.accountNames,
      );

  TransientNotice _noticeOf(Failure failure, String subject) =>
      _notices.of(FailurePresenter.of(failure, context: subject));
}

/// Kết quả một lần đọc một trang.
final class _CollectedPage {
  const _CollectedPage({
    required this.rows,
    required this.loadedCount,
    required this.totalCount,
    required this.hasMore,
  });

  final List<TransactionRowViewModel> rows;

  /// Số dòng đã đọc lên tính từ đầu danh sách — offset của lần đọc kế tiếp.
  final int loadedCount;

  final int totalCount;
  final bool hasMore;
}
