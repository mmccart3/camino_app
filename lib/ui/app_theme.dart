import 'package:flutter/material.dart';
import 'app_title.dart';

// Brand colors
const Color caminoNavyBase = caminoBlue; // Deep trail night background
const Color caminoSurface = Color(0xFF132B45); // Level 1 card surface
const Color caminoSurfaceHigh = Color(0xFF1B3857); // Level 2 elevated elements
const Color caminoSurfaceBorder = Color(0xFF284D73); // Subtle card border
const Color caminoAmber = caminoYellow; // Refined waypoint gold accent
const Color caminoAmberSubtle = Color(
  0xFFF9E8C7,
); // Highlight text on dark accents

ThemeData buildCaminoTheme() {
  final colorScheme = ColorScheme(
    brightness: Brightness.dark,
    // Primary interactive focal points (CTAs, key markers)
    primary: caminoAmber,
    onPrimary: const Color(0xFF1B1800),
    primaryContainer: const Color(0xFF4A3700),
    onPrimaryContainer: caminoAmberSubtle,

    // Secondary navigation / subtle badges
    secondary: const Color(0xFF64B5F6),
    onSecondary: const Color(0xFF003258),
    secondaryContainer: const Color(0xFF183D63),
    onSecondaryContainer: const Color(0xFFD1E4FF),

    // Surface & background tonal hierarchy
    surface: caminoNavyBase,
    onSurface: const Color(0xFFF1F5F9), // High readability off-white
    onSurfaceVariant: const Color(0xFFCBD5E1), // Muted slate for captions/dates
    surfaceContainerLowest: const Color(0xFF081421),
    surfaceContainerLow: const Color(0xFF0F243A),
    surfaceContainer: caminoSurface, // Default card body
    surfaceContainerHigh: caminoSurfaceHigh, // Chips, dropdowns
    surfaceContainerHighest: const Color(0xFF234467),

    // Outlines & borders
    outline: const Color(0xFF8CA8C4),
    outlineVariant: const Color(0xFF1E3A59),

    // Error states (warnings, off-route alerts)
    error: const Color(0xFFFFB4AB),
    onError: const Color(0xFF690005),
    errorContainer: const Color(0xFF93000A),
    onErrorContainer: const Color(0xFFFFDAD6),
  );

  final baseTheme = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: caminoNavyBase,
    canvasColor: caminoSurface,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    iconTheme: const IconThemeData(color: caminoYellow),
    listTileTheme: const ListTileThemeData(iconColor: caminoYellow),
  );

  return baseTheme.copyWith(
    // 1. Typography: Clean neutral text rather than forcing yellow everywhere
    textTheme: baseTheme.textTheme.copyWith(
      headlineLarge: baseTheme.textTheme.headlineLarge?.copyWith(
        color: const Color(0xFFF8FAFC),
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
      headlineMedium: baseTheme.textTheme.headlineMedium?.copyWith(
        color: const Color(0xFFF8FAFC),
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      headlineSmall: baseTheme.textTheme.headlineSmall?.copyWith(
        color: const Color(0xFFF1F5F9),
        fontWeight: FontWeight.w600,
      ),
      titleLarge: baseTheme.textTheme.titleLarge?.copyWith(
        color: const Color(0xFFF1F5F9),
        fontWeight: FontWeight.w600,
      ),
      titleMedium: baseTheme.textTheme.titleMedium?.copyWith(
        color: const Color(0xFFE2E8F0),
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: baseTheme.textTheme.bodyLarge?.copyWith(
        color: const Color(0xFFE2E8F0),
        height: 1.5,
      ),
      bodyMedium: baseTheme.textTheme.bodyMedium?.copyWith(
        color: const Color(0xFFCBD5E1),
        height: 1.45,
      ),
      bodySmall: baseTheme.textTheme.bodySmall?.copyWith(
        color: const Color(0xFFCBD5E1),
      ),
      labelLarge: baseTheme.textTheme.labelLarge?.copyWith(
        color: const Color(0xFFF1F5F9),
        fontWeight: FontWeight.w600,
      ),
    ),

    // 2. AppBar Theme
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 2,
      backgroundColor: caminoNavyBase,
      foregroundColor: caminoYellow,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: caminoYellow,
      ),
    ),

    // 3. Card Theme: Crisp rounded surfaces with subtle border contrast
    cardTheme: CardThemeData(
      elevation: 0,
      color: caminoSurface,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: caminoSurfaceBorder, width: 1),
      ),
    ),

    // 4. Primary Button Theme: Bold, high-visibility gold actions
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        elevation: 0,
        backgroundColor: caminoAmber,
        foregroundColor: const Color(0xFF1B1800),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    // 5. Outlined Button Theme: Clean secondary interactive items
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: const Color(0xFFE2E8F0),
        side: const BorderSide(color: Color(0xFF8CA8C4), width: 1.2),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    // 6. Text Button Theme: Low-friction auxiliary links
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: caminoAmber,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),

    // 7. Chip Theme: Elevated facility indicators
    chipTheme: ChipThemeData(
      backgroundColor: caminoSurfaceHigh,
      surfaceTintColor: Colors.transparent,
      side: const BorderSide(color: caminoSurfaceBorder, width: 0.8),
      labelStyle: const TextStyle(
        color: Color(0xFFE2E8F0),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    ),

    // 8. Divider Theme
    dividerTheme: const DividerThemeData(
      color: caminoSurfaceBorder,
      thickness: 1,
      space: 24,
    ),

    // 9. Input & Dialog Themes
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: caminoSurfaceHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF8CA8C4)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF8CA8C4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: caminoAmber, width: 1.5),
      ),
      labelStyle: const TextStyle(color: Color(0xFFCBD5E1)),
    ),
  );
}
