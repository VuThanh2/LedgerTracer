import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../presentation/import/bloc/import_bloc.dart';
import '../presentation/import/bloc/import_event.dart';
import '../presentation/import/bloc/import_history_bloc.dart';
import '../presentation/reconciliation/bloc/reconciliation_bloc.dart';
import '../presentation/settings/app_lock_page.dart';
import '../presentation/settings/bloc/app_lock_bloc.dart';
import '../presentation/settings/bloc/app_lock_event.dart';
import '../presentation/settings/bloc/app_lock_state.dart';
import '../presentation/shared/export/bloc/export_bloc.dart';
import '../presentation/shared/responsive/breakpoints.dart';
import '../presentation/shell/app_shell.dart';
import '../presentation/shell/bloc/app_shell_bloc.dart';
import '../presentation/statistics/bloc/statistics_bloc.dart';
import '../presentation/transactions/bloc/transactions_bloc.dart';
import 'dependencies.dart';
import 'router.dart';
import 'theme.dart';

/// Gốc của ứng dụng.
///
/// Các BLoC sống suốt phiên được cấp **trên** [MaterialApp] chứ không bên trong
/// khung điều hướng. Hai lý do, và cả hai đều là lỗi thật nếu làm ngược lại:
/// route đẩy lên bởi `Navigator` nằm ngoài cây con của khung, nên đặt bên dưới
/// thì màn chi tiết và màn sửa không đọc được BLoC của danh sách; và một lượt
/// nhập đang chạy phải sống lâu hơn bất kỳ màn hình nào đang hiển thị.
class LedgerTracerApp extends StatefulWidget {
  const LedgerTracerApp({required this.dependencies, super.key});

  final AppDependencies dependencies;

  @override
  State<LedgerTracerApp> createState() => _LedgerTracerAppState();
}

class _LedgerTracerAppState extends State<LedgerTracerApp> {
  /// Đóng cơ sở dữ liệu khi ứng dụng thoát.
  ///
  /// Trên thiết bị thật tiến trình chết là xong, nhưng hot restart lúc phát
  /// triển thì không: đồ thị phụ thuộc được dựng lại trong khi kết nối cũ vẫn
  /// giữ file, và lần mở thứ hai gặp một cơ sở dữ liệu đang bị khoá. Gốc là nơi
  /// sở hữu tài nguyên này nên cũng là nơi phải trả nó lại.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onDetach: widget.dependencies.dispose);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DependencyScope(
    dependencies: widget.dependencies,
    child: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<AppShellBloc>(
          create: (_) => AppShellBloc(
            recoverImports: widget.dependencies.recoverImports,
            capabilities: widget.dependencies.capabilities,
          ),
        ),
        BlocProvider<TransactionsBloc>(
          create: (_) => TransactionsBloc(
            queryTransactions: widget.dependencies.queryTransactions,
            deleteTransaction: widget.dependencies.deleteTransaction,
            manageAccounts: widget.dependencies.manageAccounts,
          ),
        ),
        BlocProvider<ImportBloc>(
          create: (_) => ImportBloc(
            prepareImport: widget.dependencies.prepareImport,
            importStatements: widget.dependencies.importStatements,
            manageAccounts: widget.dependencies.manageAccounts,
            viewCashFlow: widget.dependencies.viewCashFlow,
            filePicker: widget.dependencies.statementFilePicker,
            capabilities: widget.dependencies.capabilities,
          )..add(const ImportStarted()),
        ),
        BlocProvider<ImportHistoryBloc>(
          create: (_) => ImportHistoryBloc(
            revertImport: widget.dependencies.revertImport,
            manageAccounts: widget.dependencies.manageAccounts,
          ),
        ),
        BlocProvider<ReconciliationBloc>(
          create: (_) => ReconciliationBloc(
            runReconciliation: widget.dependencies.runReconciliation,
            listPairs: widget.dependencies.listMatchAlternatives,
            confirmPair: widget.dependencies.confirmPair,
            rejectPair: widget.dependencies.rejectPair,
            manageAccounts: widget.dependencies.manageAccounts,
            viewCashFlow: widget.dependencies.viewCashFlow,
            capabilities: widget.dependencies.capabilities,
          ),
        ),
        BlocProvider<StatisticsBloc>(
          create: (_) => StatisticsBloc(
            viewCashFlow: widget.dependencies.viewCashFlow,
            listPairs: widget.dependencies.listMatchAlternatives,
          ),
        ),
        BlocProvider<ExportBloc>(
          create: (_) =>
              ExportBloc(exportDataset: widget.dependencies.exportDataset),
        ),
        BlocProvider<AppLockBloc>(
          create: (_) => AppLockBloc(
            appLock: widget.dependencies.appLock,
            resetApp: widget.dependencies.resetApp,
          )..add(const AppLockChecked()),
        ),
      ],
      child: const _LedgerMaterialApp(),
    ),
  );
}

class _LedgerMaterialApp extends StatelessWidget {
  const _LedgerMaterialApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'LedgerTracer',
    debugShowCheckedModeBanner: false,
    theme: LedgerTheme.light(),
    onGenerateRoute: LedgerRouter.onGenerateRoute,
    home: const _AppLockGate(),
    builder: (context, child) {
      // Density chọn theo **tác vụ**, và tác vụ ở đây gắn với breakpoint: bản
      // rộng là nơi nhập hàng loạt và so sánh nhiều dòng, bản hẹp là nơi tra
      // cứu và vuốt xác nhận. Quyết định ở đây, một lần, thay vì để từng widget
      // tự đoán.
      final sizeClass = WindowSizeClass.of(MediaQuery.sizeOf(context).width);
      return Theme(
        data: LedgerTheme.light(
          compactDensity: !sizeClass.usesBottomNavigation,
        ),
        child: child ?? const SizedBox.shrink(),
      );
    },
  );
}

/// Chặn toàn bộ ứng dụng khi App Lock đang bật (UC-12).
///
/// Khung ứng dụng chỉ được **dựng** sau khi cổng mở. Đặt màn khoá thành một
/// route đẩy chồng lên sẽ vẫn dựng cây bên dưới và đọc dữ liệu lên trước khi ai
/// đó chứng minh được mình có quyền — lớp khoá khi ấy chỉ là một tấm che.
class _AppLockGate extends StatelessWidget {
  const _AppLockGate();

  @override
  Widget build(BuildContext context) => BlocBuilder<AppLockBloc, AppLockState>(
    buildWhen: (previous, current) => previous.gate != current.gate,
    builder: (context, state) => switch (state.gate) {
      AppLockGate.unknown => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      AppLockGate.locked => const AppLockPage(),
      AppLockGate.unlocked => const AppShell(),
    },
  );
}
