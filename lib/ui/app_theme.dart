import 'package:flutter/material.dart';
import 'app_title.dart';
import 'camino_colors.dart';

// Brand colors
const Color caminoNavyBase = caminoBlue; // Deep trail night background
const Color caminoSurface = Color(0xFF16304A); // Level 1 card surface
const Color caminoSurfaceHigh = Color(0xFF1E3B58); // Level 2 elevated elements
const Color caminoSurfaceBorder = Color(0xFF2E4F72); // Subtle card border
const Color caminoAmber = caminoYellow; // Refined waypoint gold accent
const Color caminoAmberSubtle = Color(
  0xFFF6E3BC,
); // Highlight text on dark accents

ThemeData buildCaminoTheme() {
  final colorScheme = ColorScheme(
    brightness: Brightness.dark,
    // Primary interactive focal points (CTAs, key markers)
    primary: caminoAmber,
    onPrimary: const Color(0xFF231A00),
    primaryContainer: const Color(0xFF4A3A12),
    onPrimaryContainer: caminoAmberSubtle,

    // Secondary navigation / subtle badges
    secondary: const Color(0xFF7DB8E8),
    onSecondary: const Color(0xFF003258),
    secondaryContainer: const Color(0xFF183D63),
    onSecondaryContainer: const Color(0xFFD1E4FF),

    // Surface & background tonal hierarchy
    surface: caminoNavyBase,
    onSurface: const Color(0xFFF2F5F9), // High readability off-white
    onSurfaceVariant: const Color(0xFFBFCCDB), // Muted slate for captions/dates
    surfaceContainerLowest: const Color(0xFF081421),
    surfaceContainerLow: const Color(0xFF0F243A),
    surfaceContainer: caminoSurface, // Default card body
    surfaceContainerHigh: caminoSurfaceHigh, // Chips, dropdowns
    surfaceContainerHighest: const Color(0xFF234467),

    // Outlines & borders
    outline: const Color(0xFF8FA9C4),
    outlineVariant: const Color(0xFF1E3A59),

    // Error states (warnings, off-route alerts)
    error: const Color(0xFFF4A59A),
    onError: const Color(0xFF690005),
    errorContainer: const Color(0xFF93000A),
    onErrorContainer: const Color(0xFFFFDAD6),
  );

  final baseTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'Figtree',
    colorScheme: colorScheme,
    scaffoldBackgroundColor: caminoNavyBase,
    canvasColor: caminoSurface,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    iconTheme: const IconThemeData(color: caminoYellow),
    listTileTheme: const ListTileThemeData(iconColor: caminoYellow),
  );

  return baseTheme.copyWith(
    extensions: const [CaminoColors.dark],
    // 1. Typography: Clean neutral text rather than forcing yellow everywhere
    textTheme: baseTheme.textTheme.copyWith(
      displayLarge: baseTheme.textTheme.displayLarge?.copyWith(
        fontWeight: FontWeight.w900,
      ),
      displayMedium: baseTheme.textTheme.displayMedium?.copyWith(
        fontWeight: FontWeight.w300,
      ),
      headlineLarge: baseTheme.textTheme.headlineLarge?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      headlineMedium: baseTheme.textTheme.headlineMedium?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      headlineSmall: baseTheme.textTheme.headlineSmall?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: baseTheme.textTheme.titleLarge?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: baseTheme.textTheme.titleMedium?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: baseTheme.textTheme.bodyLarge?.copyWith(
        color: colorScheme.onSurface,
        height: 1.5,
      ),
      bodyMedium: baseTheme.textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
        height: 1.45,
      ),
      bodySmall: baseTheme.textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      labelLarge: baseTheme.textTheme.labelLarge?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      height: 76,
      backgroundColor: colorScheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      indicatorColor: colorScheme.primaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? caminoYellow
              : colorScheme.onSurfaceVariant,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Figtree',
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w600,
          color: states.contains(WidgetState.selected)
              ? caminoYellow
              : colorScheme.onSurfaceVariant,
        ),
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
        fontFamily: 'Figtree',
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
        foregroundColor: colorScheme.onPrimary,
        textStyle: const TextStyle(
          fontFamily: 'Figtree',
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    // 5. Outlined Button Theme: Clean secondary interactive items
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: colorScheme.onSurface,
        side: BorderSide(color: colorScheme.outline, width: 1.2),
        textStyle: const TextStyle(
          fontFamily: 'Figtree',
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    // 6. Text Button Theme: Low-friction auxiliary links
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: caminoAmber,
        textStyle: const TextStyle(
          fontFamily: 'Figtree',
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),

    // 7. Chip Theme: Elevated facility indicators
    chipTheme: ChipThemeData(
      backgroundColor: caminoSurfaceHigh,
      surfaceTintColor: Colors.transparent,
      side: const BorderSide(color: caminoSurfaceBorder, width: 0.8),
      labelStyle: TextStyle(
        fontFamily: 'Figtree',
        color: colorScheme.onSurface,
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
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: caminoAmber, width: 1.5),
      ),
      labelStyle: TextStyle(
        fontFamily: 'Figtree',
        color: colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
