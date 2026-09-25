import 'dart:async';

import 'package:critalarm/app/state/app_data_status.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/models/account_access.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/features/history/domain/entities/history_entry.dart';
import 'package:critalarm/features/history/domain/entities/history_filter.dart';
import 'package:critalarm/features/history/domain/history_window.dart';
import 'package:critalarm/features/history/presentation/cubits/history_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Past alarms, newest first, grouped by the day they started.
///
/// Two things narrow the list, and they are not the same thing. The tier says
/// how far back the app may show ([HistoryWindow]). The filter is the user
/// choosing to see less than that. Neither one deletes anything: the rows sit
/// on the phone either way, so buying Pro unhides the old ones with no
/// download and a plan lapsing hides them again.
///
/// With a [LocalStore] wired the list is read from disk a page at a time, so
/// scrolling never goes to the network. Without one it falls back to whatever
/// the app-level [IncidentsCubit] holds in memory.
class HistoryCubit extends Cubit<HistoryState> {
  HistoryCubit(
    this._incidents, {
    DateTime Function()? now,
    this.identityStore,
    this.sessionStore,
    this.store,
    this.isSelfHosted = false,
    PlanChanges? planChanges,
  }) : _now = now ?? DateTime.now,
       _planChanges = planChanges ?? appPlanChanges,
       super(const HistoryState()) {
    _planChanges.addListener(_onPlanChanged);
  }

  /// How many alarms one page of the local read holds.
  static const pageSize = 50;

  final IncidentsCubit _incidents;
  final DateTime Function() _now;
  final DeviceIdentityStore? identityStore;

  /// Read once per load to tell a self-hosted server from a relay one.
  final ApiSessionStore? sessionStore;

  /// The phone's own copy. Null in tests that only exercise the grouping.
  final LocalStore? store;

  /// A self-hosted server is never sent a tier, so it has no window. Read
  /// again from [sessionStore] on every load.
  bool isSelfHosted;

  /// Tells this cubit when the plan may have moved, so buying Pro shows the
  /// older alarms without an app restart.
  final PlanChanges _planChanges;

  /// Whether the account counts as paid. Read from [AccountAccess], so the
  /// store saying Pro and the developer switch count too.
  bool _isPaid = false;

  /// How many pages have been read off disk.
  int _pagesRead = 0;

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

    if (!await _readPlan()) {
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

    await _incidents.ensureLoaded();
    _builtFrom = null;
    await _reload();
  }

  /// Reads the plan and the server mode again. False when there is an
  /// identity store but no account in it, so no plan to go on.
  Future<bool> _readPlan() async {
    final identity = await identityStore?.readOrCreate();
    if (identityStore != null && identity?.accountId == null) return false;
    _caps = identity?.caps ?? AccountCaps.free;
    _isPaid =
        identity != null &&
        AccountAccess(identity, planChanges: _planChanges).isPaid;
    final session = await sessionStore?.read();
    if (session != null) {
      isSelfHosted = session.mode == ServerMode.selfhosted;
    }
    return true;
  }

  /// The plan moved. Read it again and redraw, so older alarms appear and
  /// the upsell footer goes away.
  void _onPlanChanged() {
    if (isClosed || state.status == HistoryStatus.initial) return;
    unawaited(_reloadPlan());
  }

  Future<void> _reloadPlan() async {
    if (!await _readPlan() || isClosed) return;
    _builtFrom = null;
    await _reload();
  }

  /// True when the list loaded, so the face can say so.
  Future<bool> refresh() async {
    await _incidents.refresh(full: true);
    // The plan can move while the tab sits open, so a pull reads it too.
    await _readPlan();
    _builtFrom = null;
    await _reload();
    return _incidents.state.status != AppDataStatus.failure;
  }

  /// The oldest alarm this tier may show, or null for "everything held".
  DateTime? get window => HistoryWindow.lowerBound(
    isPaid: _isPaid,
    historyDays: _caps.historyDays ?? 7,
    now: _now(),
    isSelfHosted: isSelfHosted,
  );

  /// Reads the next page off disk. The list calls this near its end.
  Future<void> loadMore() async {
    final local = store;
    if (local == null || !state.hasMore || state.isLoadingMore) return;
    emit(state.copyWith(isLoadingMore: true));

    final now = _now();
    final page = await local.incidents.page(
      window: window,
      // Says the page size at the place that decides it, not only in a
      // default two files away.
      // ignore: avoid_redundant_argument_values
      limit: pageSize,
      offset: _pagesRead * pageSize,
    );
    if (isClosed) return;
    _pagesRead++;

    final entries = [...state.entries, ...toEntries(page, now)];
    emit(
      state.copyWith(
        entries: entries,
        days: groupByDay(filterEntries(entries, state.filter, now)),
        hasMore: page.length == pageSize,
        isLoadingMore: false,
      ),
    );
  }

  /// Reads the first page and the hidden count again.
  Future<void> _reload() async {
    final local = store;
    if (local == null) {
      _rebuildIfChanged();
      return;
    }
    if (_incidents.state.status == AppDataStatus.failure &&
        await local.incidents.count() == 0) {
      emit(
        state.copyWith(
          status: HistoryStatus.failure,
          errorMessage: _incidents.state.errorMessage,
        ),
      );
      return;
    }

    final now = _now();
    final bound = window;
    // Says the page size here rather than leaning on the store's default.
    // ignore: avoid_redundant_argument_values
    final page = await local.incidents.page(window: bound, limit: pageSize);
    final older = await local.incidents.countOlderThan(bound);
    if (isClosed) return;
    _pagesRead = 1;

    final entries = toEntries(page, now);
    emit(
      state.copyWith(
        status: HistoryStatus.success,
        entries: entries,
        days: groupByDay(filterEntries(entries, state.filter, now)),
        olderCount: older,
        hasMore: page.length == pageSize,
        isLoadingMore: false,
        clearError: true,
      ),
    );
  }

  @override
  Future<void> close() async {
    _planChanges.removeListener(_onPlanChanged);
    await _incidentsSub?.cancel();
    return super.close();
  }

  void _rebuildIfChanged() {
    if (isClosed) return;
    if (store != null) {
      unawaited(_reload());
      return;
    }
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
    final bound = window;
    final all = toEntries(incidents.incidents, now);
    final entries = bound == null
        ? all
        : [
            for (final entry in all)
              if (!entry.startedAt.isBefore(bound.toLocal())) entry,
          ];
    emit(
      state.copyWith(
        status: HistoryStatus.success,
        entries: entries,
        days: groupByDay(filterEntries(entries, state.filter, now)),
        olderCount: all.length - entries.length,
        hasMore: false,
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
  /// The filter can only narrow what the tier already allowed through, so a
  /// 30 day window on a free plan still shows 7 days.
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

  /// Turns incidents into rows, newest first. Nothing is dropped here: the
  /// window has already been applied by the query that read them.
  static List<HistoryEntry> toEntries(
    List<Incident> incidents,
    DateTime now,
  ) {
    final entries = <HistoryEntry>[];

    for (final incident in incidents) {
      final startedAt = incident.openedAt;
      if (startedAt == null) continue;

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
