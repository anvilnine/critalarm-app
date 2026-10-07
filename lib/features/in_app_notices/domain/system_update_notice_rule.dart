import 'package:flutter/foundation.dart';

/// What the system update check says right now, as `InAppNoticeCubit` reads
/// it.
@immutable
class SystemUpdateReading {
  const SystemUpdateReading({required this.needsLook, required this.osMajor});

  /// A test alarm is due: the phone was updated since one last rang.
  final bool needsLook;

  /// The OS major version the phone runs, or null when it cannot be read.
  final int? osMajor;
}

/// Answers "should Home show the 'your phone was updated' notice".
///
/// It shows when every one of these holds:
///
/// - setup is done (`SetupGate`), like every other notice;
/// - the system update check needs a look;
/// - the OS version is known;
/// - the notice was not closed for this OS version.
///
/// Closing it, or tapping its test button, stores the version. It stays gone
/// until the phone is updated to another version. A test alarm that rings
/// clears the check, so the notice goes without being closed.
///
/// It is a card on Home. It is not a notification and it makes no alert.
abstract final class SystemUpdateNoticeRule {
  static bool shouldShow({
    required bool isSetupDone,
    required SystemUpdateReading? reading,
    required int? dismissedForMajor,
  }) {
    if (!isSetupDone || reading == null || !reading.needsLook) return false;
    final major = reading.osMajor;
    if (major == null) return false;
    return dismissedForMajor != major;
  }
}
