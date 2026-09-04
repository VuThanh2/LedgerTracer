import 'package:flutter/material.dart';

/// Bảng màu nghiệp vụ của LedgerTracer, đặt trong một [ThemeExtension] chứ
/// không rải `Color(0xFF...)` khắp các widget.
///
/// DESIGN.md nói rõ lý do: màu ở đây là **chính sách**, không phải chi tiết
/// trình bày. Ba kênh ngữ nghĩa (hướng tiền, trạng thái phán quyết, phản hồi hệ
/// thống) mang nghĩa cố định, nên chúng phải khai báo được ở một chỗ, kiểm thử
/// được, và đổi được sang một bảng màu khác — ví dụ giao diện tối — mà không
/// phải sờ vào một widget nào.
///
/// [ColorScheme] của Material không đủ chỗ cho chúng: nó có `error` nhưng không
/// có "tiền vào", không có "đã từ chối", và không có "đường kẻ mỗi 5 dòng".
@immutable
final class LedgerColors extends ThemeExtension<LedgerColors> {
  const LedgerColors({
    required this.primary,
    required this.primaryDeep,
    required this.primaryPress,
    required this.primarySoft,
    required this.primarySubdued,
    required this.primaryWash,
    required this.brandDark,
    required this.darkSurface,
    required this.darkHairline,
    required this.darkInkMute,
    required this.ink,
    required this.inkSecondary,
    required this.inkMute,
    required this.inkMuteNav,
    required this.onPrimary,
    required this.canvas,
    required this.canvasSoft,
    required this.canvasCream,
    required this.creamWash,
    required this.rubyWash,
    required this.hairline,
    required this.hairlineStructure,
    required this.hairlineControl,
    required this.shadowBlue,
    required this.moneyIn,
    required this.moneyInSoft,
    required this.moneyOutGraphic,
    required this.moneyOut,
    required this.magenta,
    required this.lemon,
    required this.lemonInk,
  });

  /// Bảng màu sáng — bảng duy nhất của bản này.
  static const LedgerColors light = LedgerColors(
    primary: Color(0xFF533AFD),
    primaryDeep: Color(0xFF4434D4),
    primaryPress: Color(0xFF2E2B8C),
    primarySoft: Color(0xFF665EFD),
    primarySubdued: Color(0xFFB9B9F9),
    primaryWash: Color(0xFFEEECFF),
    brandDark: Color(0xFF1C1E54),
    darkSurface: Color(0xFF262A63),
    darkHairline: Color(0xFF33377A),
    darkInkMute: Color(0xFF8E96C4),
    ink: Color(0xFF0D253D),
    inkSecondary: Color(0xFF273951),
    inkMute: Color(0xFF64748D),
    inkMuteNav: Color(0xFF61718A),
    onPrimary: Color(0xFFFFFFFF),
    canvas: Color(0xFFFFFFFF),
    canvasSoft: Color(0xFFF6F9FC),
    canvasCream: Color(0xFFF5E9D4),
    creamWash: Color(0xFFFDF7EC),
    rubyWash: Color(0xFFFDECEF),
    hairline: Color(0xFFE3E8EE),
    hairlineStructure: Color(0xFFA8C3DE),
    hairlineControl: Color(0xFF6594C4),
    shadowBlue: Color(0xFF003770),
    moneyIn: Color(0xFF0E6245),
    moneyInSoft: Color(0xFFCBF4C9),
    moneyOutGraphic: Color(0xFFEA2261),
    moneyOut: Color(0xFFD61452),
    magenta: Color(0xFFF96BEE),
    lemon: Color(0xFF9B6829),
    lemonInk: Color(0xFF8F6026),
  );

  final Color primary;
  final Color primaryDeep;
  final Color primaryPress;
  final Color primarySoft;
  final Color primarySubdued;
  final Color primaryWash;

  final Color brandDark;
  final Color darkSurface;
  final Color darkHairline;
  final Color darkInkMute;

  final Color ink;
  final Color inkSecondary;

  /// Chỉ đặt trên [canvas]; trên [canvasSoft] nó không đạt 4.5:1 nên dùng
  /// [inkSecondary].
  final Color inkMute;
  final Color inkMuteNav;
  final Color onPrimary;

  final Color canvas;
  final Color canvasSoft;
  final Color canvasCream;
  final Color creamWash;
  final Color rubyWash;

  /// Viền card và kẻ giữa các dòng bảng.
  final Color hairline;

  /// Đường kẻ **cấu trúc**: gạch chân header bảng, kẻ đậm mỗi 5 dòng. Không
  /// dùng cho viền phần tử tương tác — nó không đạt 3:1.
  final Color hairlineStructure;

  /// Viền của mọi phần tử **tương tác** (ô nhập, chip, badge): đủ 3:1.
  final Color hairlineControl;

  final Color shadowBlue;

  /// Tiền vào và trạng thái đã xác nhận. Không bao giờ là màu nền của nút.
  final Color moneyIn;
  final Color moneyInSoft;

  /// Hướng tiền ra ở **chỉ báo đồ hoạ** (cột biểu đồ). Chữ đỏ dùng [moneyOut].
  final Color moneyOutGraphic;

  /// Hướng tiền ra ở dạng **chữ** — biến thể tối hơn để đạt 4.5:1.
  final Color moneyOut;

  final Color magenta;
  final Color lemon;
  final Color lemonInk;

  /// Màu chữ của một số tiền theo hướng của nó.
  Color moneyColorOf({required bool isIncoming}) =>
      isIncoming ? moneyIn : moneyOut;

  @override
  LedgerColors copyWith({
    Color? primary,
    Color? primaryDeep,
    Color? primaryPress,
    Color? primarySoft,
    Color? primarySubdued,
    Color? primaryWash,
    Color? brandDark,
    Color? darkSurface,
    Color? darkHairline,
    Color? darkInkMute,
    Color? ink,
    Color? inkSecondary,
    Color? inkMute,
    Color? inkMuteNav,
    Color? onPrimary,
    Color? canvas,
    Color? canvasSoft,
    Color? canvasCream,
    Color? creamWash,
    Color? rubyWash,
    Color? hairline,
    Color? hairlineStructure,
    Color? hairlineControl,
    Color? shadowBlue,
    Color? moneyIn,
    Color? moneyInSoft,
    Color? moneyOutGraphic,
    Color? moneyOut,
    Color? magenta,
    Color? lemon,
    Color? lemonInk,
  }) => LedgerColors(
    primary: primary ?? this.primary,
    primaryDeep: primaryDeep ?? this.primaryDeep,
    primaryPress: primaryPress ?? this.primaryPress,
    primarySoft: primarySoft ?? this.primarySoft,
    primarySubdued: primarySubdued ?? this.primarySubdued,
    primaryWash: primaryWash ?? this.primaryWash,
    brandDark: brandDark ?? this.brandDark,
    darkSurface: darkSurface ?? this.darkSurface,
    darkHairline: darkHairline ?? this.darkHairline,
    darkInkMute: darkInkMute ?? this.darkInkMute,
    ink: ink ?? this.ink,
    inkSecondary: inkSecondary ?? this.inkSecondary,
    inkMute: inkMute ?? this.inkMute,
    inkMuteNav: inkMuteNav ?? this.inkMuteNav,
    onPrimary: onPrimary ?? this.onPrimary,
    canvas: canvas ?? this.canvas,
    canvasSoft: canvasSoft ?? this.canvasSoft,
    canvasCream: canvasCream ?? this.canvasCream,
    creamWash: creamWash ?? this.creamWash,
    rubyWash: rubyWash ?? this.rubyWash,
    hairline: hairline ?? this.hairline,
    hairlineStructure: hairlineStructure ?? this.hairlineStructure,
    hairlineControl: hairlineControl ?? this.hairlineControl,
    shadowBlue: shadowBlue ?? this.shadowBlue,
    moneyIn: moneyIn ?? this.moneyIn,
    moneyInSoft: moneyInSoft ?? this.moneyInSoft,
    moneyOutGraphic: moneyOutGraphic ?? this.moneyOutGraphic,
    moneyOut: moneyOut ?? this.moneyOut,
    magenta: magenta ?? this.magenta,
    lemon: lemon ?? this.lemon,
    lemonInk: lemonInk ?? this.lemonInk,
  );

  @override
  LedgerColors lerp(ThemeExtension<LedgerColors>? other, double t) {
    if (other is! LedgerColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return LedgerColors(
      primary: mix(primary, other.primary),
      primaryDeep: mix(primaryDeep, other.primaryDeep),
      primaryPress: mix(primaryPress, other.primaryPress),
      primarySoft: mix(primarySoft, other.primarySoft),
      primarySubdued: mix(primarySubdued, other.primarySubdued),
      primaryWash: mix(primaryWash, other.primaryWash),
      brandDark: mix(brandDark, other.brandDark),
      darkSurface: mix(darkSurface, other.darkSurface),
      darkHairline: mix(darkHairline, other.darkHairline),
      darkInkMute: mix(darkInkMute, other.darkInkMute),
      ink: mix(ink, other.ink),
      inkSecondary: mix(inkSecondary, other.inkSecondary),
      inkMute: mix(inkMute, other.inkMute),
      inkMuteNav: mix(inkMuteNav, other.inkMuteNav),
      onPrimary: mix(onPrimary, other.onPrimary),
      canvas: mix(canvas, other.canvas),
      canvasSoft: mix(canvasSoft, other.canvasSoft),
      canvasCream: mix(canvasCream, other.canvasCream),
      creamWash: mix(creamWash, other.creamWash),
      rubyWash: mix(rubyWash, other.rubyWash),
      hairline: mix(hairline, other.hairline),
      hairlineStructure: mix(hairlineStructure, other.hairlineStructure),
      hairlineControl: mix(hairlineControl, other.hairlineControl),
      shadowBlue: mix(shadowBlue, other.shadowBlue),
      moneyIn: mix(moneyIn, other.moneyIn),
      moneyInSoft: mix(moneyInSoft, other.moneyInSoft),
      moneyOutGraphic: mix(moneyOutGraphic, other.moneyOutGraphic),
      moneyOut: mix(moneyOut, other.moneyOut),
      magenta: mix(magenta, other.magenta),
      lemon: mix(lemon, other.lemon),
      lemonInk: mix(lemonInk, other.lemonInk),
    );
  }
}

/// Thang khoảng cách 8px với ba token phụ cho công việc tinh.
abstract final class Gap {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 64;

  /// Padding màn hình, giữ nguyên trên mọi breakpoint.
  static const double screen = 16;
}

/// Thang bo góc. `pill` là hình của mọi nút — DESIGN.md cấm thay nó bằng hình
/// chữ nhật bo góc.
abstract final class Corner {
  static const Radius xs = Radius.circular(4);
  static const Radius sm = Radius.circular(6);
  static const Radius md = Radius.circular(8);
  static const Radius lg = Radius.circular(12);
  static const Radius xl = Radius.circular(16);

  static const BorderRadius radiusXs = BorderRadius.all(xs);
  static const BorderRadius radiusSm = BorderRadius.all(sm);
  static const BorderRadius radiusMd = BorderRadius.all(md);
  static const BorderRadius radiusLg = BorderRadius.all(lg);
  static const BorderRadius radiusXl = BorderRadius.all(xl);
  static const BorderRadius pill = BorderRadius.all(Radius.circular(9999));

  static const RoundedRectangleBorder pillBorder = RoundedRectangleBorder(
    borderRadius: pill,
  );
}

/// Ba mức độ nổi của DESIGN.md. Mức 0 là **phẳng cộng viền**, không phải bóng
/// mờ, nên nó không có mặt ở đây: nó là `Border.all` trong widget.
abstract final class Elevations {
  /// Menu thả xuống, snackbar, nhóm đang chọn trong segmented control.
  static List<BoxShadow> level1(Color shadow) => <BoxShadow>[
    BoxShadow(
      color: shadow.withValues(alpha: 0.08),
      offset: const Offset(0, 1),
      blurRadius: 3,
    ),
  ];

  /// Dialog và bottom sheet.
  static List<BoxShadow> level2(Color shadow) => <BoxShadow>[
    BoxShadow(
      color: shadow.withValues(alpha: 0.08),
      offset: const Offset(0, 8),
      blurRadius: 24,
    ),
    BoxShadow(
      color: shadow.withValues(alpha: 0.04),
      offset: const Offset(0, 2),
      blurRadius: 6,
    ),
  ];
}

/// Thang chữ của DESIGN.md, dựng thành [TextStyle] dùng trực tiếp.
///
/// Không đi qua `TextTheme` của Material vì ánh xạ 16 bậc của hệ thống này vào
/// các khe có sẵn tên riêng (`displayLarge`, `bodySmall`, …) làm mất chính thứ
/// mà tên token đang nói: `bodyTabular` là "ô tiền", không phải "bodyMedium cỡ
/// 14". `TextTheme` vẫn được điền ở [LedgerTheme] để widget của Material có mặc
/// định đúng.
abstract final class LedgerText {
  /// Sohne là font thương mại; DESIGN.md chỉ định Inter làm bản thay thế. Nếu
  /// chưa có file font trong `assets/`, Flutter tự lùi về font hệ thống — thang
  /// cỡ, weight và tracking bên dưới vẫn giữ nguyên.
  static const String family = 'Inter';

  static const List<String> familyFallback = <String>[
    'SF Pro Display',
    'Roboto',
    'Segoe UI',
  ];

  /// Bộ ký tự thay thế, bật toàn cục.
  static const FontFeature ss01 = FontFeature('ss01');

  /// Chữ số cùng bề rộng, áp cho **mọi** phần tử có số, không chỉ ô tiền.
  static const FontFeature tnum = FontFeature.tabularFigures();

  static const TextStyle displayXxl = TextStyle(
    fontFamily: family,
    fontFamilyFallback: familyFallback,
    fontSize: 56,
    fontWeight: FontWeight.w300,
    height: 1.03,
    letterSpacing: -1.4,
    fontFeatures: <FontFeature>[tnum],
  );

  static const TextStyle displayXl = TextStyle(
    fontFamily: family,
    fontFamilyFallback: familyFallback,
    fontSize: 48,
    fontWeight: FontWeight.w300,
    height: 1.15,
    letterSpacing: -0.96,
    fontFeatures: <FontFeature>[tnum],
  );

  static const TextStyle displayLg = TextStyle(
    fontFamily: family,
    fontFamilyFallback: familyFallback,
    fontSize: 32,
    fontWeight: FontWeight.w300,
    height: 1.1,
    letterSpacing: -0.64,
    fontFeatures: <FontFeature>[tnum],
  );

  static const TextStyle displayMd = TextStyle(
    fontFamily: family,
    fontFamilyFallback: familyFallback,
    fontSize: 26,
    fontWeight: FontWeight.w300,
    height: 1.12,
    letterSpacing: -0.26,
    fontFeatures: <FontFeature>[ss01],
  );

  static const TextStyle headingLg = TextStyle(
    fontFamily: family,
    fontFamilyFallback: familyFallback,
    fontSize: 22,
    fontWeight: FontWeight.w400,
    height: 1.2,
    letterSpacing: -0.22,
    fontFeatures: <FontFeature>[ss01],
  );

  static const TextStyle headingMd = TextStyle(
    fontFamily: family,
    fontFamilyFallback: familyFallback,
    fontSize: 20,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: -0.2,
    fontFeatures: <FontFeature>[ss01],
  );

  static const TextStyle headingSm = TextStyle(
    fontFamily: family,
    fontFamilyFallback: familyFallback,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 1.4,
    fontFeatures: <FontFeature>[ss01],
  );

  static const TextStyle bodyLg = TextStyle(
    fontFamily: family,
    fontFamilyFallback: familyFallback,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    fontFeatures: <FontFeature>[ss01],
  );

  static const TextStyle bodyMd = TextStyle(
    fontFamily: family,
    fontFamilyFallback: familyFallback,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
    fontFeatures: <FontFeature>[ss01],
  );

  static const TextStyle bodySm = TextStyle(
    fontFamily: family,
    fontFamilyFallback: familyFallback,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.45,
    fontFeatures: <FontFeature>[ss01],
  );

  /// Ô tiền: nặng hơn chữ xung quanh một bậc, vì nó là thứ mắt tìm.
  static const TextStyle bodyTabular = TextStyle(
    fontFamily: family,
    fontFamilyFallback: familyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.45,
    letterSpacing: -0.42,
    fontFeatures: <FontFeature>[tnum],
  );

  /// Số đo lớn ở màn Diagnostics.
  static const TextStyle tabularLg = TextStyle(
    fontFamily: family,
    fontFamilyFallback: familyFallback,
    fontSize: 26,
    fontWeight: FontWeight.w400,
    height: 1.15,
    letterSpacing: -0.5,
    fontFeatures: <FontFeature>[tnum],
  );

  static const TextStyle buttonMd = TextStyle(
    fontFamily: family,
    fontFamilyFallback: familyFallback,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1,
    fontFeatures: <FontFeature>[ss01],
  );

  static const TextStyle buttonSm = TextStyle(
    fontFamily: family,
    fontFamilyFallback: familyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1,
    fontFeatures: <FontFeature>[ss01],
  );

  /// Helper, ngày, số tài khoản.
  static const TextStyle caption = TextStyle(
    fontFamily: family,
    fontFamilyFallback: familyFallback,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: -0.39,
    fontFeatures: <FontFeature>[tnum],
  );

  static const TextStyle micro = TextStyle(
    fontFamily: family,
    fontFamilyFallback: familyFallback,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    fontFeatures: <FontFeature>[ss01],
  );

  /// Header cột, nhãn pill, nhãn nav. Sàn cỡ chữ của hệ thống, và chỉ dùng ở
  /// dạng viết hoa.
  static const TextStyle microCap = TextStyle(
    fontFamily: family,
    fontFamilyFallback: familyFallback,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: 0.3,
    fontFeatures: <FontFeature>[ss01],
  );

  static const TextStyle monoLog = TextStyle(
    fontFamily: 'JetBrains Mono',
    fontFamilyFallback: <String>['Consolas', 'Menlo', 'monospace'],
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.55,
    fontFeatures: <FontFeature>[FontFeature.slashedZero()],
  );
}

/// Dựng [ThemeData] từ các token bên trên.
abstract final class LedgerTheme {
  static ThemeData light({bool compactDensity = false}) {
    const colors = LedgerColors.light;
    final scheme = ColorScheme.fromSeed(seedColor: colors.primary).copyWith(
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      surface: colors.canvas,
      onSurface: colors.ink,
      error: colors.moneyOut,
      outline: colors.hairlineControl,
      outlineVariant: colors.hairline,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: const <ThemeExtension<dynamic>>[colors],
      scaffoldBackgroundColor: colors.canvas,
      canvasColor: colors.canvas,
      dividerColor: colors.hairline,
      fontFamily: LedgerText.family,
      fontFamilyFallback: LedgerText.familyFallback,

      // Density theo **tác vụ**, không theo kích thước màn: web là nơi nhập
      // hàng loạt và so sánh nên cần nhiều dòng cùng lúc.
      visualDensity: compactDensity
          ? VisualDensity.compact
          : VisualDensity.standard,

      textTheme: _textTheme(colors),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.canvas,
        foregroundColor: colors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: LedgerText.headingSm.copyWith(color: colors.ink),
        shape: Border(bottom: BorderSide(color: colors.hairline)),
      ),
      dividerTheme: DividerThemeData(
        color: colors.hairline,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: colors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Corner.radiusMd,
          side: BorderSide(color: colors.hairline),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: Corner.radiusLg),
        titleTextStyle: LedgerText.headingLg.copyWith(color: colors.ink),
        contentTextStyle: LedgerText.bodyLg.copyWith(
          color: colors.inkSecondary,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: colors.hairline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Corner.xl),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.ink,
        contentTextStyle: LedgerText.bodySm.copyWith(color: colors.onPrimary),
        actionTextColor: colors.primarySubdued,
        behavior: SnackBarBehavior.floating,
        elevation: 1,
        shape: const RoundedRectangleBorder(borderRadius: Corner.radiusMd),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.canvas,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.sm,
        ),
        hintStyle: LedgerText.bodyMd.copyWith(color: colors.inkMute),
        labelStyle: LedgerText.bodyMd.copyWith(color: colors.inkSecondary),
        helperStyle: LedgerText.caption.copyWith(color: colors.inkMute),
        errorStyle: LedgerText.caption.copyWith(color: colors.moneyOut),
        border: _inputBorder(colors.hairlineControl),
        enabledBorder: _inputBorder(colors.hairlineControl),
        focusedBorder: _inputBorder(colors.primary),
        errorBorder: _inputBorder(colors.moneyOut),
        focusedErrorBorder: _inputBorder(colors.moneyOut),
        disabledBorder: _inputBorder(colors.hairline),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colors.primarySubdued;
            }
            if (states.contains(WidgetState.pressed)) {
              return colors.primaryPress;
            }
            return colors.primary;
          }),
          foregroundColor: WidgetStatePropertyAll<Color>(colors.onPrimary),
          textStyle: const WidgetStatePropertyAll<TextStyle>(
            LedgerText.buttonMd,
          ),
          padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
          ),
          shape: const WidgetStatePropertyAll<OutlinedBorder>(
            Corner.pillBorder,
          ),
          elevation: const WidgetStatePropertyAll<double>(0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll<Color>(colors.canvas),
          foregroundColor: WidgetStatePropertyAll<Color>(colors.primary),
          side: WidgetStatePropertyAll<BorderSide>(
            BorderSide(color: colors.primary),
          ),
          textStyle: const WidgetStatePropertyAll<TextStyle>(
            LedgerText.buttonMd,
          ),
          padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
          ),
          shape: const WidgetStatePropertyAll<OutlinedBorder>(
            Corner.pillBorder,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll<Color>(colors.primary),
          textStyle: const WidgetStatePropertyAll<TextStyle>(
            LedgerText.buttonSm,
          ),
          shape: const WidgetStatePropertyAll<OutlinedBorder>(
            Corner.pillBorder,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll<Color>(colors.inkSecondary),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll<Color>(colors.canvas),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? colors.primary
              : colors.hairlineStructure;
        }),
        trackOutlineColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? colors.primary
              : colors.canvas;
        }),
        checkColor: WidgetStatePropertyAll<Color>(colors.onPrimary),
        side: BorderSide(color: colors.hairlineControl),
        shape: const RoundedRectangleBorder(borderRadius: Corner.radiusXs),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.hairline,
        linearMinHeight: 4,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.ink,
          borderRadius: Corner.radiusMd,
        ),
        textStyle: LedgerText.bodySm.copyWith(color: colors.onPrimary),
      ),
      // Không có hiệu ứng gợn sóng lan rộng: DESIGN.md cấm chuyển động trang trí
      // và màn hình chính cuộn qua hàng nghìn dòng.
      splashFactory: NoSplash.splashFactory,
      highlightColor: colors.primaryWash,
    );
  }

  /// Bảng màu tối, chỉ bọc riêng màn Developer Diagnostics.
  static ThemeData diagnostics(ThemeData base) {
    const colors = LedgerColors.light;
    return base.copyWith(
      scaffoldBackgroundColor: colors.brandDark,
      canvasColor: colors.brandDark,
      textTheme: base.textTheme.apply(
        bodyColor: colors.onPrimary,
        displayColor: colors.onPrimary,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: colors.brandDark,
        foregroundColor: colors.onPrimary,
        titleTextStyle: LedgerText.headingSm.copyWith(color: colors.onPrimary),
        shape: Border(bottom: BorderSide(color: colors.darkHairline)),
      ),
      dividerColor: colors.darkHairline,
    );
  }

  static OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
    borderRadius: Corner.radiusSm,
    borderSide: BorderSide(color: color),
  );

  static TextTheme _textTheme(LedgerColors colors) => TextTheme(
    displayLarge: LedgerText.displayXxl.copyWith(color: colors.ink),
    displayMedium: LedgerText.displayXl.copyWith(color: colors.ink),
    displaySmall: LedgerText.displayLg.copyWith(color: colors.ink),
    headlineLarge: LedgerText.displayMd.copyWith(color: colors.ink),
    headlineMedium: LedgerText.headingLg.copyWith(color: colors.ink),
    headlineSmall: LedgerText.headingMd.copyWith(color: colors.ink),
    titleLarge: LedgerText.headingSm.copyWith(color: colors.ink),
    titleMedium: LedgerText.bodyLg.copyWith(color: colors.ink),
    titleSmall: LedgerText.bodyMd.copyWith(color: colors.inkSecondary),
    bodyLarge: LedgerText.bodyLg.copyWith(color: colors.ink),
    bodyMedium: LedgerText.bodyMd.copyWith(color: colors.ink),
    bodySmall: LedgerText.bodySm.copyWith(color: colors.inkSecondary),
    labelLarge: LedgerText.buttonMd.copyWith(color: colors.ink),
    labelMedium: LedgerText.micro.copyWith(color: colors.inkSecondary),
    labelSmall: LedgerText.microCap.copyWith(color: colors.inkSecondary),
  );
}

/// Truy cập ngắn tới bảng màu nghiệp vụ.
extension LedgerThemeContext on BuildContext {
  /// Bảng màu nghiệp vụ đang áp dụng.
  ///
  /// Lùi về [LedgerColors.light] thay vì ném khi extension chưa được cài: một
  /// widget dựng trong test tiện ích không nên chết chỉ vì thiếu theme.
  LedgerColors get ledger =>
      Theme.of(this).extension<LedgerColors>() ?? LedgerColors.light;
}
