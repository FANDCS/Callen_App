import 'package:flutter/material.dart';

/// Κεντρικό design system της εφαρμογής.
///
/// Αντί για το γενικό Material "seed green", διαλέγουμε ρητά μια πιο
/// σοφιστικέ, βαθιά δασική/σμαραγδί απόχρωση ως brand χρώμα, με ζεστό,
/// απαλό κόκκινο για χαμένες κλήσεις — πιο εκλεπτυσμένο από το ωμό
/// Material red.
class AppColors {
  AppColors._();

  static const Color brand = Color(0xFF0B6E4F); // βαθύ σμαραγδί
  static const Color brandDark = Color(0xFF063D2C);
  static const Color incoming = Color(0xFF2E7D32); // πράσινο, εισερχόμενη
  static const Color outgoing = Color(0xFF1565C0); // μπλε, εξερχόμενη
  static const Color missed = Color(0xFFD64550); // απαλό κόκκινο, χαμένη
  static const Color blocked = Color(0xFF6B6B6B); // γκρι, μπλοκαρισμένη

  static const Color surfaceTint = Color(0xFFF4F8F6); // ελαφρύ πράσινο-γκρι
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: Brightness.light,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surfaceTint,
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        // Μεγάλος αριθμός στο πληκτρολόγιο: λεπτό βάρος, αραιά
        // διάστιχα ψηφίων — πιο "εκλεπτυσμένο" από το default bold.
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w300,
          letterSpacing: 1.5,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          color: base.colorScheme.onSurfaceVariant,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceTint,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 3,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? colorScheme.primary : colorScheme.outline,
          );
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: Brightness.dark,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF101513),
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w300,
          letterSpacing: 1.5,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF101513),
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF181F1C),
        elevation: 3,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? colorScheme.primary : colorScheme.outline,
          );
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF1B221E),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
    );
  }

  /// Χρώμα ανά τύπο κλήσης — χρησιμοποιείται σε avatars/εικονίδια
  /// στο ιστορικό κλήσεων.
  static Color callTypeColor(String semanticType) {
    switch (semanticType) {
      case 'incoming':
        return AppColors.incoming;
      case 'outgoing':
        return AppColors.outgoing;
      case 'missed':
        return AppColors.missed;
      default:
        return AppColors.blocked;
    }
  }
}
