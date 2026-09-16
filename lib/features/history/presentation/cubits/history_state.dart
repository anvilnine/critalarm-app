import 'package:critalarm/features/history/domain/entities/history_entry.dart';
import 'package:critalarm/features/history/domain/entities/history_filter.dart';
import 'package:flutter/foundation.dart';

enum HistoryStatus { initial, loading, success, failure }

@immutable
class HistoryState {
  const HistoryState({
    this.status = HistoryStatus.initial,
    this.entries = const <HistoryEntry>[],
    this.days = const <HistoryDay>[],
    this.filter = HistoryFilter.none,
    this.isCapped = false,
    this.errorMessage,
  });

  final HistoryStatus status;

  /// Every alarm that was loaded, before [filter] is applied. Kept so changing
  /// the filter never needs another fetch.
  final List<HistoryEntry> entries;

  /// What the list draws: [entries] narrowed by [filter], grouped into days.
  final List<HistoryDay> days;

  final HistoryFilter filter;

  /// [entries] holds as many alarms as History is allowed to hold, so there
  /// are older ones the app cannot reach. v1 has no paging, so the only
  /// honest thing to do is say so.
  final bool isCapped;

  final String? errorMessage;

  bool get isLoading => status == HistoryStatus.loading;
  bool get isEmpty => status == HistoryStatus.success && days.isEmpty;

  /// Nothing has ever rung, so the filter is not what is hiding the list.
  bool get isEmptyBeforeFilter =>
      status == HistoryStatus.success && entries.isEmpty;

  /// There are alarms, but none of them survive the filter.
  bool get isEmptyAfterFilter =>
      status == HistoryStatus.success && entries.isNotEmpty && days.isEmpty;

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
    List<HistoryEntry>? entries,
    List<HistoryDay>? days,
    HistoryFilter? filter,
    bool? isCapped,
    String? errorMessage,
    bool clearError = false,
  }) {
    return HistoryState(
      status: status ?? this.status,
      entries: entries ?? this.entries,
      days: days ?? this.days,
      filter: filter ?? this.filter,
      isCapped: isCapped ?? this.isCapped,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
