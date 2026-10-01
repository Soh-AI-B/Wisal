import 'package:flutter/material.dart';

// Exact tokens from the supplied design system (reconnect_app/assets/design system.png).
const wisalPrimary = Color(0xFF2E7D32);
const wisalPrimaryLight = Color(0xFFE8F5E9);
const wisalSecondary = Color(0xFFF4A261);
const wisalWarning = Color(0xFFE76F51);
const wisalTextPrimary = Color(0xFF1F2937);
const wisalTextSecondary = Color(0xFF687280);
const wisalBorder = Color(0xFFE5E7EB);
const wisalBackground = Color(0xFFFAFAF7);
const kinPurple = Color(0xFF6B4FA0);
const kinPurpleBg = Color(0xFFEDE7F9);

/// Kept as `kinGold` for call-site compatibility with earlier code; now maps to the kin palette.
const kinGold = kinPurple;

ThemeData wisalTheme(Brightness b, bool ar) {
  final dark = b == Brightness.dark;
  final cs = ColorScheme.fromSeed(
    seedColor: wisalPrimary,
    brightness: b,
    primary: dark ? null : wisalPrimary,
    onPrimary: dark ? null : Colors.white,
    surface: dark ? null : wisalBackground,
    onSurface: dark ? null : wisalTextPrimary,
    onSurfaceVariant: dark ? null : wisalTextSecondary,
    outline: dark ? null : wisalBorder,
    error: dark ? null : wisalWarning,
  );
  final fontFamily = ar ? 'Tajawal' : 'Inter';

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: cs.surface,
    textTheme: TextTheme(
      headlineSmall: TextStyle(fontFamily: fontFamily, fontSize: 24, fontWeight: FontWeight.bold, color: cs.onSurface),
      titleLarge: TextStyle(fontFamily: fontFamily, fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface),
      titleMedium: TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface),
      bodyLarge: TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.normal, color: cs.onSurface),
      bodyMedium: TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.normal, color: cs.onSurface),
      bodySmall: TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.normal, color: cs.onSurfaceVariant),
      labelLarge: TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w500, color: cs.onSurface),
      labelSmall: TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.normal, color: cs.onSurfaceVariant),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 22, fontWeight: FontWeight.w700, color: cs.onSurface),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: cs.primaryContainer,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: wisalPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w500),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: wisalPrimary,
        side: const BorderSide(color: wisalPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w500),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    dividerTheme: const DividerThemeData(color: wisalBorder, space: 1),
  );
}

/// Consistent 4/8/12/16/24/32 spacing scale used across the redesigned screens.
class WSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}
