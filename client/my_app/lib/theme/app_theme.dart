import 'package:flutter/material.dart';

class AppTheme {
  static const Color ink = Color(0xFF17324D);
  static const Color inkMuted = Color(0xFF5A7085);
  static const Color canvas = Color(0xFFF5EFE6);
  static const Color mist = Color(0xFFE8EEF4);
  static const Color panel = Color(0xFFFFFCF7);
  static const Color border = Color(0xFFD8D6CF);
  static const Color accent = Color(0xFFE4774C);
  static const Color accentDeep = Color(0xFFC85D38);
  static const Color mint = Color(0xFF2B9D8F);
  static const Color gold = Color(0xFFF0B454);
  static const Color danger = Color(0xFFCC5A4B);

  static const LinearGradient pageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF8F2E8),
      Color(0xFFEAF0F5),
      Color(0xFFFBE4D7),
    ],
  );

  static List<BoxShadow> get softShadow => const [
        BoxShadow(
          color: Color(0x1417324D),
          blurRadius: 30,
          offset: Offset(0, 14),
        ),
      ];

  static const List<String> _fontFallback = [
    'Microsoft YaHei',
    'PingFang SC',
    'Hiragino Sans GB',
    'Noto Sans CJK SC',
    'Source Han Sans SC',
    'WenQuanYi Micro Hei',
    'Arial',
    'sans-serif',
  ];

  static TextStyle _textStyle({
    required double fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) {
    return TextStyle(
      fontFamilyFallback: _fontFallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ink,
        brightness: Brightness.light,
      ).copyWith(
        primary: ink,
        secondary: accent,
        tertiary: mint,
        surface: panel,
        error: danger,
      ),
    );

    final textTheme = base.textTheme.copyWith(
      headlineLarge: _textStyle(
        fontSize: 42,
        fontWeight: FontWeight.w700,
        color: ink,
        height: 1.08,
      ),
      headlineMedium: _textStyle(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleLarge: _textStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleMedium: _textStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      bodyLarge: _textStyle(
        fontSize: 15,
        color: ink,
        height: 1.5,
      ),
      bodyMedium: _textStyle(
        fontSize: 13,
        color: inkMuted,
        height: 1.45,
      ),
      labelLarge: _textStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );

    final roundedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: const BorderSide(color: border),
    );

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: Colors.transparent,
      dividerColor: border,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: const IconThemeData(color: ink),
      ),
      cardTheme: CardTheme(
        color: panel.withOpacity(0.94),
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: border.withOpacity(0.6)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white.withOpacity(0.88),
        selectedColor: ink.withOpacity(0.12),
        side: BorderSide(color: border.withOpacity(0.8)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        labelStyle: textTheme.bodyMedium?.copyWith(color: ink),
        secondaryLabelStyle: textTheme.bodyMedium?.copyWith(color: ink),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: ink.withOpacity(0.12),
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(
            color: ink,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.9),
        hintStyle: textTheme.bodyMedium,
        labelStyle: textTheme.bodyMedium?.copyWith(color: inkMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: roundedBorder,
        enabledBorder: roundedBorder,
        focusedBorder: roundedBorder.copyWith(
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: roundedBorder.copyWith(
          borderSide: const BorderSide(color: danger, width: 1.5),
        ),
        focusedErrorBorder: roundedBorder.copyWith(
          borderSide: const BorderSide(color: danger, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: ink,
          disabledBackgroundColor: ink.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          textStyle: textTheme.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
    );
  }
}
