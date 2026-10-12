import 'package:flutter/material.dart';

class AppColors {
  static const forest = Color(0xFF1F4B3F);
  static const forestDark = Color(0xFF153730);
  static const gold = Color(0xFFC99A2E);
  static const goldLight = Color(0xFFE8C976);
  static const paper = Color(0xFFEEF2E9);
  static const paperCard = Color(0xFFFFFFFF);
  static const brick = Color(0xFF8C3A2B);
  static const success = Color(0xFF3F7D58);
  static const ink = Color(0xFF202320);
  static const muted = Color(0xFF6B7268);
}

final ThemeData appTheme = ThemeData(
  scaffoldBackgroundColor: AppColors.paper,
  fontFamily: 'System',
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.forest,
    primary: AppColors.forest,
    secondary: AppColors.gold,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.forest,
      foregroundColor: AppColors.paper,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.forestDark,
      side: BorderSide(color: AppColors.forest.withOpacity(0.3)),
      padding: const EdgeInsets.symmetric(vertical: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),
);