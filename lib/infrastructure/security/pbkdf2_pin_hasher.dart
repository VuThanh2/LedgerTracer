import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../application/settings/app_lock/app_lock_use_case.dart';

/// Hiện thực [PinHasher] bằng PBKDF2-HMAC-SHA256, mỗi mã PIN một muối riêng
/// (UC-12).
///
/// ## Vì sao phải là một hàm băm **chậm**
///
/// Mã PIN chỉ có 4–6 chữ số, tức nhiều nhất một triệu khả năng. Với một hàm băm
/// nhanh, người cầm được thiết bị dò hết cả không gian đó trong vài giây — lớp
/// khoá ứng dụng khi ấy chỉ còn là một cánh cửa dán giấy. Chi phí mỗi lần thử là
/// **thứ duy nhất** bảo vệ một bí mật ngắn như vậy, nên số vòng lặp ở đây không
/// phải một núm vặn tuỳ ý.
///
/// ## Đánh đổi phải nói thẳng: phép băm chạy trên luồng giao diện
///
/// Hợp đồng [PinHasher] là **đồng bộ**, nên phép dẫn xuất chạy ngay trên luồng
/// đang vẽ giao diện và giữ nó lại trong một khoảng thấy được. Chấp nhận được vì
/// nó chỉ xảy ra ở đúng ba thời điểm rời rạc do người dùng chủ động gây ra — mở
/// khoá, đặt PIN, đổi PIN — chứ không phải trong một vòng lặp; đây khác hẳn về
/// bản chất với hai workload nhập liệu và đối soát, vốn chạy hàng phút và vì thế
/// mới cần tới cả một tầng concurrency. Giao diện nên hiện trạng thái chờ trong
/// khoảnh khắc đó thay vì trông như bị treo.
final class Pbkdf2PinHasher implements PinHasher {
  const Pbkdf2PinHasher();

  /// Nhãn thuật toán, ghi vào chính chuỗi hash.
  ///
  /// Nhờ nó, đổi thuật toán về sau không làm mọi mã PIN đang tồn tại thành vô
  /// nghĩa: [verify] đọc được bản ghi cũ, và mã PIN được nâng cấp lặng lẽ ở lần
  /// đổi PIN kế tiếp.
  static const String _algorithm = 'pbkdf2-sha256';

  /// Số vòng lặp, chọn theo **thời gian đo được** chứ không theo con số khuyến
  /// nghị chung.
  ///
  /// Mức OWASP khuyến nghị cho PBKDF2-HMAC-SHA256 là 210.000 vòng, và bản sao
  /// lưu ở UC-13 dùng đúng con số đó — nó chạy bất đồng bộ, một lần, cho một
  /// thao tác người dùng vốn đã biết là lâu. Ở đây thì không: hợp đồng
  /// [PinHasher] là đồng bộ nên phép dẫn xuất giữ luôn luồng giao diện, và ở
  /// 210.000 vòng thì màn hình khoá đứng khoảng một giây trên máy tính để bàn —
  /// tức vài giây trên điện thoại tầm trung, mỗi lần mở ứng dụng.
  ///
  /// 50.000 vòng giữ chi phí ở mức người dùng chấp nhận được mà vẫn khiến việc
  /// dò hết không gian một triệu mã PIN sáu chữ số trở nên đắt. Con số này được
  /// ghi vào chính chuỗi hash, nên nâng nó lên khi có một hiện thực bất đồng bộ
  /// sẽ không làm hỏng mã PIN nào đang tồn tại.
  static const int _iterations = 50000;

  static const int _saltLength = 16;
  static const int _keyLength = 32;

  @override
  String hash(String pin) {
    final salt = _randomSalt();
    final derived = _derive(pin, salt, _iterations);
    // Muối và số vòng đi cùng hash, không nằm ở bảng khác: một bản ghi tự mô tả
    // là bản ghi không thể bị tách rời khỏi tham số đã tạo ra nó.
    return <String>[
      _algorithm,
      '$_iterations',
      base64.encode(salt),
      base64.encode(derived),
    ].join(r'$');
  }

  @override
  bool verify(String pin, String hash) {
    final parts = hash.split(r'$');
    if (parts.length != 4 || parts.first != _algorithm) return false;
    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations < 1) return false;

    final Uint8List salt;
    final Uint8List expected;
    try {
      salt = base64.decode(parts[2]);
      expected = base64.decode(parts[3]);
    } on FormatException {
      // Bản ghi hỏng là "không mở được", không phải "mở được". Trả `false` chứ
      // không ném: nơi gọi hỏi một câu có/không, và một ngoại lệ ở đây sẽ nổi
      // lên thành lỗi hệ thống thay vì thành "sai PIN".
      return false;
    }

    return _constantTimeEquals(
      _derive(pin, salt, iterations, length: expected.length),
      expected,
    );
  }

  /// PBKDF2 theo RFC 8018, dựng trên HMAC-SHA256 của `package:crypto`.
  ///
  /// Chỉ phần *lặp* là tự viết; hàm băm và HMAC bên dưới đều là hiện thực đã
  /// được kiểm chứng. Đó là ranh giới đúng: vòng lặp PBKDF2 là một công thức
  /// công khai và ngắn, còn tự viết lấy một hàm băm thì không bao giờ nên làm.
  static Uint8List _derive(
    String password,
    List<int> salt,
    int iterations, {
    int length = _keyLength,
  }) {
    final hmac = Hmac(sha256, utf8.encode(password));
    final output = BytesBuilder(copy: false);
    final blocks = (length + _blockLength - 1) ~/ _blockLength;

    for (var block = 1; block <= blocks; block++) {
      var current = hmac.convert(<int>[...salt, ..._bigEndian(block)]).bytes;
      final accumulated = Uint8List.fromList(current);
      for (var round = 1; round < iterations; round++) {
        current = hmac.convert(current).bytes;
        for (var index = 0; index < accumulated.length; index++) {
          accumulated[index] ^= current[index];
        }
      }
      output.add(accumulated);
    }
    return Uint8List.sublistView(output.toBytes(), 0, length);
  }

  /// So sánh không rẽ nhánh theo dữ liệu.
  ///
  /// `==` trên danh sách bytes dừng ngay ở byte đầu tiên khác nhau, và thời gian
  /// chênh lệch đó là thứ đo được. Ở đây rủi ro thực tế rất thấp — kẻ tấn công
  /// đã cầm thiết bị trong tay — nhưng phép so sánh đúng cách không đắt hơn phép
  /// so sánh sai cách chút nào.
  static bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }

  /// Muối phải đến từ nguồn ngẫu nhiên **an toàn mật mã**: muối đoán được thì
  /// bảng tra dựng sẵn lại có tác dụng, và toàn bộ lý do tồn tại của muối biến
  /// mất.
  static Uint8List _randomSalt() {
    final random = Random.secure();
    return Uint8List.fromList(<int>[
      for (var index = 0; index < _saltLength; index++) random.nextInt(256),
    ]);
  }

  static List<int> _bigEndian(int value) => <int>[
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ];

  /// Độ dài đầu ra của SHA-256.
  static const int _blockLength = 32;
}
