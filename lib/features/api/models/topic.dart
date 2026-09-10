import 'package:freezed_annotation/freezed_annotation.dart';

part 'topic.freezed.dart';
part 'topic.g.dart';

/// A topic row as described in api.md §3.1.
@freezed
abstract class Topic with _$Topic {
  const factory Topic({
    required String name,
    @JsonKey(name: 'repeat_interval_s') required int repeatIntervalS,
    @JsonKey(name: 'max_ring_s') required int maxRingS,
    @JsonKey(name: 'desk_timer_s') required int deskTimerS,
    @JsonKey(name: 'relay_content') required String relayContent,
    @JsonKey(name: 'created_at') required int createdAt,
    @Default(false) bool critical,
  }) = _Topic;

  factory Topic.fromJson(Map<String, dynamic> json) => _$TopicFromJson(json);
}
