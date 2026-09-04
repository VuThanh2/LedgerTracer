import '../../../application/import/contracts/parse_error.dart';
import '../../../application/import/contracts/parsed_row.dart';
import '../../../application/import/contracts/statement_parser.dart';
import '../../../domain/value_objects/currency.dart';
import '../../../domain/value_objects/money.dart';
import 'statement_fields.dart';

/// Đọc **một dòng** của sao kê dạng bảng thành kết quả phân tích.
///
/// CSV, Excel và JSON khác nhau ở cách lấy ra được các ô của một dòng, chứ không
/// khác nhau ở ý nghĩa của những ô đó. Phần "ý nghĩa" nằm trọn ở đây: ba parser
/// dùng chung, nên một sao kê CSV và bản Excel xuất từ cùng dữ liệu cho ra cùng
/// những `ParsedRow` — điều kiện để chống trùng giữa hai file khác định dạng của
/// cùng một tài khoản hoạt động đúng (UC-02).
abstract final class TabularStatement {
  /// [rawLine] được nhận dưới dạng hàm chứ không phải chuỗi: nó chỉ cần tới khi
  /// dòng hỏng, mà đường thành công mới là đường chạy hàng trăm nghìn lần. Dựng
  /// sẵn trích đoạn cho mọi dòng là trả chi phí của trường hợp hiếm trên toàn bộ
  /// dữ liệu.
  static ParseLineResult readRow({
    required ColumnLayout layout,
    required List<String?> cells,
    required int sourceLineNumber,
    required String Function() rawLine,
  }) {
    try {
      final currency = StatementFields.parseCurrency(
        layout.read(cells, StatementColumn.currency),
      );
      return ParseLineResult.parsed(
        ParsedRow(
          bookingDate: StatementFields.parseDate(
            layout.read(cells, StatementColumn.date),
          ),
          amount: _amountOf(layout, cells, currency),
          counterpartyName: layout.read(cells, StatementColumn.counterparty),
          description: StatementFields.parseDescription(
            layout.read(cells, StatementColumn.description),
          ),
          sourceLineNumber: sourceLineNumber,
        ),
      );
    } on StatementFieldException catch (error) {
      // Lỗi từng dòng đi về như **dữ liệu**: một dòng hỏng không được làm dừng
      // các dòng còn lại, và exception thì không vượt qua ranh giới isolate mà
      // không giết cả tác vụ (UC-02).
      return ParseLineResult.failed(
        ParseError(
          sourceLineNumber: sourceLineNumber,
          rawLine: rawLine(),
          reason: error.reason,
        ),
      );
    }
  }

  /// Số tiền có dấu của một dòng, dù nguồn viết nó thành một cột hay hai.
  ///
  /// Chuẩn hoá về **dấu** ngay tại bước phân tích là thứ cho phép luật ghép cặp
  /// ở UC-08 chỉ là một phép kiểm "hai số đối nhau" thay vì phải rẽ nhánh theo
  /// định dạng nguồn (Rule – The Sign Carries the Direction).
  static Money _amountOf(
    ColumnLayout layout,
    List<String?> cells,
    Currency currency,
  ) {
    final signed = layout.read(cells, StatementColumn.amount);
    if (signed != null) return StatementFields.parseAmount(signed, currency);

    final debit = layout.read(cells, StatementColumn.debit);
    final credit = layout.read(cells, StatementColumn.credit);
    // Sao kê hai cột thường điền `0` vào cột không dùng, nên "có giá trị" chưa
    // đủ — phải là giá trị khác 0 mới tính.
    final outgoing = debit == null
        ? null
        : StatementFields.parseAmount(debit, currency, negative: true);
    final incoming = credit == null
        ? null
        : StatementFields.parseAmount(credit, currency);

    final hasOutgoing = outgoing != null && !outgoing.isZero;
    final hasIncoming = incoming != null && !incoming.isZero;
    if (hasOutgoing && hasIncoming) {
      // Một dòng sao kê là một chiều tiền. Cả hai cột cùng khác 0 nghĩa là dòng
      // này không nói được nó vào hay ra, và đoán bừa sẽ ghi vào cơ sở dữ liệu
      // một con số sai mà không ai biết.
      throw const StatementFieldException(
        'The row carries both a debit and a credit, so the direction of the '
      'money is undecidable.',
      );
    }
    if (hasOutgoing) return outgoing;
    if (hasIncoming) return incoming;
    // Cả hai cột cùng bằng 0 vẫn là một con số đọc được; chỉ khi không cột nào
    // có giá trị mới là thiếu dữ liệu.
    return outgoing ?? incoming ?? StatementFields.parseAmount(null, currency);
  }
}
