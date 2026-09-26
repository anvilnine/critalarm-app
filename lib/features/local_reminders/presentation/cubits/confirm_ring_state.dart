import 'package:critalarm/features/local_reminders/domain/ring_failure.dart';
import 'package:flutter/foundation.dart';

enum ConfirmRingStatus {
  loading,

  /// The topics did not load, for example offline.
  loadFailed,
  ready,
  sending,
  sent,
}

@immutable
class RingTopicRow {
  const RingTopicRow({
    required this.name,
    required this.isCritical,
    this.daysSinceTest,
  });

  final String name;
  final bool isCritical;

  /// Calendar days since the last test that went out. Null: never tested.
  final int? daysSinceTest;
}

@immutable
class ConfirmRingState {
  const ConfirmRingState({
    this.status = ConfirmRingStatus.loading,
    this.critical = const [],
    this.normal = const [],
    this.selected,
    this.failure,
  });

  final ConfirmRingStatus status;
  final List<RingTopicRow> critical;

  /// Empty until the server can test a topic that is not critical.
  final List<RingTopicRow> normal;
  final String? selected;
  final RingFailure? failure;

  bool get isSelectedCritical => critical.any((row) => row.name == selected);

  ConfirmRingState copyWith({
    ConfirmRingStatus? status,
    List<RingTopicRow>? critical,
    List<RingTopicRow>? normal,
    String? selected,
    RingFailure? failure,
    bool clearFailure = false,
  }) => ConfirmRingState(
    status: status ?? this.status,
    critical: critical ?? this.critical,
    normal: normal ?? this.normal,
    selected: selected ?? this.selected,
    failure: clearFailure ? null : (failure ?? this.failure),
  );
}
