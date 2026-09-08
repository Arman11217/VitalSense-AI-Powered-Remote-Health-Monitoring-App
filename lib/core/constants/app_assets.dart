/// Centralized asset paths to avoid magic strings scattered across the codebase.
class AppAssets {
  AppAssets._();

  // ── Images ─────────────────────────────────────────────
  static const String logo = 'assets/images/logo.png';
  static const String onboardingDoctor = 'assets/images/onboarding_doctor.svg';
  static const String onboardingHeart = 'assets/images/onboarding_heart.svg';
  static const String onboardingAi = 'assets/images/onboarding_ai.svg';

  // ── Icons (custom SVG) ─────────────────────────────────
  static const String iconHeart = 'assets/icons/heart.svg';
  static const String iconLungs = 'assets/icons/lungs.svg';
  static const String iconThermometer = 'assets/icons/thermometer.svg';
  static const String iconPulse = 'assets/icons/pulse.svg';

  // ── Sounds ─────────────────────────────────────────────
  static const String alarmSound = 'assets/sounds/alarm.mp3';
  static const String notificationSound = 'assets/sounds/notification.mp3';
}
