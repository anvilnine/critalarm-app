import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/features/history/domain/entities/history_entry.dart';
import 'package:critalarm/features/history/domain/entities/history_filter.dart';
import 'package:critalarm/features/history/domain/history_window.dart';
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

  group('window chips follow the plan', () {
    test('Free keeps 7 days, so 30 and 90 are locked', () {
      final locked = [
        for (final w in HistoryWindows.all)
          if (HistoryWindows.isLocked(w, 7)) w,
      ];
      expect(locked, <Duration>[HistoryWindows.month, HistoryWindows.quarter]);
    });

    test('Pro keeps 90 days, so nothing is locked', () {
      expect(
        HistoryWindows.all.any((w) => HistoryWindows.isLocked(w, 90)),
        isFalse,
      );
    });

    test('shownDays is 90 for paid and self-hosted, the cap for Free', () {
      expect(HistoryWindow.shownDays(isPaid: true, historyDays: 7), 90);
      expect(
        HistoryWindow.shownDays(
          isPaid: false,
          historyDays: 7,
          isSelfHosted: true,
        ),
        90,
      );
      expect(HistoryWindow.shownDays(isPaid: false, historyDays: 7), 7);
    });

    test('effective window: Free default resolves to 7 days', () {
      expect(
        HistoryWindows.effective(HistoryFilter.none.window, 7),
        HistoryWindows.week,
      );
    });

    test('effective window: Pro default stays 90 days', () {
      expect(
        HistoryWindows.effective(HistoryFilter.none.window, 90),
        HistoryWindows.quarter,
      );
    });

    test('effective window: Free with a stale 30 day filter gets 7 days', () {
      expect(
        HistoryWindows.effective(HistoryWindows.month, 7),
        HistoryWindows.week,
      );
      expect(
        HistoryWindows.effective(HistoryWindows.day, 7),
        HistoryWindows.day,
      );
    });

    test('the default filter opens on the widest window', () {
      expect(HistoryFilter.none.window, HistoryWindows.quarter);
    });
  });
}
