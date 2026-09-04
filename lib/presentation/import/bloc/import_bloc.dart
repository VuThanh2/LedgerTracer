import 'package:bloc/bloc.dart';

import '../../../application/accounts/manage_accounts/manage_accounts_use_case.dart';
import '../../../application/import/import_statements/import_statements_dto.dart';
import '../../../application/import/import_statements/import_statements_use_case.dart';
import '../../../application/import/prepare_import/prepare_import_dto.dart';
import '../../../application/import/prepare_import/prepare_import_use_case.dart';
import '../../../application/statistics/view_cash_flow/view_cash_flow_use_case.dart';
import '../../../core/concurrency/cancellation_signal.dart';
import '../../../core/concurrency/platform_capabilities.dart';
import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../../domain/entities/bank_account.dart';
import '../../shared/bloc/event_transformers.dart';
import '../../shared/bloc/transient_notice.dart';
import '../../shared/failures/failure_presenter.dart';
import '../../shared/queries/account_activity.dart';
import '../ports/statement_file_picker.dart';
import '../view_models/import_file_entry.dart';
import '../view_models/import_progress_view_model.dart';
import 'import_event.dart';
import 'import_state.dart';

/// Tab *Nhập mới*: stepper bốn bước của một lượt nhập sao kê (UC-02, UC-14).
///
/// BLoC này là nơi **nối hai nửa** mà tầng Application cố ý tách rời.
/// `PrepareImportUseCase` lo phần ngắn và cần người dùng trả lời — nhận diện
/// định dạng, đối chiếu số tài khoản; `ImportStatementsUseCase` lo phần chạy
/// hàng phút trên luồng nền và không được dừng lại hỏi ai. Chỗ nối ấy đúng là
/// một màn hình có bốn bước, và giữ nó ở đây là điều kiện để việc chờ người dùng
/// bấm không bao giờ nghẽn hàng đợi ghi tuần tự.
///
/// Hai việc nhỏ mà không nửa nào ở tầng dưới nhận, nên chúng thuộc về đây:
///
/// * **Ghi nhận số tài khoản học được** (`learnAccountNumber`) chạy ngay trước
///   khi nhập, cho những file có phán quyết `willLearn`. Use case nhập không gọi
///   nó, và đúng là không nên: nó là hệ quả của một quyết định người dùng vừa
///   đưa ra ở bước 2, không phải một bước của việc phân tích file.
/// * **Bỏ file khỏi lượt** trước khi chạy — khác hẳn "bỏ qua file này" ở cảnh
///   báo lệch số tài khoản, thứ vẫn để lại một bản ghi trong lịch sử.
final class ImportBloc extends Bloc<ImportEvent, ImportState> {
  ImportBloc({
    required PrepareImportUseCase prepareImport,
    required ImportStatementsUseCase importStatements,
    required ManageAccountsUseCase manageAccounts,
    required ViewCashFlowUseCase viewCashFlow,
    required StatementFilePicker filePicker,
    required this.capabilities,
  }) : _prepare = prepareImport,
       _import = importStatements,
       _accounts = manageAccounts,
       _cashFlow = viewCashFlow,
       _picker = filePicker,
       super(const ImportState()) {
    on<ImportStarted>(_onStarted, transformer: EventTransformers.restartable());
    // Hộp thoại chọn file của nền tảng không được mở hai lần chồng nhau.
    on<ImportFilesPickRequested>(_onPickRequested, transformer: EventTransformers.droppable());
    on<ImportFileRemoved>(_onFileRemoved);
    on<ImportFileAccountAssigned>(_onAccountAssigned, transformer: EventTransformers.sequential());
    on<ImportAccountCreated>(_onAccountCreated, transformer: EventTransformers.sequential());
    on<ImportMismatchResolved>(_onMismatchResolved);
    on<ImportStepAdvanced>(_onStepAdvanced);
    on<ImportStepReverted>(_onStepReverted);
    on<ImportRunRequested>(_onRunRequested, transformer: EventTransformers.droppable());
    on<ImportRunCancelled>(_onRunCancelled);
    on<ImportReset>(_onReset);
  }

  final PrepareImportUseCase _prepare;
  final ImportStatementsUseCase _import;
  final ManageAccountsUseCase _accounts;
  final ViewCashFlowUseCase _cashFlow;
  final StatementFilePicker _picker;
  final NoticeSink _notices = NoticeSink();

  final PlatformCapabilities capabilities;

  CancellationSignal? _cancellation;

  @override
  Future<void> close() {
    // Rời tab giữa lượt nhập: phát tín hiệu dừng. Phần đã ghi vẫn nằm đó và lượt
    // sẽ được ghi nhận là đã huỷ — không có gì bị bỏ lửng ở trạng thái dở dang.
    _cancellation?.cancel();
    return super.close();
  }

  Future<void> _onStarted(
    ImportStarted event,
    Emitter<ImportState> emit,
  ) async {
    emit(
      state.copyWith(
        accounts: await _loadAccounts(),
        supportsIsolates: capabilities.supportsIsolates,
      ),
    );
  }

  Future<void> _onPickRequested(
    ImportFilesPickRequested event,
    Emitter<ImportState> emit,
  ) async {
    emit(state.copyWith(isPicking: true, clearError: true));

    final List<PickedFile> picked;
    try {
      picked = await _picker.pickStatements();
    } on Object catch (error) {
      emit(
        state.copyWith(
          isPicking: false,
          notice: _notices.danger(
            'Không mở được hộp thoại chọn file: $error',
          ),
        ),
      );
      return;
    }
    if (picked.isEmpty) {
      // Đóng hộp thoại mà không chọn gì không phải một lỗi và không đáng một
      // thông báo — chỉ là không có gì để làm tiếp.
      emit(state.copyWith(isPicking: false));
      return;
    }

    final inspected = await _prepare.inspect(picked);
    switch (inspected) {
      case Err<List<InspectedFile>>(:final failure):
        emit(
          state.copyWith(
            isPicking: false,
            notice: _noticeOf(failure, 'file sao kê'),
          ),
        );
      case Ok<List<InspectedFile>>(:final value):
        // Chọn thêm thì **cộng dồn** chứ không thay thế: chọn nhiều lần là cách
        // duy nhất gom file từ nhiều thư mục vào cùng một lượt, và trên Web thì
        // hộp thoại của trình duyệt cũng chỉ mở được một thư mục mỗi lần.
        final existing = <String>{for (final file in state.files) file.fileName};
        emit(
          state.copyWith(
            isPicking: false,
            files: <ImportFileEntry>[
              ...state.files,
              for (final file in value)
                if (!existing.contains(file.fileName))
                  ImportFileEntry.of(file),
            ],
          ),
        );
    }
  }

  void _onFileRemoved(ImportFileRemoved event, Emitter<ImportState> emit) {
    if (state.isRunning) return;
    emit(
      state.copyWith(
        files: <ImportFileEntry>[
          for (final file in state.files)
            if (file.fileName != event.fileName) file,
        ],
      ),
    );
  }

  Future<void> _onAccountAssigned(
    ImportFileAccountAssigned event,
    Emitter<ImportState> emit,
  ) async {
    final entry = _entryOf(event.fileName);
    final recognized = entry?.recognized;
    if (entry == null || recognized == null) return;

    final check = await _prepare.checkAssignment(
      file: recognized,
      accountId: event.accountId,
    );
    switch (check) {
      case Err<AccountAssignmentCheck>(:final failure):
        emit(state.copyWith(notice: _noticeOf(failure, 'tài khoản')));
      case Ok<AccountAssignmentCheck>(:final value):
        emit(
          state.copyWith(
            files: _replace(
              entry.copyWith(
                accountId: event.accountId,
                check: value,
                // Gán lại tài khoản khác là một khởi đầu mới cho phép đối chiếu,
                // nên quyết định cũ không còn nghĩa gì: giữ nó lại nghĩa là một
                // "vẫn nhập" của lần trước sẽ âm thầm áp cho một cảnh báo khác.
                clearDecision: true,
              ),
            ),
          ),
        );
    }
  }

  Future<void> _onAccountCreated(
    ImportAccountCreated event,
    Emitter<ImportState> emit,
  ) async {
    final created = await _accounts.add(event.displayName);
    switch (created) {
      case Err<BankAccount>(:final failure):
        emit(state.copyWith(notice: _noticeOf(failure, 'tài khoản')));
      case Ok<BankAccount>(:final value):
        emit(
          state.copyWith(
            accounts: <BankAccount>[...state.accounts, value],
            notice: _notices.success('Đã tạo tài khoản "${value.displayName}".'),
          ),
        );
        final fileName = event.assignToFileName;
        if (fileName != null) {
          add(
            ImportFileAccountAssigned(
              fileName: fileName,
              accountId: value.accountId!,
            ),
          );
        }
    }
  }

  void _onMismatchResolved(
    ImportMismatchResolved event,
    Emitter<ImportState> emit,
  ) {
    final entry = _entryOf(event.fileName);
    if (entry == null) return;
    emit(
      state.copyWith(files: _replace(entry.copyWith(decision: event.decision))),
    );
  }

  void _onStepAdvanced(ImportStepAdvanced event, Emitter<ImportState> emit) {
    switch (state.step) {
      case ImportStep.pickFiles:
        if (state.canAssignAccounts) {
          emit(state.copyWith(step: ImportStep.assignAccounts));
        }
      case ImportStep.assignAccounts:
        // Bước 2 **chặn cứng**: đi tiếp khi còn file chưa gán hoặc còn cảnh báo
        // chưa trả lời là nhập sao kê vào nhầm tài khoản (UC-02 bước 4).
        if (state.canRun) add(const ImportRunRequested());
      case ImportStep.running || ImportStep.summary:
        break;
    }
  }

  void _onStepReverted(ImportStepReverted event, Emitter<ImportState> emit) {
    if (!state.step.canGoBack) return;
    emit(state.copyWith(step: ImportStep.pickFiles));
  }

  Future<void> _onRunRequested(
    ImportRunRequested event,
    Emitter<ImportState> emit,
  ) async {
    if (state.isRunning || !state.canRun) return;

    // Ghi nhận số tài khoản học được từ file đầu tiên mang nó, **trước** khi
    // isolate nào khởi động: sau đó luồng chính còn bận đối chiếu và ghi, và một
    // lệnh ghi thiết lập chen vào giữa là một lệnh ghi tranh chấp không cần có.
    for (final entry in state.recognizedFiles) {
      if (!entry.willLearnAccountNumber || entry.isSkipped) continue;
      final number = entry.check?.embeddedAccountNumber;
      if (number == null) continue;
      await _prepare.learnAccountNumber(
        accountId: entry.accountId!,
        accountNumber: number,
      );
    }

    final cancellation = CancellationSignal();
    _cancellation = cancellation;
    emit(
      state.copyWith(
        step: ImportStep.running,
        isCancelling: false,
        clearProgress: true,
        clearSummary: true,
        clearError: true,
      ),
    );

    final accountNames = <int, String>{
      for (final account in state.accounts)
        if (account.accountId != null) account.accountId!: account.displayName,
    };

    final result = await _import.execute(
      ImportStatementsRequest(
        files: <ImportFileInput>[
          for (final entry in state.recognizedFiles) entry.toInput(),
        ],
        cancellation: cancellation,
      ),
      onProgress: (progress) {
        if (isClosed) return;
        emit(state.copyWith(progress: ImportProgressViewModel.of(progress)));
      },
    );

    _cancellation = null;
    switch (result) {
      case Err<ImportSummary>(:final failure):
        // Cả lượt hỏng là chuyện khác hẳn một file hỏng: file hỏng đi về như dữ
        // liệu và vẫn có bảng tổng kết, còn tới đây thì không có gì để tổng kết.
        emit(
          state.copyWith(
            step: ImportStep.pickFiles,
            isCancelling: false,
            clearProgress: true,
            error: FailurePresenter.of(failure, context: 'lượt nhập'),
          ),
        );
      case Ok<ImportSummary>(:final value):
        // Huỷ xong **vẫn đi tiếp sang bước 4**: phần đã ghi là kết quả thật và
        // phải được tổng kết, chứ không bị vứt đi cùng lượt (UC-02 bước 7).
        emit(
          state.copyWith(
            step: ImportStep.summary,
            isCancelling: false,
            clearProgress: true,
            summary: ImportSummaryViewModel.of(
              value,
              accountNames: accountNames,
            ),
            // Đọc **sau** khi ghi xong, không phải trước: chính lượt nhập vừa
            // rồi có thể là lượt làm cho tài khoản thứ hai có giao dịch đầu
            // tiên, và đó đúng là lúc nút "Chạy đối soát" nên xuất hiện.
            accountsWithTransactions:
                await AccountActivity.countAccountsWithTransactions(_cashFlow),
          ),
        );
    }
  }

  void _onRunCancelled(ImportRunCancelled event, Emitter<ImportState> emit) {
    if (!state.isRunning || state.isCancelling) return;
    _cancellation?.cancel();
    emit(state.copyWith(isCancelling: true));
  }

  void _onReset(ImportReset event, Emitter<ImportState> emit) {
    if (state.isRunning) return;
    emit(
      ImportState(
        // Danh sách tài khoản được giữ lại: nó vừa được đọc xong và không dính
        // gì tới lượt vừa kết thúc.
        accounts: state.accounts,
        supportsIsolates: state.supportsIsolates,
      ),
    );
  }

  ImportFileEntry? _entryOf(String fileName) {
    for (final file in state.files) {
      if (file.fileName == fileName) return file;
    }
    return null;
  }

  /// Thay một mục theo tên file, giữ nguyên thứ tự.
  ///
  /// Thứ tự chính là thứ tự người dùng chọn file, và tầng dưới ghi theo đúng thứ
  /// tự đó để hai lần nhập cùng một tập file cho cùng một kết quả — xáo trộn nó
  /// ở đây là phá một bất biến nằm ở tầng khác.
  List<ImportFileEntry> _replace(ImportFileEntry updated) => <ImportFileEntry>[
    for (final file in state.files)
      if (file.fileName == updated.fileName) updated else file,
  ];

  Future<List<BankAccount>> _loadAccounts() async =>
      (await _accounts.list()).valueOrNull ?? const <BankAccount>[];

  TransientNotice _noticeOf(Failure failure, String subject) =>
      _notices.of(FailurePresenter.of(failure, context: subject));
}
