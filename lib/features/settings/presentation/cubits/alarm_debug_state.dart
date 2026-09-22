import 'package:critalarm/core/alarm/alarm_debug_snapshot.dart';

final class AlarmDebugState {
  const AlarmDebugState({
    this.snapshot,
    this.loading = false,
    this.actionInProgress,
    this.error,
  });

  final AlarmDebugSnapshot? snapshot;
  final bool loading;
  final String? actionInProgress;
  final String? error;

  AlarmDebugState copyWith({
    AlarmDebugSnapshot? snapshot,
    bool? loading,
    String? actionInProgress,
    bool clearAction = false,
    String? error,
    bool clearError = false,
  }) => AlarmDebugState(
    snapshot: snapshot ?? this.snapshot,
    loading: loading ?? this.loading,
    actionInProgress: clearAction
        ? null
        : actionInProgress ?? this.actionInProgress,
    error: clearError ? null : error ?? this.error,
  );
}
