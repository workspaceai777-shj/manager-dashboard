import 'package:flutter/material.dart';

/// Mobile-first dark glass design tokens for Ontario TaskLog.
class TaskLogStyle {
  static const ink = Color(0xFFF5F8FF);
  static const navy = Color(0xFF0B1427);
  static const teal = Color(0xFF34D5C0);
  static const canvas = Color(0xFF080F1F);
  static const muted = Color(0xFFA5B4CC);
  static const surface = Color(0xFF14223A);
  static const border = Color(0xFF34445D);

  static BoxDecoration get glass => BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1F3450), Color(0xFF111C32)],
    ),
    border: Border.all(color: const Color(0xFF3B516F), width: 0.8),
    borderRadius: BorderRadius.circular(20),
    boxShadow: const [
      BoxShadow(color: Color(0x32000000), blurRadius: 22, offset: Offset(0, 12)),
    ],
  );

  static ThemeData get light => dark;
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: teal,
      brightness: Brightness.dark,
      surface: surface,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      fontFamily: 'Roboto',
      textTheme: ThemeData.dark().textTheme.apply(bodyColor: ink, displayColor: ink),
      appBarTheme: const AppBarTheme(
        backgroundColor: navy,
        foregroundColor: ink,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ink),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border, width: 0.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: teal,
          foregroundColor: const Color(0xFF061425),
          minimumSize: const Size(120, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF17263D),
        labelStyle: const TextStyle(color: muted),
        hintStyle: const TextStyle(color: muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: teal, width: 1.6),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: navy,
        indicatorColor: Color(0xFF1C4B5F),
        selectedIconTheme: IconThemeData(color: teal),
        unselectedIconTheme: IconThemeData(color: muted),
        selectedLabelTextStyle: TextStyle(color: ink, fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: TextStyle(color: muted),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navy,
        indicatorColor: const Color(0xFF1C4B5F),
        labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11, color: ink)),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? teal : muted,
        )),
      ),
      dividerColor: border,
    );
  }
}
