import 'package:critalarm/features/api/models/crit_message.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'incident.freezed.dart';
part 'incident.g.dart';

/// An incident object as described in api.md §3.2.
@freezed
abstract class Incident with _$Incident {
  @JsonSerializable(explicitToJson: true)
  const factory Incident({
    required String id,
    required String topic,
    required String state,
    @JsonKey(name: 'opened_at') required int openedAt,
    @JsonKey(name: 'last_message_at') required int lastMessageAt,
    @JsonKey(name: 'acked_at') int? ackedAt,
    @JsonKey(name: 'closed_at') int? closedAt,
    @Default(<CritMessage>[]) List<CritMessage> messages,
    @JsonKey(name: 'desk_timer_fires_at') int? deskTimerFiresAt,
  }) = _Incident;

  factory Incident.fromJson(Map<String, dynamic> json) =>
      _$IncidentFromJson(json);
}
