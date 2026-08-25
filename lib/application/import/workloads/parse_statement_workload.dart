import 'dart:typed_data';

import '../../../core/concurrency/isolate_runner.dart';
import '../../../core/concurrency/progress_report.dart';
import '../contracts/parse_batch.dart';
import '../contracts/parse_error.dart';
import '../contracts/parsed_row.dart';
import '../contracts/statement_parser.dart';

/// Đầu vào của workload phân tích một file. Đi qua ranh giới isolate nên mọi
/// trường phải sao chép được: [parser] là một [StatementParser] không trạng thái,
/// [bytes] là nội dung file, [batchSize] là núm vặn từ `ConcurrencyStrategy`.
final class ParseStatementInput {
  const ParseStatementInput({
    required this.parser,
    required this.bytes,
    required this.batchSize,
  });

  final StatementParser parser;
  final Uint8List bytes;
  final int batchSize;
}

/// Phân tích một file sao kê thành các [ParseBatch], chạy trong isolate trên
/// native và trên luồng chính khi suy biến trên Web (UC-02, UC-14).
///
/// **Bắt buộc là hàm top-level, không bắt trạng thái bên ngoài**: đó là ràng buộc
/// cứng của `Isolate.spawn`. Mọi thứ nó cần đến qua [input]; mọi thứ nó báo ra đi
/// qua [context].
///
/// Vòng lặp gom [ConcurrencyStrategy.batchSize] dòng rồi mới giao một lô. `await`
/// trên [WorkloadContext.emit] vừa là backpressure (phân tích dừng khi luồng ghi
/// còn bận) vừa là chỗ **duy nhất** một yêu cầu huỷ được nhìn thấy — isolate chỉ
/// biết chuyện bên ngoài giữa hai lượt event loop của chính nó. Huỷ giữa chừng
/// thì các lô đã giao vẫn được giữ (UC-02 bước 7).
Future<void> parseStatementWorkload(
  ParseStatementInput input,
  WorkloadContext<ParseBatch> context,
) async {
  // Ước lượng tổng số dòng một lần, ngay đầu: thanh tiến trình có tỷ lệ ngay từ
  // lô đầu tiên thay vì chỉ quay tròn cho tới lúc xong. `null` là hợp lệ — định
  // dạng nào không cho biết rẻ tiền thì tiến trình là loại không xác định.
  final total = input.parser.estimateRowCount(input.bytes);
  context.reportProgress(ProgressReport(processed: 0, total: total));

  final rows = <ParsedRow>[];
  final errors = <ParseError>[];
  var batchIndex = 0;
  var processed = 0;

  final iterator = input.parser.parseLines(input.bytes).iterator;
  var hasNext = iterator.moveNext();
  while (hasNext) {
    switch (iterator.current) {
      case ParsedLine(:final row):
        rows.add(row);
      case RejectedLine(:final error):
        errors.add(error);
    }
    processed++;
    hasNext = iterator.moveNext();

    if (rows.length + errors.length >= input.batchSize || !hasNext) {
      // Kiểm huỷ tại ranh giới lô: dừng lại thì phần đã giao vẫn nằm đó, tín hiệu
      // huỷ là thứ phân biệt "chạy hết" với "dừng theo yêu cầu".
      if (context.isCancelled) return;
      await context.emit(
        ParseBatch(
          index: batchIndex++,
          rows: List<ParsedRow>.of(rows),
          errors: List<ParseError>.of(errors),
          isLast: !hasNext,
        ),
      );
      context.reportProgress(
        ProgressReport(processed: processed, total: total),
      );
      rows.clear();
      errors.clear();
    }
  }
}
