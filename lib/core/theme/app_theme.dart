import 'package:flutter/material.dart';

class AppTheme {
  // Dark navy blue theme (like the screenshot)
  static const Color primary = Color(0xFF1A237E);       // deep blue
  static const Color primaryLight = Color(0xFF4361EE);  // electric blue
  static const Color accent = Color(0xFF4ADE80);        // light green
  static const Color surface = Color(0xFF080E2A);       // very dark navy
  static const Color cardBg = Color(0xFF101840);        // dark navy card
  static const Color cardBg2 = Color(0xFF1A2560);       // slightly lighter card
  static const Color cardGlow = Color(0xFF253580);      // card with glow
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8899CC);
  static const Color divider = Color(0xFF1E2D6B);
  static const Color red = Color(0xFFE53935);
  static const Color liveRed = Color(0xFFFF1744);
  static const Color green = Color(0xFF00E676);
  static const Color supportGreen = Color(0xFF43A047);
  static const Color supportGreenDark = Color(0xFF2E7D32);

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.transparent,
    primaryColor: primaryLight,
    colorScheme: const ColorScheme.dark(
      primary: primaryLight,
      secondary: accent,
      surface: cardBg,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      foregroundColor: textPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    ),
    cardTheme: CardThemeData(
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryLight,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        elevation: 4,
        shadowColor: Color(0x664361EE),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryLight,
        side: const BorderSide(color: primaryLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardBg2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryLight, width: 1.5),
      ),
      hintStyle: const TextStyle(color: textSecondary),
      labelStyle: const TextStyle(color: textSecondary),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: cardBg,
      selectedItemColor: accent,
      unselectedItemColor: textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    dividerTheme: const DividerThemeData(color: divider, thickness: 1),
    chipTheme: ChipThemeData(
      backgroundColor: cardBg2,
      selectedColor: primaryLight,
      labelStyle: const TextStyle(color: textPrimary, fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
    ),
    tabBarTheme: const TabBarThemeData(
      indicatorColor: accent,
      labelColor: accent,
      unselectedLabelColor: textSecondary,
      indicatorSize: TabBarIndicatorSize.label,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 28),
      headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 22),
      titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
      titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
      bodyLarge: TextStyle(color: textPrimary, fontSize: 15),
      bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
      labelLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
    ),
  );

  // Gradient helpers
  static const LinearGradient navyGradient = LinearGradient(
    colors: [Color(0xFF1A2560), Color(0xFF101840)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient blueGradient = LinearGradient(
    colors: [Color(0xFF4361EE), Color(0xFF1A237E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient liveGradient = LinearGradient(
    colors: [Color(0xFFFF1744), Color(0xFFB71C1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
