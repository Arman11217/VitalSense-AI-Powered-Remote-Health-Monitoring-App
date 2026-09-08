import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/router/app_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/pulsing_dot.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  Onboarding screen (Module 3)
/// ─────────────────────────────────────────────────────────────────────────
/// PageView-based first-run experience that introduces the app's core
/// capabilities. On completion the user is sent to /login and a
/// `SharedPreferences` flag is flipped so the screen is never shown again.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const String _kOnboardingCompleteKey = 'onboarding_complete_v1';

  final List<_OnboardingPage> _pages = const <_OnboardingPage>[
    _OnboardingPage(
      icon: Icons.favorite_rounded,
      gradient: [Color(0xFF008B8B), Color(0xFF00B8B8)],
      title: 'Real-time Monitoring',
      description:
          'Stream heart rate, SpO₂, ECG and body temperature live from your '
          'ESP32 device — directly to your phone.',
    ),
    _OnboardingPage(
      icon: Icons.monitor_heart_rounded,
      gradient: [Color(0xFF00B8B8), Color(0xFF4ECDC4)],
      title: 'AI Disease Prediction',
      description:
          'A machine-learning model analyses every reading in the cloud and '
          'predicts heart-disease risk, abnormal patterns and emergencies.',
    ),
    _OnboardingPage(
      icon: Icons.history_rounded,
      gradient: [Color(0xFF4ECDC4), Color(0xFF008B8B)],
      title: 'Health History & Reports',
      description:
          'Browse your entire history, generate PDF reports and share them '
          'with your doctor in a single tap.',
    ),
    _OnboardingPage(
      icon: Icons.emergency_rounded,
      gradient: [Color(0xFFE74C3C), Color(0xFFF39C12)],
      title: 'Instant Emergency Alerts',
      description:
          'When vitals go critical, VitalSense raises an instant SOS, plays '
          'an audible alarm and notifies your emergency contacts.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) => setState(() => _currentPage = index);

  Future<void> _next() async {
    if (_currentPage < _pages.length - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      await _complete();
    }
  }

  Future<void> _complete() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingCompleteKey, true);
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final bool isLast = _currentPage == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // ── Skip button ──────────────────────────────────────────────
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextButton(
                  onPressed: _complete,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            // ── PageView ────────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (BuildContext context, int index) {
                  return _OnboardingSlide(page: _pages[index]);
                },
              ),
            ),

            // ── Dot indicators + CTA ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List<Widget>.generate(_pages.length, (int i) {
                      final bool active = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: active ? 28 : 8,
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.primary
                              : AppColors.primary.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _next,
                      child: Text(isLast ? 'Get Started' : AppStrings.next),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Slide widget ────────────────────────────────────────────────────────

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({required this.page});
  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          // ── Animated hero icon ──────────────────────────────────────
          GlassCard(
            padding: const EdgeInsets.all(40),
            borderRadius: 32,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: page.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: page.gradient.first.withValues(alpha: 0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Icon(page.icon, color: Colors.white, size: 72),
            ),
          ).animate().scale(
                duration: 500.ms,
                curve: Curves.easeOutBack,
                begin: const Offset(0.85, 0.85),
              ).fadeIn(duration: 400.ms),

          const SizedBox(height: 40),

          // ── Title + description ─────────────────────────────────────
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ).animate(key: ValueKey<String>('t-${page.title}'))
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.15, end: 0, duration: 400.ms),
          const SizedBox(height: 12),
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
          ).animate(key: ValueKey<String>('d-${page.title}'))
              .fadeIn(duration: 500.ms, delay: 100.ms)
              .slideY(begin: 0.2, end: 0, duration: 500.ms, delay: 100.ms),

          const SizedBox(height: 24),

          // Live pulse on the last slide to hint at "real-time".
          if (page.icon == Icons.favorite_rounded)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const PulsingDot(color: AppColors.healthy, size: 10),
                const SizedBox(width: 8),
                Text(
                  'LIVE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.healthy,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─── Data model ─────────────────────────────────────────────────────────

@immutable
class _OnboardingPage {
  const _OnboardingPage({
    required this.icon,
    required this.gradient,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final List<Color> gradient;
  final String title;
  final String description;
}
