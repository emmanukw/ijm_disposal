import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand palette.
class Brand {
  static const navy = Color(0xFF0B2545);
  static const blue = Color(0xFF13497E);
  static const teal = Color(0xFF1B998B);
  static const amber = Color(0xFFF2A541);
  static const red = Color(0xFFD64545);
  static const bg = Color(0xFFF4F6FA);
  static const border = Color(0xFFE3E8EF);

  static const heroGradient = LinearGradient(
    colors: [navy, blue, Color(0xFF1A6E8E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.blue,
    primary: Brand.blue,
    secondary: Brand.teal,
    surface: Colors.white,
  );
  // Calling GoogleFonts.inter() registers + lazily loads the font.
  final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: GoogleFonts.inter().fontFamily);
  final radius = BorderRadius.circular(14);

  return base.copyWith(
    scaffoldBackgroundColor: Brand.bg,
    textTheme: base.textTheme.copyWith(
      headlineMedium: GoogleFonts.poppins(
          fontWeight: FontWeight.w700, fontSize: 28, color: Brand.navy),
      titleLarge: GoogleFonts.poppins(
          fontWeight: FontWeight.w600, fontSize: 20, color: Brand.navy),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Brand.navy,
      elevation: 0,
      scrolledUnderElevation: 1,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.poppins(
          fontSize: 18, fontWeight: FontWeight.w600, color: Brand.navy),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Brand.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: radius),
        side: const BorderSide(color: Brand.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF7F9FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: radius, borderSide: const BorderSide(color: Brand.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: radius, borderSide: const BorderSide(color: Brand.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: Brand.blue, width: 1.6)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: const BorderSide(color: Brand.border),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Brand.navy,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    dataTableTheme: DataTableThemeData(
      headingTextStyle: const TextStyle(
          fontWeight: FontWeight.w600, color: Color(0xFF5B6B82), fontSize: 13),
      headingRowColor: const WidgetStatePropertyAll(Color(0xFFF7F9FC)),
      dividerThickness: 0.6,
    ),
    tabBarTheme: const TabBarThemeData(dividerColor: Colors.transparent),
  );
}

/// Small colored pill used for statuses.
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const StatusPill(this.label, this.color, {super.key, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600, fontSize: 12)),
        ]),
      );
}
