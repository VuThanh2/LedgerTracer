package com.example.ledger_tracer

import io.flutter.embedding.android.FlutterFragmentActivity

// Kế thừa FlutterFragmentActivity chứ không phải FlutterActivity vì mở khoá bằng
// sinh trắc học (UC-12) chạy trên androidx.biometric, và thư viện đó dựng hộp
// thoại của nó bằng một Fragment.
//
// LocalAuthPlugin kiểm đúng điều này: `if (!(activity instanceof FragmentActivity))`
// thì nó trả về NOT_FRAGMENT_ACTIVITY và không bao giờ hiện hộp thoại. Đây là
// thất bại **im lặng** — ứng dụng không sập, nút mở khoá bằng vân tay chỉ đơn
// giản là không bao giờ hoạt động — nên nó sẽ không lộ ra lúc chạy thử nếu không
// ai thử đúng nút đó trên máy thật có vân tay.
//
// FlutterFragmentActivity nằm trong chính engine của Flutter và có cùng vòng đời,
// cùng cách đăng ký plugin như FlutterActivity; đổi qua nó không đụng gì tới phần
// còn lại của ứng dụng.
class MainActivity : FlutterFragmentActivity()
