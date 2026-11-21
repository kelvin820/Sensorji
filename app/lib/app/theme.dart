import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../logic/season.dart';

/// 色票（BUILD_PLAN 第 0 節）。
abstract final class Palette {
  static const paper = Color(0xFFF1EADC); // 土白底
  static const card = Color(0xFFFBF6EC);
  static const line = Color(0xFFD8C9AE); // 只當裝飾線（對底色 1.4:1）
  static const ink = Color(0xFF2A221C);
  static const inkSoft = Color(0xFF6B5D4C); // 也用在互動元件邊框（≥3:1）
  static const vermilion = Color(0xFFB5321F);
  static const vermilionDeep = Color(0xFF7E1F12);
  static const gold = Color(0xFF8A5A1E);

  // 冬夜配色
  static const nightText = Color(0xFFF6EEDD);
  static const nightTextSoft = Color(0xFFC9BFAE);
}

/// 依季節決定疊在背景上的漸層與文字色。卡片、輸入框、籤紙一律維持米白底深色字。
class SeasonLook {
  const SeasonLook._(this.overlay, this.text, this.textSoft);

  final List<Color> overlay;
  final Color text;
  final Color textSoft;

  static SeasonLook of(Season s) => s.isNight ? night : day;

  static const day = SeasonLook._(
    [Color(0x00F1EADC), Color(0xCCF1EADC), Color(0xF2F1EADC)],
    Palette.ink,
    Palette.inkSoft,
  );

  static const night = SeasonLook._(
    [Color(0x8C14182C), Color(0xB314182C), Color(0xD914182C)], // rgba(20,24,44,0.55→0.85)
    Palette.nightText,
    Palette.nightTextSoft,
  );
}

/// 測試時關掉 Google Fonts（避免連網），改用系統字型。
bool useGoogleFonts = true;

TextStyle serif(TextStyle base) => useGoogleFonts ? GoogleFonts.notoSerifTc(textStyle: base) : base;
TextStyle sans(TextStyle base) => useGoogleFonts ? GoogleFonts.notoSansTc(textStyle: base) : base;

ThemeData buildTheme() {
  const scheme = ColorScheme.light(
    primary: Palette.vermilion,
    onPrimary: Colors.white,
    secondary: Palette.gold,
    surface: Palette.card,
    onSurface: Palette.ink,
    outline: Palette.inkSoft,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final t = base.textTheme.apply(bodyColor: Palette.ink, displayColor: Palette.ink);
  final text = t.copyWith(
    displaySmall: serif(t.displaySmall!.copyWith(fontWeight: FontWeight.w700)),
    headlineMedium: serif(t.headlineMedium!.copyWith(fontWeight: FontWeight.w700)),
    headlineSmall: serif(t.headlineSmall!.copyWith(fontWeight: FontWeight.w700)),
    titleLarge: serif(t.titleLarge!.copyWith(fontWeight: FontWeight.w700)),
    titleMedium: serif(t.titleMedium!.copyWith(fontWeight: FontWeight.w600)),
    bodyLarge: sans(t.bodyLarge!.copyWith(height: 1.7)),
    bodyMedium: sans(t.bodyMedium!.copyWith(height: 1.6)),
    bodySmall: sans(t.bodySmall!),
    labelLarge: sans(t.labelLarge!.copyWith(fontWeight: FontWeight.w600, letterSpacing: 1)),
  );

  return base.copyWith(
    scaffoldBackgroundColor: Palette.paper,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      // 不設 titleTextStyle：預設會用 textTheme.titleLarge 並套上 foregroundColor，
      // 冬夜畫面傳入淺色 foregroundColor 時標題才會跟著變色。
      foregroundColor: Palette.ink,
      centerTitle: true,
    ),
    cardTheme: const CardThemeData(
      color: Palette.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        side: BorderSide(color: Palette.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.vermilion,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 52),
        textStyle: text.labelLarge?.copyWith(fontSize: 17),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(26))),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.ink,
        backgroundColor: Palette.card,
        minimumSize: const Size(64, 48),
        side: const BorderSide(color: Palette.inkSoft),
        textStyle: text.labelLarge,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Palette.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Palette.inkSoft),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Palette.inkSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Palette.vermilion, width: 2),
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: Palette.card,
      selectedColor: Color(0xFFF3D9CF),
      side: BorderSide(color: Palette.inkSoft),
      labelStyle: TextStyle(color: Palette.ink),
    ),
  );
}
