import 'package:flutter/material.dart';

ThemeData buildAppTheme(Color primaryColor) {
  final hsl = HSLColor.fromColor(primaryColor);
  final darkColor = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
  final lightColor = hsl.withLightness((hsl.lightness + 0.35).clamp(0.0, 1.0)).toColor();

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      secondary: darkColor,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: primaryColor, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      labelStyle: TextStyle(color: primaryColor),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.all(primaryColor),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: Colors.white,
    ),
  );
}
