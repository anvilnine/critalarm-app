import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/features/history/presentation/cubits/history_cubit.dart';
import 'package:critalarm/features/history/presentation/cubits/history_state.dart';
import 'package:flutter_test/flutter_test.dart';

Incident _incident({
  required String id,
  required String topic,
  required DateTime openedAt,
  String state = IncidentStates.acked,
  DateTime? ackedAt,
  DateTime? closedAt,
}) => Incident(
  id: id,
  topic: topic,
  state: state,
  openedAt: openedAt,
  ackedAt: ackedAt,
  closedAt: closedAt,
);

void main() {
  final now = DateTime(2026, 9, 11, 9, 44);

  group('HistoryCubit.toEntries', () {
    test('drops incidents older than the 30 day window', () {
      final entries = HistoryCubit.toEntries([
        _incident(
          id: 'i1',
          topic: 'prod-db',
          openedAt: now.subtract(const Duration(days: 2)),
        ),
        _incident(
          id: 'i2',
          topic: 'old-one',
          openedAt: now.subtract(const Duration(days: 31)),
        ),
      ], now);

      expect(entries.map((e) => e.id), ['i1']);
    });

    test('drops incidents with no start time', () {
      final entries = HistoryCubit.toEntries([
        const Incident(id: 'i1', topic: 'prod-db'),
      ], now);

      expect(entries, isEmpty);
    });

    test('ring time runs from opened to acknowledged', () {
      final opened = now.subtract(const Duration(minutes: 10));
      final entries = HistoryCubit.toEntries([
        _incident(
          id: 'i1',
          topic: 'prod-db',
          openedAt: opened,
          ackedAt: opened.add(const Duration(minutes: 2, seconds: 14)),
        ),
      ], now);

      expect(
        entries.single.ringDuration,
        const Duration(minutes: 2, seconds: 14),
      );
    });

    test('an open incident is still ringing, so it counts up to now', () {
      final entries = HistoryCubit.toEntries([
        _incident(
          id: 'i1',
          topic: 'prod-db',
          state: IncidentStates.open,
          openedAt: now.subtract(const Duration(seconds: 44)),
        ),
      ], now);

      expect(entries.single.ringDuration, const Duration(seconds: 44));
    });

    test('newest first', () {
      final entries = HistoryCubit.toEntries([
        _incident(
          id: 'older',
          topic: 'a',
          openedAt: now.subtract(const Duration(days: 3)),
        ),
        _incident(
          id: 'newer',
          topic: 'b',
          openedAt: now.subtract(const Duration(hours: 6)),
        ),
      ], now);

      expect(entries.map((e) => e.id), ['newer', 'older']);
    });
  });

  group('HistoryCubit.groupByDay', () {
    test('puts two alarms from the same day in one group', () {
      final entries = HistoryCubit.toEntries([
        _incident(id: 'a', topic: 'x', openedAt: DateTime(2026, 9, 9, 4, 41)),
        _incident(id: 'b', topic: 'y', openedAt: DateTime(2026, 9, 9, 21, 8)),
        _incident(id: 'c', topic: 'z', openedAt: DateTime(2026, 9, 8, 13, 55)),
      ], now);

      final days = HistoryCubit.groupByDay(entries);

      expect(days.length, 2);
      expect(days.first.day, DateTime(2026, 9, 9));
      expect(days.first.entries.map((e) => e.id), ['b', 'a']);
      expect(days.last.entries.map((e) => e.id), ['c']);
    });
  });

  group('HistoryState', () {
    test('counts alarms across every day', () {
      final entries = HistoryCubit.toEntries([
        _incident(id: 'a', topic: 'x', openedAt: DateTime(2026, 9, 9, 4, 41)),
        _incident(id: 'b', topic: 'y', openedAt: DateTime(2026, 9, 8, 21, 8)),
      ], now);

      final state = HistoryState(days: HistoryCubit.groupByDay(entries));

      expect(state.alarmCount, 2);
    });

    test('longest ring is the biggest of them', () {
      final entries = HistoryCubit.toEntries([
        _incident(
          id: 'a',
          topic: 'x',
          openedAt: DateTime(2026, 9, 9, 4, 41),
          ackedAt: DateTime(2026, 9, 9, 4, 47, 2),
        ),
        _incident(
          id: 'b',
          topic: 'y',
          openedAt: DateTime(2026, 9, 8, 21, 8),
          ackedAt: DateTime(2026, 9, 8, 21, 8, 18),
        ),
      ], now);

      final state = HistoryState(days: HistoryCubit.groupByDay(entries));

      expect(state.longestRing, const Duration(minutes: 6, seconds: 2));
    });

    test('longest ring is null when nothing rang', () {
      const state = HistoryState();
      expect(state.longestRing, isNull);
    });
  });
}
