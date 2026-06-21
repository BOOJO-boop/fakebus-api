import 'package:flutter/material.dart';

// ─────────────────────────────────────────
//  COLORES
// ─────────────────────────────────────────
class AppColors {
  AppColors._();

  static const Color primary        = Color(0xFF2E7D32); // green[800]
  static const Color primaryDark    = Color(0xFF1B5E20); // green[900]
  static const Color primaryLight   = Color(0xFF388E3C); // green[700]
  static const Color onPrimary      = Colors.white;
  static const Color background     = Color(0xFF2E7D32); // fondo pantallas auth
  static const Color backgroundPage = Color(0xFFF3F4F6); // fondo homepage
  static const Color surface        = Colors.white;
  static const Color error          = Color(0xFFD32F2F);
  static const Color success        = Color(0xFF388E3C);
  static const Color textOnDark     = Colors.white;
  static const Color textOnDarkSoft = Color(0xCCFFFFFF); // white70

  // Semáforo de ocupación
  static const Color semaforoLibre    = Color(0xFF388E3C); // verde
  static const Color semaforoModerado = Color(0xFFF57C00); // naranja
  static const Color semaforoSaturado = Color(0xFFD32F2F); // rojo

  // Tarjeta
  static const Color cardBorder          = Color(0xFFE5E7EB);
  static const Color progressBackground  = Color(0xFFE5E7EB);
}

// ─────────────────────────────────────────
//  ESPACIADO
// ─────────────────────────────────────────
class AppSpacing {
  AppSpacing._();

  static const double xs  = 8.0;
  static const double sm  = 16.0;
  static const double md  = 24.0;
  static const double lg  = 32.0;
  static const double xl  = 40.0;
}

// ─────────────────────────────────────────
//  RADIOS
// ─────────────────────────────────────────
class AppRadius {
  AppRadius._();

  static const double input  = 12.0;
  static const double button = 12.0;
  static const double card   = 16.0;
}

// ─────────────────────────────────────────
//  ESTILOS DE TEXTO
// ─────────────────────────────────────────
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle appTitle = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.bold,
    color: AppColors.textOnDark,
  );

  static const TextStyle appSubtitle = TextStyle(
    fontSize: 14,
    color: AppColors.textOnDarkSoft,
  );

  static const TextStyle buttonLabel = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle linkOnDark = TextStyle(
    color: AppColors.textOnDark,
  );

  static const TextStyle pageTitle = TextStyle(
    color: AppColors.textOnDark,
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  // AppBar subtítulo (saludo)
  static const TextStyle appBarSubtitle = TextStyle(
    color: AppColors.textOnDarkSoft,
    fontSize: 12,
  );

  // Tarjeta de camión
  static const TextStyle cardTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Color(0xFF1A1A2E),
  );

  static const TextStyle cardSubtitle = TextStyle(
    fontSize: 13,
    color: Color(0xFF6B7280),
  );

  static const TextStyle cardDetail = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: Color(0xFF374151),
  );

  static const TextStyle badgeLabel = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.bold,
    fontSize: 13,
  );
}

// ─────────────────────────────────────────
//  WIDGETS REUTILIZABLES
// ─────────────────────────────────────────

/// TextField con estilo FakeBus
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Icon(icon),
      ),
    );
  }
}

/// Botón primario ancho completo
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.primaryLight,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        child: loading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label, style: AppTextStyles.buttonLabel),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  TEMA GLOBAL
// ─────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primaryDark,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: AppColors.textOnDark),
          titleTextStyle: AppTextStyles.pageTitle,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: BorderSide.none,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.primaryLight,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      );
}