import 'package:flutter/material.dart';
import 'app_title.dart';

/// Blue surfaces and yellow accents, with pale body text for long guide entries.
ThemeData buildCaminoTheme() {
  const surface = Color(0xFF123C69);
  final colors =
      ColorScheme.fromSeed(
        seedColor: caminoYellow,
        brightness: Brightness.dark,
      ).copyWith(
        primary: caminoYellow,
        onPrimary: Color(0xFF102F50),
        primaryContainer: caminoBlue,
        onPrimaryContainer: caminoYellow,
        secondary: Color(0xFFFFE88A),
        onSecondary: Color(0xFF102F50),
        secondaryContainer: Color(0xFF204F80),
        onSecondaryContainer: Color(0xFFFFE88A),
        surface: surface,
        onSurface: Color(0xFFF5F7FC),
        onSurfaceVariant: Color(0xFFD5E2F2),
        surfaceContainerLowest: Color(0xFF0C2948),
        surfaceContainerLow: Color(0xFF153F6C),
        surfaceContainer: Color(0xFF194776),
        surfaceContainerHigh: Color(0xFF205184),
        surfaceContainerHighest: Color(0xFF285C90),
        outline: Color(0xFF9DB5D0),
        outlineVariant: Color(0xFF52769D),
        surfaceTint: Colors.transparent,
      );
  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: surface,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: caminoBlue,
      foregroundColor: caminoYellow,
      surfaceTintColor: Colors.transparent,
    ),
    iconTheme: const IconThemeData(color: caminoYellow),
    listTileTheme: const ListTileThemeData(iconColor: caminoYellow),
  );
  return theme.copyWith(
    textTheme: theme.textTheme.copyWith(
      headlineLarge: theme.textTheme.headlineLarge?.copyWith(
        color: caminoYellow,
      ),
      headlineMedium: theme.textTheme.headlineMedium?.copyWith(
        color: caminoYellow,
      ),
      headlineSmall: theme.textTheme.headlineSmall?.copyWith(
        color: caminoYellow,
      ),
      titleLarge: theme.textTheme.titleLarge?.copyWith(color: caminoYellow),
    ),
  );
}
