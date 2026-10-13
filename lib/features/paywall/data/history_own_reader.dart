import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/features/paywall/domain/history_own.dart';

/// Reads the rows the history picture draws from the phone's own copy of the
/// alarms. It asks no server and sends nothing.
class HistoryOwnReader {
  HistoryOwnReader({required this.incidents, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// Null where the phone has no local store (the web build).
  final IncidentStore? incidents;
  final DateTime Function() _now;

  /// The rows, or null when the phone holds nothing as old as the Free
  /// window, has no store, or a read fails.
  Future<HistoryOwn?> read() async {
    final store = incidents;
    if (store == null) return null;
    try {
      final now = _now();
      final free = AccountCaps.free.historyDays ?? 7;
      final windowStart = now.subtract(Duration(days: free));
      return historyOwnFrom(
        rows: [
          ...await store.newestSince(windowStart, limit: 50),
          ...await store.newestBefore(windowStart),
        ],
        now: now,
        freeDays: free,
      );
    } on Object catch (_) {
      return null;
    }
  }
}
