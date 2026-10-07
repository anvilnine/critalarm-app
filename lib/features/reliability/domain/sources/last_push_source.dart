import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/push/last_push_reader.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/reliability_check_source.dart';

/// Whether pushes still reach this phone.
///
/// With at least one critical topic, a phone that has received nothing for
/// more than [quietFor] needs a look. With no critical topic there is nothing
/// to wait for, so the check is fine. A phone that has never received a push
/// counts its silence from the first time this was read.
///
/// The fix is a test alarm, through the route [testRouteName].
///
/// Reasons: `silent`.
final class LastPushSource implements ReliabilityCheckSource {
  LastPushSource({
    required this.reader,
    required this.capabilities,
    required this.hasCriticalTopic,
    required this.testRouteName,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// A silence longer than this, with a critical topic, needs a look.
  static const quietFor = Duration(days: 7);

  final LastPushReader reader;
  final PlatformCapabilities capabilities;
  final Future<bool> Function() hasCriticalTopic;
  final String testRouteName;
  final DateTime Function() _now;

  @override
  Future<List<ReliabilityCheck>> read() async {
    if (!capabilities.canRegisterPush) {
      return [
        const ReliabilityCheck.notOnThisPhone(
          ReliabilityCheckIds.lastPushReceived,
        ),
      ];
    }
    final now = _now();
    final last = await reader.read();
    final since = await reader.store.watchingSince(now);
    return [
      lastPushCheckFor(
        now: now,
        lastPushAt: last,
        watchingSince: since,
        hasCriticalTopic: await hasCriticalTopic(),
        testRouteName: testRouteName,
      ),
    ];
  }

  /// The state rule. Pure, so a test picks the clock.
  static ReliabilityCheck lastPushCheckFor({
    required DateTime now,
    required DateTime? lastPushAt,
    required DateTime watchingSince,
    required bool hasCriticalTopic,
    required String testRouteName,
  }) {
    const id = ReliabilityCheckIds.lastPushReceived;
    if (!hasCriticalTopic) {
      return ReliabilityCheck(
        id: id,
        state: ReliabilityState.fine,
        lastKnownGood: lastPushAt,
      );
    }
    final reference = lastPushAt ?? watchingSince;
    if (now.difference(reference) > quietFor) {
      return ReliabilityCheck(
        id: id,
        state: ReliabilityState.needsLook,
        lastKnownGood: lastPushAt,
        reason: 'silent',
        fix: OpenRouteFix(testRouteName),
      );
    }
    return ReliabilityCheck(
      id: id,
      state: ReliabilityState.fine,
      lastKnownGood: lastPushAt,
    );
  }
}
