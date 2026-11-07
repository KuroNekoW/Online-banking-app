import 'package:flutter/material.dart';

class AppColors {
  // Brand colors
  static const Color primary = Color(0xFF0D47A1);       // Deep Banking Blue
  static const Color primaryLight = Color(0xFF1976D2);
  static const Color primaryDark = Color(0xFF0A2540);
  static const Color accent = Color(0xFF00BFA5);        // Fintech Emerald/Teal
  static const Color accentLight = Color(0xFFA7F3D0);

  // Backgrounds & Surface
  static const Color background = Color(0xFFF8FAFC);    // Slate 50
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);// Slate 100
  static const Color divider = Color(0xFFE2E8F0);

  // Text
  static const Color textPrimary = Color(0xFF0F172A);   // Slate 900
  static const Color textSecondary = Color(0xFF64748B); // Slate 500
  static const Color textMuted = Color(0xFF94A3B8);     // Slate 400
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Status colors
  static const Color success = Color(0xFF10B981);       // Money in (+)
  static const Color error = Color(0xFFEF4444);         // Money out (-)
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Bank Card Gradients
  static const LinearGradient cardGradientBlue = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0A2540),
      Color(0xFF1E3A8A),
      Color(0xFF2563EB),
    ],
  );

  static const LinearGradient cardGradientGold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF78350F),
      Color(0xFFB45309),
      Color(0xFFF59E0B),
    ],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFF0D47A1),
      Color(0xFF1976D2),
    ],
  );
}
