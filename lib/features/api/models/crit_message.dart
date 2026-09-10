import 'package:freezed_annotation/freezed_annotation.dart';

part 'crit_message.freezed.dart';
part 'crit_message.g.dart';

/// A message object as described in api.md §1.6.
@freezed
abstract class CritMessage with _$CritMessage {
  const factory CritMessage({
    required String id,
    required int time,
    required String topic,
    required String message,
    int? expires,
    String? event,
    String? title,
    int? priority,
    List<String>? tags,
    String? click,
    @JsonKey(name: 'incident_id') String? incidentId,
  }) = _CritMessage;

  factory CritMessage.fromJson(Map<String, dynamic> json) =>
      _$CritMessageFromJson(json);
}
