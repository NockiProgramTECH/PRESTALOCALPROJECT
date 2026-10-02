import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Système de design « Warm Kinetic Modern » (maquette Stitch
/// `stitch_refonte_plateforme_lesprodufao`, fichier `warm_kinetic_modern/DESIGN.md`).
///
/// - Primaire citrus `#FF8A3D` (état pressé `#E07228`)
/// - Encre navy `#1E293B` (textes, bordures structurelles)
/// - Confiance émeraude `#10B981` (badges Vérifié / Disponible)
/// - Canevas sable `#FBF9F7`, cartes `#FFFFFF`, bordures `#EAE3DB`
/// - Typographie unique : Plus Jakarta Sans
/// - Monnaie : montants en `FCFA` (voir `AppConstants.formatFcfa`)
///
/// Les anciens noms (`primaryGreen`, `surfaceLight`, ...) sont conservés en
/// alias pour les écrans non encore migrés vers la maquette.
class AppTheme {
  AppTheme._();

  // ---- Palette Warm Kinetic ----
  static const Color primary = Color(0xFFFF8A3D); // citrus : actions
  static const Color primaryPressed = Color(0xFFE07228); // état pressé
  static const Color primarySoft = Color(0xFFFFDBC9); // fond tinté orange
  static const Color navy = Color(0xFF1E293B); // encre principale
  static const Color success = Color(0xFF10B981); // émeraude : statuts
  static const Color successSoft = Color(0xFFECFDF5); // fond badges
  static const Color successText = Color(0xFF065F46); // texte badges
  static const Color successDeep = Color(0xFF047857); // micro-typo Vérifié
  static const Color canvas = Color(0xFFFBF9F7); // fond de page sable
  static const Color cardBorder = Color(0xFFEAE3DB); // bordures chaudes
  static const Color inputFill = Color(0xFFF5F3F1); // fond des champs
  static const Color muted = Color(0xFF64748B); // texte secondaire ardoise
  static const Color warning = Color(0xFFF59E0B); // ambre : attention
  static const Color danger = Color(0xFFEF4444); // rouge : destructif

  // ---- Alias de compatibilité (anciens noms -> nouvelle palette) ----
  // ignore: deprecated_member_use_from_same_package
  static const Color primaryGreen = primary;
  // ignore: deprecated_member_use_from_same_package
  static const Color primaryDark = primaryPressed;
  static const Color primaryContainer = primarySoft;
  // ignore: deprecated_member_use_from_same_package
  static const Color secondaryRed = danger;
  static const Color secondaryContainer = Color(0xFFFFDAD6);
  static const Color tertiaryGold = warning;
  // ignore: deprecated_member_use_from_same_package
  static const Color surfaceLight = canvas;
  static const Color surfaceDark = Color(0xFF121212);
  // ignore: deprecated_member_use_from_same_package
  static const Color textDark = navy;
  // ignore: deprecated_member_use_from_same_package
  static const Color textMedium = muted;
  static const Color textLight = Color(0xFF94A3B8);

  /// Dégradé de marque — `#FF8A3D → #E07228`.
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryPressed],
  );

  /// Ombre ambiante chaude (niveau 1 : cartes).
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: navy.withValues(alpha: 0.04),
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: primary.withValues(alpha: 0.03),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  /// Bordure standard des cartes blanches sur canevas sable.
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: cardBorder),
    boxShadow: cardShadow,
  );

  /// Définition complète du thème clair.
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primarySoft,
      onPrimaryContainer: const Color(0xFF682D00),
      secondary: navy,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFD5E0F8),
      onSecondaryContainer: navy,
      tertiary: success,
      onTertiary: Colors.white,
      tertiaryContainer: successSoft,
      onTertiaryContainer: successText,
      error: danger,
      onError: Colors.white,
      errorContainer: const Color(0xFFFFDAD6),
      onErrorContainer: const Color(0xFF93000A),
      surface: canvas,
      onSurface: navy,
      surfaceContainerHighest: const Color(0xFFE4E2E0),
      outline: cardBorder,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: canvas,
      // Typographie Plus Jakarta Sans (spec DESIGN.md).
      textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
        headlineLarge: GoogleFonts.plusJakartaSans(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: navy,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: navy,
        ),
        headlineSmall: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: navy,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: navy,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: navy,
        ),
        bodySmall: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: muted,
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        labelMedium: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        labelSmall: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      // AppBar blanche (les écrans dessinent leurs propres en-têtes).
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: navy,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: navy,
        ),
      ),
      // Cartes : blanches, radius 24, bordure chaude.
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),
      // Bouton primaire : orange 48px, radius 12.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primary.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      // Bouton secondaire : contour navy.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navy,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: const BorderSide(color: navy, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      // Bouton texte / ghost : texte orange.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      // Chips : pilules blanches bordées.
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: const BorderSide(color: cardBorder),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: navy,
        ),
      ),
      // Barre de navigation : pastille orange.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        indicatorColor: primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: primary,
            );
          }
          return GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: muted,
          );
        }),
      ),
      // Champs : fond sable, focus orange 2px.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: danger, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.plusJakartaSans(
          color: muted,
          fontSize: 14,
        ),
      ),
      // Bottom sheet.
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      // Dividers chauds.
      dividerTheme: const DividerThemeData(
        color: cardBorder,
        thickness: 1,
      ),
      // FAB orange.
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: navy,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 14,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// Séparateur vertical réutilisable.
  static Widget verticalDivider() {
    return Container(width: 1, height: 24, color: cardBorder);
  }
}
