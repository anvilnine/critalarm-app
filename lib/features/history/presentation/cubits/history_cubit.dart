import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/features/history/domain/entities/history_entry.dart';
import 'package:critalarm/features/history/domain/entities/history_filter.dart';
import 'package:critalarm/features/history/presentation/cubits/history_state.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Past alarms, newest first, grouped by the day they started.
///
/// Two things narrow the list, and they are not the same thing. The plan caps
/// how far back the server will go and how many alarms come back at all. The
/// filter is the user choosing to see less than that. Caps apply when the list
/// is fetched, the filter applies to what was fetched, so changing the filter
/// never goes back to the server.
class HistoryCubit extends Cubit<HistoryState> {
  HistoryCubit(
    this._getIncidents, {
    DateTime Function()? now,
    this.identityStore,
  }) : _now = now ?? DateTime.now,
       super(const HistoryState());

  final GetIncidentsUsecase _getIncidents;
  final DateTime Function() _now;
  final DeviceIdentityStore? identityStore;

  Future<void> load() async {
    emit(state.copyWith(status: HistoryStatus.loading));
    final identity = await identityStore?.readOrCreate();
    if (identityStore != null && identity?.accountId == null) {
      emit(
        state.copyWith(
          status: HistoryStatus.failure,
          days: [],
          errorMessage:
              'History limits unavailable. Reconnect to refresh your plan.',
        ),
      );
      return;
    }
    final caps = identity?.caps ?? AccountCaps.free;
    final result = await _getIncidents(
      GetIncidentsParams(limit: caps.historyIncidents),
    );
    result.fold(
      (incidents) {
        final now = _now();
        final entries = toEntries(incidents, now, caps: caps);
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
  ///
  /// The filter can only narrow what the plan already allowed through, so a
  /// 30 day window on a plan that keeps 7 days still shows 7.
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

  /// Apply both display caps, then group the newest incidents first.
  static List<HistoryEntry> toEntries(
    List<Incident> incidents,
    DateTime now, {
    AccountCaps caps = AccountCaps.free,
  }) {
    final cutoff = caps.historyDays == null
        ? null
        : now.subtract(Duration(days: caps.historyDays!));
    final entries = <HistoryEntry>[];

    for (final incident in incidents) {
      final startedAt = incident.openedAt;
      if (startedAt == null || (cutoff != null && startedAt.isBefore(cutoff))) {
        continue;
      }

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
    return caps.historyIncidents == null
        ? entries
        : entries.take(caps.historyIncidents!).toList();
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
