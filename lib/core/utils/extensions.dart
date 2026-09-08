import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Handy extensions that keep code readable at call sites.
extension ContextExtensions on BuildContext {
  /// `Theme.of(this).textTheme` with shorter syntax.
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// `Theme.of(this).colorScheme` shorthand.
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// `MediaQuery.sizeOf(this)` shorthand.
  Size get screenSize => MediaQuery.sizeOf(this);

  /// `MediaQuery.paddingOf(this)` shorthand.
  EdgeInsets get padding => MediaQuery.paddingOf(this);
}

extension DoubleExtensions on double {
  /// Format to 1 decimal place (e.g., 36.7).
  String get asTemp => toStringAsFixed(1);
  String get asOneDecimal => toStringAsFixed(1);
}

extension IntExtensions on int {
  String get asBpm => toString();
  String get asPercent => '$this%';
}

extension DateTimeExtensions on DateTime {
  /// `Jul 13, 2026 — 10:42 AM`
  String get formatted => DateFormat('MMM d, y — hh:mm a').format(this);

  /// `10:42:15`
  String get formattedTime => DateFormat('hh:mm:ss a').format(this);

  /// `Jul 13`
  String get formattedDate => DateFormat('MMM d').format(this);

  /// `2026-07-13`
  String get isoDay => DateFormat('yyyy-MM-dd').format(this);

  /// Returns `true` if same calendar day as [other].
  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;
}
