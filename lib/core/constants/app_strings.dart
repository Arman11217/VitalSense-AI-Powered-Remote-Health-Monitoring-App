/// Centralized constant strings used across the application.
///
/// Keeping all user-facing strings in one place makes
/// future localization (English + বাংলা) straightforward.
class AppStrings {
  AppStrings._();

  // ── App ────────────────────────────────────────────────
  static const String appName = 'VitalSense';
  static const String appTagline = 'AI-Powered Remote Health Monitoring';
  static const String appDescription =
      'Real-time physiological monitoring and AI-driven disease prediction.';

  // ── Auth ───────────────────────────────────────────────
  static const String login = 'Log In';
  static const String register = 'Create Account';
  static const String forgotPassword = 'Forgot password?';
  static const String emailVerification = 'Verify your email';
  static const String logout = 'Log out';

  // ── Module Titles ──────────────────────────────────────
  static const String dashboard = 'Dashboard';
  static const String liveEcg = 'Live ECG';
  static const String aiAnalysis = 'AI Analysis';
  static const String healthHistory = 'Health History';
  static const String reports = 'Reports';
  static const String emergency = 'Emergency';
  static const String profile = 'Profile';
  static const String deviceManagement = 'Device Management';

  // ── Vitals ─────────────────────────────────────────────
  static const String heartRate = 'Heart Rate';
  static const String spo2 = 'Blood Oxygen';
  static const String temperature = 'Body Temperature';
  static const String ecgSignal = 'ECG Signal';
  static const String healthScore = 'Health Score';
  static const String heartDiseaseRisk = 'Heart Disease Risk';
  static const String lastUpdated = 'Last updated';
  static const String bpm = 'bpm';
  static const String percent = '%';
  static const String celsius = '°C';

  // ── Status ─────────────────────────────────────────────
  static const String deviceOnline = 'Device online';
  static const String deviceOffline = 'Device offline';
  static const String wifiConnected = 'Wi-Fi connected';
  static const String firebaseConnected = 'Cloud connected';
  static const String noData = 'No data available yet';

  // ── Common Actions ─────────────────────────────────────
  static const String retry = 'Retry';
  static const String cancel = 'Cancel';
  static const String confirm = 'Confirm';
  static const String save = 'Save';
  static const String continue_ = 'Continue';
  static const String back = 'Back';
  static const String next = 'Next';
  static const String done = 'Done';
}
