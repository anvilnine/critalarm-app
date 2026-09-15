import 'package:critalarm/core/models/date_time_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'topic.freezed.dart';
part 'topic.g.dart';

/// A notification topic registered on the server.
///
/// Commitment made to Apple: [critical] defaults to `false`.
@freezed
abstract class Topic with _$Topic {
  const factory Topic({
    required String name,
    @Default(false) bool critical,
    @JsonKey(name: 'repeat_interval_s') @Default(30) int repeatIntervalS,
    @JsonKey(name: 'max_ring_s') @Default(1800) int maxRingS,
    @JsonKey(name: 'desk_timer_s') @Default(600) int deskTimerS,
    @JsonKey(name: 'relay_content') @Default('none') String relayContent,
    @JsonKey(name: 'created_at')
    @NullableDateTimeConverter()
    DateTime? createdAt,
    String? token,
    @JsonKey(name: 'token_id') String? tokenId,
  }) = _Topic;

  factory Topic.fromJson(Map<String, dynamic> json) => _$TopicFromJson(json);
}
