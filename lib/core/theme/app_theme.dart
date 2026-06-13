import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/cupertino.dart';

// ══════════════════════════════════════════
//  WAFRA — Design Tokens
// ══════════════════════════════════════════

class WaColors {
  WaColors._();
  static const Color gold          = Color(0xFFC9A84C);
  static const Color goldLight     = Color(0xFFE8C97A);
  static const Color goldDim       = Color(0xFF8A6E2E);
  static const Color obsidian      = Color(0xFF0A0A0F);
  static const Color obsidian2     = Color(0xFF12121A);
  static const Color obsidian3     = Color(0xFF1A1A26);
  static const Color obsidian4     = Color(0xFF222234);
  static const Color cream         = Color(0xFFF5F3EE);
  static const Color creamWhite    = Color(0xFFFFFFFF);
  static const Color creamLight    = Color(0xFFF0EDE6);
  static const Color success       = Color(0xFF4CAF82);
  static const Color danger        = Color(0xFFE05C5C);
  static const Color info          = Color(0xFF6B9FD4);
  static const Color warning       = Color(0xFFE8A040);
  static const Color textPrimary   = Color(0xFFF0EAD6);
  static const Color textSecondary = Color(0xFF9B9080);
  static const Color textMuted     = Color(0xFF5A5450);
  static const Color textPrimaryL  = Color(0xFF1A1410);
  static const Color textSecL      = Color(0xFF6B5F4E);
  static const Color border        = Color(0x2DC9A84C);

  static const Map<String, Color> catColors = {
    'food'         : Color(0xFFE8956D),
    'transport'    : Color(0xFF6BAED4),
    'health'       : Color(0xFF79C88A),
    'bills'        : Color(0xFFE87A7A),
    'entertainment': Color(0xFFB58FDB),
    'shopping'     : Color(0xFFE8C87A),
    'education'    : Color(0xFF7AB8E8),
    'family'       : Color(0xFFF0A070),
    'salary'       : Color(0xFF79C88A),
    'business'     : Color(0xFFC9A84C),
    'investment'   : Color(0xFF6BAED4),
    'rental'       : Color(0xFFD4A06B),
    'other_income' : Color(0xFFB58FDB),
  };
  static Color catColor(String id) => catColors[id] ?? const Color(0xFF888888);
}

// ══════════════════════════════════════════
//  خطوط الأرقام — الحل الصحيح بدون monospace
//  monospace لا تدعم العربية جيداً
//  نستخدم Tajawal للأرقام أيضاً مع tabular figures
// ══════════════════════════════════════════
class WaFonts {
  WaFonts._();

  // خط الشعار والأرقام الكبيرة
  static TextStyle playfair({
    double fontSize = 32,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
  }) => GoogleFonts.playfairDisplay(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
  );

  // خط الأرقام المالية — Tajawal مع tabular figures
  static TextStyle amount({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
  }) => GoogleFonts.tajawal(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    // tabular figures: الأرقام بعرض ثابت لمحاذاة الأعمدة
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

class WaTheme {
  WaTheme._();
  static ThemeData dark()  => _build(true);
  static ThemeData light() => _build(false);

  static ThemeData _build(bool isDark) {
    final bg     = isDark ? WaColors.obsidian  : WaColors.cream;
    final surf   = isDark ? WaColors.obsidian2 : WaColors.creamWhite;
    final onSurf = isDark ? WaColors.textPrimary : WaColors.textPrimaryL;

    return ThemeData(
      useMaterial3           : true,
      brightness             : isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness : isDark ? Brightness.dark : Brightness.light,
        primary    : WaColors.gold,    onPrimary : WaColors.obsidian,
        secondary  : WaColors.goldDim, onSecondary: WaColors.obsidian,
        error      : WaColors.danger,  onError   : Colors.white,
        surface    : surf,             onSurface : onSurf,
      ),

      // ── خط Tajawal العربي لكل النصوص ────────
      textTheme: GoogleFonts.tajawalTextTheme().copyWith(
        displayLarge  : GoogleFonts.tajawal(fontSize:32, fontWeight:FontWeight.w700, color:onSurf),
        headlineMedium: GoogleFonts.tajawal(fontSize:20, fontWeight:FontWeight.w700, color:onSurf),
        headlineSmall : GoogleFonts.tajawal(fontSize:17, fontWeight:FontWeight.w600, color:onSurf),
        titleLarge    : GoogleFonts.tajawal(fontSize:16, fontWeight:FontWeight.w600, color:onSurf),
        titleMedium   : GoogleFonts.tajawal(fontSize:14, fontWeight:FontWeight.w500, color:onSurf),
        bodyLarge     : GoogleFonts.tajawal(fontSize:15, color:onSurf),
        bodyMedium    : GoogleFonts.tajawal(fontSize:14, color:onSurf),
        bodySmall     : GoogleFonts.tajawal(fontSize:12,
            color: isDark ? WaColors.textSecondary : WaColors.textSecL),
        labelSmall    : GoogleFonts.tajawal(fontSize:10, letterSpacing:1.2,
            color: isDark ? WaColors.textMuted : const Color(0xFFA09484)),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor : surf,
        elevation       : 0,
        centerTitle     : true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle  : GoogleFonts.tajawal(
            fontSize:17, fontWeight:FontWeight.w700, color:onSurf),
        iconTheme: const IconThemeData(color: WaColors.gold),
      ),
      cardTheme: CardThemeData(
        color    : surf, elevation: 0,
        shape    : RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: WaColors.border)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled      : true,
        fillColor   : isDark ? WaColors.obsidian3 : WaColors.creamLight,
        border      : OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: WaColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: WaColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: WaColors.goldDim, width:1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: WaColors.danger)),
        contentPadding: const EdgeInsets.symmetric(horizontal:16, vertical:13),
        hintStyle: GoogleFonts.tajawal(
            color: isDark ? WaColors.textMuted : const Color(0xFFA09484),
            fontSize:14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: WaColors.gold,
          foregroundColor: WaColors.obsidian,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical:13, horizontal:24),
          textStyle: GoogleFonts.tajawal(fontSize:14, fontWeight:FontWeight.w700),
        ),
      ),
      dividerTheme: const DividerThemeData(color: WaColors.border, thickness:1, space:1),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor    : surf,
        selectedItemColor  : WaColors.gold,
        unselectedItemColor: WaColors.textMuted,
        type : BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        // خط عربي في الـ dialogs
        titleTextStyle  : GoogleFonts.tajawal(
            fontSize:16, fontWeight:FontWeight.w700, color:onSurf),
        contentTextStyle: GoogleFonts.tajawal(fontSize:14, color:onSurf),
      ),
      // ── Cupertino (iOS-style widgets) ─────────
      cupertinoOverrideTheme: NoDefaultCupertinoThemeData(
        primaryColor: WaColors.gold,
        textTheme: CupertinoTextThemeData(
          textStyle: GoogleFonts.tajawal(color: onSurf),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: const ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS    : const ZoomPageTransitionsBuilder(),
      }),
    );
  }
}
