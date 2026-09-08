import 'package:flutter/material.dart';

/// Medical-grade color palette used across the application.
///
/// All colors are chosen to:
///   • Remain readable in both light and dark themes.
///   • Communicate health state intuitively (green=healthy, amber=warning, red=critical).
///   • Pass WCAG AA contrast on common backgrounds.
class AppColors {
  AppColors._();

  // ── Brand ───────────────────────────────────────────────
  /// Primary medical teal — instills trust & cleanliness.
  static const Color primary = Color(0xFF008B8B);

  /// Secondary accent — soft cyan used for highlights.
  static const Color secondary = Color(0xFF00B8B8);

  /// Tertiary mint for success indicators.
  static const Color tertiary = Color(0xFF4ECDC4);

  // ── Vital Status ───────────────────────────────────────
  /// All vitals within normal range.
  static const Color healthy = Color(0xFF2ECC71);

  /// Mild deviation — needs attention.
  static const Color warning = Color(0xFFF39C12);

  /// Severe deviation — emergency.
  static const Color critical = Color(0xFFE74C3C);

  /// Offline / no data.
  static const Color offline = Color(0xFF95A5A6);

  // ── Backgrounds (Light) ────────────────────────────────
  static const Color lightBackground = Color(0xFFF5F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);

  // ── Backgrounds (Dark) ─────────────────────────────────
  static const Color darkBackground = Color(0xFF0E1B22);
  static const Color darkSurface = Color(0xFF16242C);
  static const Color darkCard = Color(0xFF1E2F38);

  // ── Text ───────────────────────────────────────────────
  static const Color lightTextPrimary = Color(0xFF1A2A33);
  static const Color lightTextSecondary = Color(0xFF5A6C75);
  static const Color darkTextPrimary = Color(0xFFF0F4F7);
  static const Color darkTextSecondary = Color(0xFFA5B5BD);

  // ── Gradients ──────────────────────────────────────────
  /// Hero gradient — used on splash/auth backgrounds.
  static const Gradient heroGradient = LinearGradient(
    colors: [Color(0xFF008B8B), Color(0xFF00B8B8), Color(0xFF4ECDC4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Subtle card gradient.
  static const Gradient cardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF5F9FA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── ECG Waveform ───────────────────────────────────────
  static const Color ecgLine = Color(0xFF00C853);
  static const Color ecgGrid = Color(0x331A2A33);

  // ── Per-vital palette (used by cards / sparklines / charts) ──
  /// Heart-rate: warm red associated with cardiac rhythm.
  static const Color hrColor = Color(0xFFE74C3C);

  /// SpO₂: oxygen blue.
  static const Color spo2Color = Color(0xFF3498DB);

  /// Body temperature: thermal orange.
  static const Color tempColor = Color(0xFFF39C12);

  /// Returns a color reflecting a numeric health status.
  ///
  /// * [heartRate] in BPM.
  /// * [spo2] in percentage (0–100).
  static Color vitalsColor({required int heartRate, required int spo2}) {
    if (heartRate < 50 || heartRate > 120 || spo2 < 92) return critical;
    if (heartRate < 60 || heartRate > 100 || spo2 < 95) return warning;
    return healthy;
  }
}
