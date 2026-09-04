import 'package:flutter/material.dart';

import 'app/dependencies.dart';
import 'app/ledger_tracer_app.dart';

/// Điểm vào của ứng dụng.
///
/// Chỉ làm hai việc: dựng đồ thị phụ thuộc, rồi giao lại cho tầng trình bày. Mọi
/// hiểu biết về việc thứ gì nối vào thứ gì nằm ở [AppDependencies.bootstrap];
/// giữ file này mỏng có nghĩa là không có tầng nào bị khởi tạo lén ở đây.
Future<void> main() async {
  // Bắt buộc trước khi chạm tới bất kỳ plugin nào — mở cơ sở dữ liệu là một
  // trong số đó, và nó xảy ra ngay dưới đây.
  WidgetsFlutterBinding.ensureInitialized();

  final dependencies = await AppDependencies.bootstrap();
  runApp(LedgerTracerApp(dependencies: dependencies));
}
