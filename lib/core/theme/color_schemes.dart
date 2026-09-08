import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Material 3 color schemes for both light and dark themes.
///
/// Built with [ColorScheme.fromSeed] for guaranteed accessibility,
/// then overridden with project-specific tokens.
class AppColorSchemes {
  AppColorSchemes._();

  static final ColorScheme light = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    tertiary: AppColors.tertiary,
    surface: AppColors.lightSurface,
    error: AppColors.critical,
    onPrimary: Colors.white,
    onSurface: AppColors.lightTextPrimary,
  );

  static final ColorScheme dark = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.secondary,
    secondary: AppColors.tertiary,
    tertiary: AppColors.tertiary,
    surface: AppColors.darkSurface,
    error: AppColors.critical,
    onPrimary: Colors.black,
    onSurface: AppColors.darkTextPrimary,
  );
}
