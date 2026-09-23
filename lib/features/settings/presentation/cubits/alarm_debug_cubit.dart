import 'dart:convert';

import 'package:critalarm/core/ack/ack_queue_entry.dart';
import 'package:critalarm/core/alarm/alarm_debug_snapshot.dart';
import 'package:critalarm/features/settings/presentation/cubits/alarm_debug_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum AlarmDebugAction {
  flushNow('flush_now'),
  cancelAllRearms('cancel_all_rearms'),
  clearContentCache('clear_content_cache'),
  clearAckedSet('clear_acked_set'),
  reconcileNow('reconcile_now');

  const AlarmDebugAction(this.wireName);
  final String wireName;
}

/// Coordinates diagnostic reads and explicit developer actions.
final class AlarmDebugCubit extends Cubit<AlarmDebugState> {
  AlarmDebugCubit({
    required this._readNative,
    required this._readEnvironment,
    required this._readDartAckQueue,
    required this._readPushEvents,
    required this._readLaunchCalls,
    required this._readStoreStats,
    required this._flushNow,
    required this._cancelAllRearms,
    required this._clearContentCache,
    required this._clearAckedSet,
    required this._reconcileNow,
    required this._recordDebugAction,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const AlarmDebugState());

  final Future<Map<String, Object?>> Function() _readNative;
  final Future<DebugEnvironment> Function() _readEnvironment;
  final List<AckQueueEntry> Function() _readDartAckQueue;
  final List<DebugPushEvent> Function() _readPushEvents;
  final List<DebugLaunchCall> Function() _readLaunchCalls;
  final Future<DebugStoreStats> Function() _readStoreStats;
  final Future<void> Function() _flushNow;
  final Future<void> Function() _cancelAllRearms;
  final Future<void> Function() _clearContentCache;
  final Future<void> Function() _clearAckedSet;
  final Future<void> Function() _reconcileNow;
  final void Function(String action) _recordDebugAction;
  final DateTime Function() _clock;
  int _refreshGeneration = 0;

  Future<void> refresh() async {
    final generation = ++_refreshGeneration;
    emit(state.copyWith(loading: state.snapshot == null, clearError: true));
    try {
      final values = await Future.wait<Object>([
        _readNative(),
        _readEnvironment(),
        _readStoreStats(),
      ]);
      final native = values[0] as Map<String, Object?>;
      final snapshot = AlarmDebugSnapshot.fromNative(
        native,
        takenAt: _clock(),
        environment: values[1] as DebugEnvironment,
        dartAckQueue: [
          for (final entry in _readDartAckQueue())
            DebugAckEntry(
              action: entry.action.name,
              incidentId: entry.incidentId,
              attempts: entry.attempts,
              nextAttemptAt: DateTime.fromMillisecondsSinceEpoch(
                entry.nextAttemptAtMs,
                isUtc: true,
              ),
              source: DebugAckSource.dart,
            ),
        ],
        pushEvents: _readPushEvents(),
        launchCalls: _readLaunchCalls(),
        store: values[2] as DebugStoreStats,
      );
      if (isClosed || generation != _refreshGeneration) return;
      emit(
        state.copyWith(snapshot: snapshot, loading: false, clearError: true),
      );
    } on Object catch (error) {
      if (isClosed || generation != _refreshGeneration) return;
      emit(state.copyWith(loading: false, error: error.toString()));
    }
  }

  Future<void> performAction(AlarmDebugAction action) async {
    emit(state.copyWith(actionInProgress: action.wireName, clearError: true));
    Object? actionError;
    try {
      switch (action) {
        case AlarmDebugAction.flushNow:
          _recordDebugAction(action.wireName);
          await _flushNow();
        case AlarmDebugAction.cancelAllRearms:
          await _cancelAllRearms();
        case AlarmDebugAction.clearContentCache:
          await _clearContentCache();
        case AlarmDebugAction.clearAckedSet:
          await _clearAckedSet();
        case AlarmDebugAction.reconcileNow:
          _recordDebugAction(action.wireName);
          await _reconcileNow();
      }
    } on Object catch (error) {
      actionError = error;
    }
    await refresh();
    if (!isClosed) {
      emit(
        state.copyWith(
          clearAction: true,
          error: actionError?.toString(),
          clearError: actionError == null,
        ),
      );
    }
  }

  String copyReportJson() {
    final snapshot = state.snapshot;
    if (snapshot == null) throw StateError('No alarm debug snapshot loaded');
    return const JsonEncoder.withIndent('  ').convert(snapshot.toJson());
  }
}
