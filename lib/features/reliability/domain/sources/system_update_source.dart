import 'package:critalarm/core/device/os_version_reader.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/os_version_store.dart';
import 'package:critalarm/features/reliability/domain/reliability_check_source.dart';

/// Whether the phone has been updated since a test alarm last rang.
///
/// The first run stores the OS major version and reports fine. When a later
/// run sees a different major version it stores the new one with the time of
/// the change, and the check needs a look until a test alarm rings that is
/// newer than that time.
///
/// Not on this phone when the version cannot be read (the web).
///
/// A change time or a test time in the future (a clock that was set back)
/// cannot be compared, so the check needs a look until the clock catches up.
///
/// Reasons: `os_changed`, `clock`. The fix is a test alarm, through
/// [testRouteName].
///
/// [recordVersion] does the comparing and storing without building a check.
/// Call it on launch, so a change is stamped when it happened and not when a
/// screen first asks.
final class SystemUpdateSource implements ReliabilityCheckSource {
  SystemUpdateSource({
    required this.os,
    required this.store,
    required this.lastTestAt,
    required this.testRouteName,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final OsVersionReader os;
  final OsVersionStore store;

  /// The newest successful test alarm on any topic, or null if there is none.
  final Future<DateTime?> Function() lastTestAt;
  final String testRouteName;
  final DateTime Function() _now;

  /// Stores the version, and the time of a change. Null when it cannot be
  /// read.
  Future<OsVersionRecord?> recordVersion() async {
    final major = await os.major();
    if (major == null) return null;
    final held = store.read();
    if (held.major == major) return held;
    final next = held.major == null
        ? OsVersionRecord(major: major, changedAt: held.changedAt)
        : OsVersionRecord(major: major, changedAt: _now());
    await store.write(next);
    return next;
  }

  /// [recordVersion] for the launch path, where nobody awaits it. It never
  /// throws: a phone that cannot read or save the version tries again on the
  /// next read.
  Future<void> recordVersionAtLaunch() async {
    try {
      await recordVersion();
    } on Object catch (_) {
      // Nothing waits for this, and the next read stamps the change.
    }
  }

  @override
  Future<List<ReliabilityCheck>> read() async {
    final record = await recordVersion();
    if (record == null) {
      return [
        const ReliabilityCheck.notOnThisPhone(ReliabilityCheckIds.systemUpdate),
      ];
    }
    return [
      systemUpdateCheckFor(
        now: _now(),
        changedAt: record.changedAt,
        lastTestAt: await lastTestAt(),
        testRouteName: testRouteName,
      ),
    ];
  }

  /// The state rule. Pure. A test at the very moment of the change does not
  /// count: it has to be newer.
  static ReliabilityCheck systemUpdateCheckFor({
    required DateTime now,
    required DateTime? changedAt,
    required DateTime? lastTestAt,
    required String testRouteName,
  }) {
    const id = ReliabilityCheckIds.systemUpdate;
    if (changedAt == null) {
      return const ReliabilityCheck(id: id, state: ReliabilityState.fine);
    }
    if (changedAt.isAfter(now) || (lastTestAt?.isAfter(now) ?? false)) {
      return ReliabilityCheck(
        id: id,
        state: ReliabilityState.needsLook,
        reason: 'clock',
        fix: OpenRouteFix(testRouteName),
      );
    }
    if (lastTestAt != null && lastTestAt.isAfter(changedAt)) {
      return ReliabilityCheck(
        id: id,
        state: ReliabilityState.fine,
        lastKnownGood: lastTestAt,
      );
    }
    return ReliabilityCheck(
      id: id,
      state: ReliabilityState.needsLook,
      lastKnownGood: lastTestAt,
      reason: 'os_changed',
      fix: OpenRouteFix(testRouteName),
    );
  }
}
