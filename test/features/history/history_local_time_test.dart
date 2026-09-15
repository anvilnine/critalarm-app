import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/features/history/presentation/cubits/history_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('History shows local time', () {
    test('a UTC start time comes out local', () {
      // The server hands out UTC and the model keeps it that way. History used
      // to render it straight, so the same incident read 05:31 there and
      // 13:31 in the message list on topic detail.
      final openedUtc = DateTime.utc(2026, 9, 15, 5, 31);
      final now = DateTime.now();

      final entries = HistoryCubit.toEntries([
        Incident(
          id: 'i1',
          topic: 'phase3-crit',
          state: IncidentStates.acked,
          openedAt: openedUtc,
          ackedAt: openedUtc.add(const Duration(minutes: 4, seconds: 28)),
        ),
      ], now);

      expect(entries, hasLength(1));
      expect(entries.single.startedAt.isUtc, isFalse);
      expect(
        entries.single.startedAt,
        openedUtc.toLocal(),
        reason: 'every time the user reads is local',
      );
    });

    test('the ring length is unchanged by the conversion', () {
      final openedUtc = DateTime.utc(2026, 9, 15, 5, 31);
      final entries = HistoryCubit.toEntries([
        Incident(
          id: 'i1',
          topic: 'phase3-crit',
          state: IncidentStates.acked,
          openedAt: openedUtc,
          ackedAt: openedUtc.add(const Duration(minutes: 4, seconds: 28)),
        ),
      ], DateTime.now());

      expect(
        entries.single.ringDuration,
        const Duration(minutes: 4, seconds: 28),
      );
    });
  });
}
