import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/features/history/domain/entities/history_entry.dart';
import 'package:critalarm/features/history/domain/entities/history_filter.dart';
import 'package:critalarm/features/history/presentation/cubits/history_state.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Past alarms, newest first, grouped by the day they started.
class HistoryCubit extends Cubit<HistoryState> {
  HistoryCubit(this._getIncidents, {DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(const HistoryState());

  final GetIncidentsUsecase _getIncidents;
  final DateTime Function() _now;

  /// How far back the list reaches. The widest filter window can never ask for
  /// more than this, because nothing older was ever fetched.
  static const Duration window = HistoryWindows.full;

  Future<void> load() async {
    emit(state.copyWith(status: HistoryStatus.loading));
    final result = await _getIncidents(const GetIncidentsParams(limit: 200));
    result.fold(
      (incidents) {
        final now = _now();
        final entries = toEntries(incidents, now);
        emit(
          state.copyWith(
            status: HistoryStatus.success,
            entries: entries,
            days: groupByDay(filterEntries(entries, state.filter, now)),
            clearError: true,
          ),
        );
      },
      (failure) => emit(
        state.copyWith(
          status: HistoryStatus.failure,
          errorMessage: failure.message,
        ),
      ),
    );
  }

  Future<void> refresh() => load();

  /// Narrows the list down. Re-derives from what is already loaded, so this
  /// never goes back to the server.
  void applyFilter(HistoryFilter filter) {
    emit(
      state.copyWith(
        filter: filter,
        days: groupByDay(filterEntries(state.entries, filter, _now())),
      ),
    );
  }

  void clearFilter() => applyFilter(HistoryFilter.none);

  /// Keeps the entries that match [filter]. Order is preserved, so the result
  /// is still newest first and ready for [groupByDay].
  static List<HistoryEntry> filterEntries(
    List<HistoryEntry> entries,
    HistoryFilter filter,
    DateTime now,
  ) {
    final cutoff = now.subtract(filter.window);
    return <HistoryEntry>[
      for (final entry in entries)
        if (!entry.startedAt.isBefore(cutoff) &&
            (filter.states.isEmpty || filter.states.contains(entry.state)))
          entry,
    ];
  }

  /// Turns raw incidents into entries, dropping anything older than [window]
  /// and anything with no start time to sort on.
  static List<HistoryEntry> toEntries(List<Incident> incidents, DateTime now) {
    final cutoff = now.subtract(window);
    final entries = <HistoryEntry>[];

    for (final incident in incidents) {
      final startedAt = incident.openedAt;
      if (startedAt == null || startedAt.isBefore(cutoff)) continue;

      final stoppedAt =
          incident.ackedAt ?? incident.closedAt ?? incident.lastMessageAt;

      entries.add(
        HistoryEntry(
          id: incident.id,
          topic: incident.topic,
          startedAt: startedAt,
          state: incident.incidentState,
          ringDuration: stoppedAt == null
              ? (incident.isOpen ? now.difference(startedAt) : null)
              : stoppedAt.difference(startedAt),
        ),
      );
    }

    entries.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return entries;
  }

  /// Groups sorted entries into days, keeping the newest day first.
  static List<HistoryDay> groupByDay(List<HistoryEntry> entries) {
    final days = <HistoryDay>[];
    for (final entry in entries) {
      if (days.isNotEmpty && days.last.day == entry.day) {
        days.last.entries.add(entry);
      } else {
        days.add(HistoryDay(day: entry.day, entries: [entry]));
      }
    }
    return days;
  }
}
