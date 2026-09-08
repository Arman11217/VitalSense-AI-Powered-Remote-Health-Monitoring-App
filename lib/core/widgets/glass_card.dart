import 'package:flutter/material.dart';

/// A reusable rounded card used throughout the dashboard.
///
/// Wraps any child with subtle elevation, rounded corners,
/// and consistent padding — keeping every module visually unified.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF1E2F38) : Colors.white,
      borderRadius: BorderRadius.circular(borderRadius),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
            gradient: isDark
                ? null
                : LinearGradient(
                    colors: [Colors.white, scheme.surfaceContainerHighest
                        .withValues(alpha: 0.3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
          ),
          child: child,
        ),
      ),
    );
  }
}
