import 'package:critalarm/features/history/domain/entities/history_entry.dart';
import 'package:flutter/foundation.dart';

enum HistoryStatus { initial, loading, success, failure }

@immutable
class HistoryState {
  const HistoryState({
    this.status = HistoryStatus.initial,
    this.days = const <HistoryDay>[],
    this.errorMessage,
  });

  final HistoryStatus status;
  final List<HistoryDay> days;
  final String? errorMessage;

  bool get isLoading => status == HistoryStatus.loading;
  bool get isEmpty => status == HistoryStatus.success && days.isEmpty;

  int get alarmCount =>
      days.fold(0, (total, day) => total + day.entries.length);

  /// The longest single ring in the window, for the line under the face.
  Duration? get longestRing {
    Duration? longest;
    for (final day in days) {
      for (final entry in day.entries) {
        final ring = entry.ringDuration;
        if (ring == null) continue;
        if (longest == null || ring > longest) longest = ring;
      }
    }
    return longest;
  }

  HistoryState copyWith({
    HistoryStatus? status,
    List<HistoryDay>? days,
    String? errorMessage,
    bool clearError = false,
  }) {
    return HistoryState(
      status: status ?? this.status,
      days: days ?? this.days,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
