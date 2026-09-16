import 'dart:async';
import 'dart:math' as math;

import 'package:critalarm/app/state/app_data_status.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/core/api/api_client.dart' show maxIncidentLimit;
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/features/history/domain/entities/history_entry.dart';
import 'package:critalarm/features/history/domain/entities/history_filter.dart';
import 'package:critalarm/features/history/presentation/cubits/history_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Past alarms, newest first, grouped by the day they started.
///
/// Two things narrow the list, and they are not the same thing. The plan caps
/// how far back the server will go and how many alarms come back at all. The
/// filter is the user choosing to see less than that. Caps apply when the list
/// is fetched, the filter applies to what was fetched, so changing the filter
/// never goes back to the server.
///
/// The incidents themselves come from the app-level [IncidentsCubit], so this
/// tab follows an acknowledge made anywhere else without being reopened.
class HistoryCubit extends Cubit<HistoryState> {
  HistoryCubit(
    this._incidents, {
    DateTime Function()? now,
    this.identityStore,
  }) : _now = now ?? DateTime.now,
       super(const HistoryState());

  final IncidentsCubit _incidents;
  final DateTime Function() _now;
  final DeviceIdentityStore? identityStore;

  StreamSubscription<IncidentsState>? _incidentsSub;

  /// What the days on screen were built from, so an upstream change that
  /// leaves the incidents alone does not regroup them.
  List<Incident>? _builtFrom;

  AccountCaps _caps = AccountCaps.free;

  Future<void> load() async {
    _incidentsSub ??= _incidents.stream.listen((_) => _rebuildIfChanged());
    // A refresh keeps whatever is already grouped. Only a first load has
    // nothing to show, and that is the only time the screen says "loading".
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
    _caps = identity?.caps ?? AccountCaps.free;

    await _incidents.ensureLoaded();
    _rebuildIfChanged();
  }

  Future<void> refresh() async {
    await _incidents.refresh();
    _rebuildIfChanged();
  }

  @override
  Future<void> close() async {
    await _incidentsSub?.cancel();
    return super.close();
  }

  void _rebuildIfChanged() {
    if (isClosed) return;
    final incidents = _incidents.state;

    if (incidents.status == AppDataStatus.failure) {
      _builtFrom = null;
      emit(
        state.copyWith(
          status: HistoryStatus.failure,
          errorMessage: incidents.errorMessage,
        ),
      );
      return;
    }
    if (!incidents.isReady) return;
    if (identical(incidents.incidents, _builtFrom)) return;
    _builtFrom = incidents.incidents;

    final now = _now();
    final entries = toEntries(incidents.incidents, now, caps: _caps);
    emit(
      state.copyWith(
        status: HistoryStatus.success,
        entries: entries,
        days: groupByDay(filterEntries(entries, state.filter, now)),
        isCapped: entries.length >= ceilingFor(_caps),
        clearError: true,
      ),
    );
  }

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

  /// The most alarms History can put on screen.
  ///
  /// Two ceilings, whichever is lower. The plan says how many a tier may show
  /// ([AccountCaps.historyIncidents], null on a paid tier). The shared list
  /// cannot fetch more than [maxIncidentLimit] in one call, and v1 has no
  /// paging, so a paid user with more alarms than that in their window still
  /// stops there.
  static int ceilingFor(AccountCaps caps) =>
      math.min(caps.historyIncidents ?? maxIncidentLimit, maxIncidentLimit);

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
          // The model keeps UTC, which is right for a model. Everything the
          // user reads is local, and History was the one screen that forgot:
          // the same incident read 05:31 here and 13:31 on topic detail.
          startedAt: startedAt.toLocal(),
          state: incident.incidentState,
          ringDuration: stoppedAt == null
              ? (incident.isOpen ? now.difference(startedAt) : null)
              : stoppedAt.difference(startedAt),
        ),
      );
    }

    entries.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return entries.take(ceilingFor(caps)).toList();
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
