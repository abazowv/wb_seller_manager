import 'package:flutter/material.dart';

/// Фирменный цвет в духе Wildberries.
const brandColor = Color(0xFF8B1FA9);
const profitColor = Color(0xFF2E9D5B);
const lossColor = Color(0xFFD64545);
const warningColor = Color(0xFFE08A00);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: brandColor, brightness: brightness);
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: brightness);
  return base.copyWith(
    scaffoldBackgroundColor: brightness == Brightness.light ? const Color(0xFFF7F5FA) : scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLowest,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      indicatorColor: scheme.primaryContainer,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
