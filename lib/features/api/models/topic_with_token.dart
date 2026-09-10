import 'package:critalarm/features/api/models/topic.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'topic_with_token.freezed.dart';
part 'topic_with_token.g.dart';

/// A topic with its initial creation token returned once by `POST /v1/topics`.
@freezed
abstract class TopicWithToken with _$TopicWithToken {
  const factory TopicWithToken({
    required String name,
    @JsonKey(name: 'repeat_interval_s') required int repeatIntervalS,
    @JsonKey(name: 'max_ring_s') required int maxRingS,
    @JsonKey(name: 'desk_timer_s') required int deskTimerS,
    @JsonKey(name: 'relay_content') required String relayContent,
    @JsonKey(name: 'created_at') required int createdAt,
    required String token,
    @Default(false) bool critical,
  }) = _TopicWithToken;

  const TopicWithToken._();

  factory TopicWithToken.fromJson(Map<String, dynamic> json) =>
      _$TopicWithTokenFromJson(json);

  /// Converts this topic with token into a plain [Topic].
  Topic toTopic() => Topic(
    name: name,
    repeatIntervalS: repeatIntervalS,
    maxRingS: maxRingS,
    deskTimerS: deskTimerS,
    relayContent: relayContent,
    createdAt: createdAt,
    critical: critical,
  );
}
