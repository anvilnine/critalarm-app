import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/features/paywall/domain/leaving_floors.dart';
import 'package:critalarm/features/paywall/domain/leaving_numbers.dart';

/// Counts the leaving paywall's numbers from the phone's own copy of the
/// alarms. It asks no server and sends nothing.
class LeavingFactsReader {
  LeavingFactsReader({
    required this.incidents,
    required this.readCriticalTopics,
    required this.setupIncidentIds,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Null where the phone has no local store (the web build).
  final IncidentStore? incidents;
  final Future<int> Function() readCriticalTopics;

  /// `SetupTestRing.setupIncidentIds`: the test alarms setup rang.
  final Set<String> Function() setupIncidentIds;
  final DateTime Function() _now;

  /// The numbers, or null when the phone has no store or a read fails.
  Future<LeavingFacts?> read() async {
    final store = incidents;
    if (store == null) return null;
    try {
      final now = _now();
      final from = now.subtract(const Duration(days: LeavingFloors.windowDays));
      final rows = await store.openedSince(from);
      return leavingFactsFrom(
        alarms: [
          for (final row in rows)
            LeavingAlarm(
              id: row.id,
              openedAt: row.openedAt,
              isAcked: row.isAcked,
            ),
        ],
        now: now,
        criticalTopics: await readCriticalTopics(),
        oldestOpenedAt: await store.oldestOpenedAt(),
        excludedIds: setupIncidentIds(),
      );
    } on Object catch (_) {
      return null;
    }
  }
}
