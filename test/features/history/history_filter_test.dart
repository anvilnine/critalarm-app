import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/features/history/domain/entities/history_entry.dart';
import 'package:critalarm/features/history/domain/entities/history_filter.dart';
import 'package:critalarm/features/history/presentation/cubits/history_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

HistoryEntry _entry({
  required String id,
  required DateTime startedAt,
  IncidentState state = IncidentState.acked,
}) {
  return HistoryEntry(
    id: id,
    topic: 'prod-db',
    startedAt: startedAt,
    state: state,
    ringDuration: const Duration(seconds: 30),
  );
}

void main() {
  final now = DateTime(2026, 9, 15, 10);
  final entries = <HistoryEntry>[
    _entry(
      id: 'today-open',
      startedAt: now.subtract(const Duration(hours: 2)),
      state: IncidentState.open,
    ),
    _entry(
      id: 'three-days-acked',
      startedAt: now.subtract(const Duration(days: 3)),
    ),
    _entry(
      id: 'ten-days-closed',
      startedAt: now.subtract(const Duration(days: 10)),
      state: IncidentState.closed,
    ),
  ];

  group('HistoryCubit.filterEntries', () {
    test('the default filter keeps everything', () {
      expect(
        HistoryCubit.filterEntries(entries, HistoryFilter.none, now),
        entries,
      );
    });

    test('a narrower window drops anything older than it', () {
      final week = HistoryCubit.filterEntries(
        entries,
        const HistoryFilter(window: HistoryWindows.week),
        now,
      );
      final day = HistoryCubit.filterEntries(
        entries,
        const HistoryFilter(window: HistoryWindows.day),
        now,
      );

      expect(week.map((e) => e.id), <String>['today-open', 'three-days-acked']);
      expect(day.map((e) => e.id), <String>['today-open']);
    });

    test('an empty state set means every state, not none', () {
      // HistoryFilter.none is the one with no states picked.
      expect(
        HistoryCubit.filterEntries(entries, HistoryFilter.none, now),
        hasLength(3),
      );
    });

    test('picking states keeps only those', () {
      final ringing = HistoryCubit.filterEntries(
        entries,
        const HistoryFilter(states: <IncidentState>{IncidentState.open}),
        now,
      );

      expect(ringing.map((e) => e.id), <String>['today-open']);
    });

    test('state and window both apply', () {
      final filtered = HistoryCubit.filterEntries(
        entries,
        const HistoryFilter(
          states: <IncidentState>{IncidentState.acked, IncidentState.closed},
          window: HistoryWindows.week,
        ),
        now,
      );

      expect(filtered.map((e) => e.id), <String>['three-days-acked']);
    });

    test('order is kept, so the result is still ready to group by day', () {
      // The widest window, so nothing is dropped and only the order is proved.
      final filtered = HistoryCubit.filterEntries(
        entries,
        HistoryFilter.none,
        now,
      );

      expect(filtered, entries);
    });
  });

  group('HistoryFilter', () {
    test('the default is not active and counts nothing', () {
      expect(HistoryFilter.none.isActive, isFalse);
      expect(HistoryFilter.none.activeCount, 0);
    });

    test('each control away from its default counts once', () {
      const states = HistoryFilter(
        states: <IncidentState>{IncidentState.open},
      );
      const both = HistoryFilter(
        states: <IncidentState>{IncidentState.open},
        window: HistoryWindows.week,
      );

      expect(states.activeCount, 1);
      expect(both.activeCount, 2);
      expect(both.isActive, isTrue);
    });

    test('toggleState adds then removes', () {
      final on = HistoryFilter.none.toggleState(IncidentState.acked);
      final off = on.toggleState(IncidentState.acked);

      expect(on.states, <IncidentState>{IncidentState.acked});
      expect(off.states, isEmpty);
    });

    test('withAllStates clears the states and keeps the window', () {
      const filter = HistoryFilter(
        states: <IncidentState>{IncidentState.open},
        window: HistoryWindows.week,
      );

      expect(filter.withAllStates().states, isEmpty);
      expect(filter.withAllStates().window, HistoryWindows.week);
    });

    test('two filters with the same contents are equal', () {
      const a = HistoryFilter(
        states: <IncidentState>{IncidentState.open, IncidentState.acked},
        window: HistoryWindows.week,
      );
      const b = HistoryFilter(
        states: <IncidentState>{IncidentState.acked, IncidentState.open},
        window: HistoryWindows.week,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
