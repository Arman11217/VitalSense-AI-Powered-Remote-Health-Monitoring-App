import 'package:flutter/material.dart';

/// A soft, animated gradient background used on auth & splash screens.
///
/// Animates between two brand-aligned color sets for a premium feel
/// without overwhelming the user.
class AnimatedGradientBg extends StatefulWidget {
  const AnimatedGradientBg({super.key, required this.child});

  final Widget child;

  @override
  State<AnimatedGradientBg> createState() => _AnimatedGradientBgState();
}

class _AnimatedGradientBgState extends State<AnimatedGradientBg>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 8))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * _ctrl.value, -1),
              end: Alignment(1, 1 - 2 * _ctrl.value),
              colors: const [
                Color(0xFF008B8B),
                Color(0xFF00B8B8),
                Color(0xFF4ECDC4),
              ],
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}
