import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF136F63)),
      useMaterial3: true,
      fontFamily: 'Arial',
    );

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF7F9FB),
      appBarTheme: const AppBarTheme(centerTitle: false),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    );
  }
}
