import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../application/settings/backup_restore/backup_restore_dto.dart';
import '../../application/settings/contracts/app_data_store.dart';

/// Mã hoá và giải mã file sao lưu bằng AES-256-GCM, khoá dẫn xuất từ mật khẩu
/// người dùng bằng PBKDF2-HMAC-SHA256 (UC-13).
///
/// ## Vì sao là AES-GCM chứ không phải một phép mã hoá đơn thuần
///
/// UC-13 bước 3 đòi hai thứ cùng lúc: giải mã **và** kiểm tra tính toàn vẹn,
/// trước khi bất kỳ dữ liệu hiện có nào bị đụng tới. GCM cho cả hai trong một
/// bước — thẻ xác thực của nó vừa phát hiện sai mật khẩu vừa phát hiện file bị
/// sửa hay hỏng giữa chừng. Với một phép mã hoá không xác thực, sai mật khẩu sẽ
/// cho ra một khối bytes rác trông như đã giải mã thành công, và thứ duy nhất
/// chặn nó lại sẽ là bộ đọc JSON ở tầng trên — một lưới an toàn không được thiết
/// kế để đỡ việc đó.
///
/// ## Vì sao mật khẩu này không liên quan gì tới mã PIN
///
/// Lối thoát khi quên PIN là reset ứng dụng rồi khôi phục từ bản sao lưu (UC-12).
/// Nếu file sao lưu được mã hoá bằng khoá dẫn xuất từ chính PIN đã quên thì hai
/// use case triệt tiêu nhau: quên PIN là mất trắng cả dữ liệu lẫn bản sao lưu.
/// Vì vậy khoá ở đây **chỉ** đến từ mật khẩu người dùng đặt riêng cho từng file,
/// và ứng dụng không giữ bản sao nào của nó.
final class AesGcmBackupCodec implements BackupCodec {
  const AesGcmBackupCodec();

  /// Nhãn nhận dạng ở đầu file, để một file không phải bản sao lưu bị nhận ra
  /// **trước** khi mật khẩu bị đem ra thử — người dùng cần biết mình chọn nhầm
  /// file, không phải nghi ngờ mình gõ nhầm mật khẩu.
  static const List<int> _magic = <int>[0x4C, 0x54, 0x42, 0x4B]; // 'LTBK'

  static const int _formatVersion = 1;
  static const int _saltLength = 16;
  static const int _nonceLength = 12;
  static const int _macLength = 16;

  /// Số vòng lặp của PBKDF2.
  ///
  /// Đây là một đánh đổi cố ý nghiêng về phía thiết bị yếu: con số càng lớn thì
  /// tấn công dò mật khẩu càng đắt, nhưng người dùng cũng chờ càng lâu ở mỗi lần
  /// sao lưu và khôi phục — trên một chiếc điện thoại tầm trung, không phải trên
  /// máy chủ. 210.000 vòng là mức OWASP khuyến nghị cho PBKDF2-HMAC-SHA256.
  ///
  /// Số vòng được **ghi vào file**, nên nâng nó về sau không làm hỏng các bản
  /// sao lưu cũ.
  static const int _iterations = 210000;

  @override
  Future<Uint8List> encrypt(Uint8List plain, String password) async {
    final salt = _randomBytes(_saltLength);
    final nonce = _randomBytes(_nonceLength);
    final key = await _deriveKey(password, salt, _iterations);
    final box = await AesGcm.with256bits().encrypt(
      plain,
      secretKey: key,
      nonce: nonce,
    );

    final builder = BytesBuilder(copy: false)
      ..add(_magic)
      ..addByte(_formatVersion)
      ..add(_uint32(_iterations))
      ..add(salt)
      ..add(nonce)
      ..add(box.mac.bytes)
      ..add(box.cipherText);
    return builder.toBytes();
  }

  @override
  Future<Uint8List> decrypt(Uint8List cipher, String password) async {
    final header = _headerLength;
    if (cipher.length < header || !_startsWithMagic(cipher)) {
      // File không phải bản sao lưu của ứng dụng này. Đây là "chọn nhầm file",
      // không phải "sai mật khẩu" — hai chuyện dẫn tới hai việc khác nhau mà
      // người dùng phải làm tiếp (UC-13).
      throw const CorruptBackupException(
        'File này không phải bản sao lưu của LedgerTracer.',
      );
    }
    if (cipher[_magic.length] != _formatVersion) {
      throw const CorruptBackupException(
        'Bản sao lưu được tạo bởi một phiên bản ứng dụng không tương thích.',
      );
    }

    var offset = _magic.length + 1;
    final iterations = _readUint32(cipher, offset);
    offset += 4;
    final salt = Uint8List.sublistView(cipher, offset, offset + _saltLength);
    offset += _saltLength;
    final nonce = Uint8List.sublistView(cipher, offset, offset + _nonceLength);
    offset += _nonceLength;
    final mac = Uint8List.sublistView(cipher, offset, offset + _macLength);
    offset += _macLength;

    final key = await _deriveKey(password, salt, iterations);
    try {
      final plain = await AesGcm.with256bits().decrypt(
        SecretBox(
          Uint8List.sublistView(cipher, offset),
          nonce: nonce,
          mac: Mac(mac),
        ),
        secretKey: key,
      );
      return Uint8List.fromList(plain);
    } on SecretBoxAuthenticationError {
      // Thẻ xác thực không khớp. Sai mật khẩu và file bị sửa đổi cho ra cùng một
      // kết quả ở đây, và **không** phân biệt được là đúng: cố đoán xem là
      // trường hợp nào sẽ phải rò rỉ thông tin về khoá.
      throw const BackupPasswordException();
    }
  }

  static Future<SecretKey> _deriveKey(
    String password,
    List<int> salt,
    int iterations,
  ) => Pbkdf2.hmacSha256(
    iterations: iterations,
    bits: 256,
  ).deriveKeyFromPassword(password: password, nonce: salt);

  static int get _headerLength =>
      _magic.length + 1 + 4 + _saltLength + _nonceLength + _macLength;

  static bool _startsWithMagic(Uint8List bytes) {
    for (var index = 0; index < _magic.length; index++) {
      if (bytes[index] != _magic[index]) return false;
    }
    return true;
  }

  /// Muối và nonce phải đến từ nguồn ngẫu nhiên **an toàn mật mã**.
  ///
  /// `Random()` thường được gieo từ đồng hồ và đoán được; dùng nó ở đây sẽ khiến
  /// hai lần sao lưu liên tiếp có thể dùng lại cùng một nonce, và dùng lại nonce
  /// là cách phá vỡ AES-GCM một cách kinh điển.
  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(<int>[
      for (var index = 0; index < length; index++) random.nextInt(256),
    ]);
  }

  static List<int> _uint32(int value) => <int>[
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ];

  static int _readUint32(Uint8List bytes, int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
}
