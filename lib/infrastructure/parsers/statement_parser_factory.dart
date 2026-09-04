import '../../application/import/contracts/statement_parser.dart';
import '../../domain/value_objects/statement_format.dart';
import 'csv/csv_parser.dart';
import 'excel/excel_parser.dart';
import 'json/json_parser.dart';
import 'mt940/mt940_parser.dart';

/// Nguồn cấp parser theo định dạng đã nhận diện.
///
/// Tách khỏi [StatementParser] vì bản thân factory **không** đi qua ranh giới
/// isolate — chỉ parser nó trả về mới đi. Đó cũng là lý do mọi parser ở đây đều
/// là hằng: một object bất biến, không trạng thái, không giữ tài nguyên gắn với
/// luồng gốc là thứ duy nhất sao chép sang isolate được.
final class DefaultStatementParserFactory implements StatementParserFactory {
  const DefaultStatementParserFactory();

  @override
  StatementParser parserFor(StatementFormat format) => switch (format) {
    StatementFormat.csv => const CsvParser(),
    StatementFormat.excel => const ExcelParser(),
    StatementFormat.mt940 => const Mt940Parser(),
    StatementFormat.json => const JsonParser(),
  };
}
