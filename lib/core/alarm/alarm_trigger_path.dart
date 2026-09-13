/// Which of the two iOS trigger paths in the spec (Part A, iOS) schedules the
/// alarm.
///
/// The answer is an on-device finding, not a design choice, so it is written
/// down once in `docs/specs/remote-alarm-ios-spike.md` and read back here. The
/// test reads that file and fails if [chosen] drifts away from the verdict, so
/// nobody can flip the path in code and leave the spike saying something else.
enum AlarmTriggerPath {
  /// Path 1. The alert push carries `mutable-content: 1` and the Notification
  /// Service Extension schedules the alarm.
  notificationServiceExtension('nse'),

  /// Path 2. The push carries `content-available: 1`, the app is woken in the
  /// background, and it schedules the alarm from the main process.
  appBackgroundPush('app-background-push');

  const AlarmTriggerPath(this.id);

  /// The value the spike file writes on its `Verdict:` line.
  final String id;

  /// What the app is built to use. Mirrored by `AlarmTriggerPath.chosen` in
  /// `ios/Shared/Alarm/AlarmTriggerPath.swift`.
  static const AlarmTriggerPath chosen = AlarmTriggerPath.appBackgroundPush;

  /// The line the spike file has to carry, as it is written there.
  static const verdictPrefix = 'Verdict:';

  /// Reads the verdict out of the spike document.
  ///
  /// Throws [FormatException] when the file has no verdict line or names a
  /// path that does not exist, because either one means the spike was never
  /// finished and there is nothing to build against.
  static AlarmTriggerPath fromSpike(String markdown) {
    for (final line in markdown.split('\n')) {
      final trimmed = line.trim();
      if (!trimmed.startsWith(verdictPrefix)) continue;
      final value = trimmed.substring(verdictPrefix.length).trim();
      for (final path in AlarmTriggerPath.values) {
        if (path.id == value) return path;
      }
      throw FormatException('unknown trigger path in spike verdict: "$value"');
    }
    throw const FormatException(
      'no "$verdictPrefix" line in the spike document',
    );
  }
}
