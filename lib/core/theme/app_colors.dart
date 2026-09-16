import 'package:flutter/material.dart';

/// TELLO design system colors.
///
/// - Moments: soft purple (primary)
/// - Plans: orange accent
/// - Places: teal accent
/// - Celebrations: pink accent
class AppColors {
  AppColors._();

  // Primary — Moments
  static const Color primary = Color(0xFF7B6FD6);
  static const Color primaryLight = Color(0xFFEFECFC);
  static const Color primaryDark = Color(0xFF4E44A8);

  // Plans — orange accent
  static const Color planAccent = Color(0xFFF5934C);
  static const Color planAccentLight = Color(0xFFFEF1E5);

  // Places — teal accent
  static const Color placeAccent = Color(0xFF3AA6A0);
  static const Color placeAccentLight = Color(0xFFE4F5F4);

  // Celebrations — pink accent
  static const Color celebrationAccent = Color(0xFFE87CA0);
  static const Color celebrationAccentLight = Color(0xFFFCE9F0);

  // Neutrals
  static const Color background = Color(0xFFFAF9FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF241F33);
  static const Color textSecondary = Color(0xFF6F6A80);
  static const Color divider = Color(0xFFE9E6F2);

  // Semantic
  static const Color error = Color(0xFFD64545);
  static const Color success = Color(0xFF3FA37C);
  static const Color warning = Color(0xFFE0A73B);
}
