/// Motion duration tokens for Crit Alarm Design System.
abstract final class AppDurations {
  /// Quick interaction: press, hover lift, toggle knob (150ms).
  static const Duration quick = Duration(milliseconds: 150);

  /// Base transition: canvas retint, sheet content swap (300ms).
  static const Duration base = Duration(milliseconds: 300);

  /// Slow transition: sheet slide up, screen change (400ms).
  static const Duration slow = Duration(milliseconds: 400);

  /// Alarm ring pulse duration (900ms).
  static const Duration ring = Duration(milliseconds: 900);

  /// Alarmed face shake cycle cadence (500ms).
  static const Duration shake = Duration(milliseconds: 500);

  /// Watching face pupil drift cadence (4000ms).
  static const Duration look = Duration(milliseconds: 4000);

  // Backwards compatibility aliases
  static const Duration tap = Duration(milliseconds: 120);
  static const Duration fast = quick;
  static const Duration enter = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration exit = quick;
}
