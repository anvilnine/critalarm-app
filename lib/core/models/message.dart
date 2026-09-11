import 'package:freezed_annotation/freezed_annotation.dart';

part 'message.freezed.dart';
part 'message.g.dart';

/// An ntfy-compatible notification message with Crit Alarm extensions.
@freezed
abstract class Message with _$Message {
  const factory Message({
    required String id,
    required String topic,
    @Default(0) int time,
    int? expires,
    @Default('message') String event,
    String? title,
    @Default('triggered') String message,
    @Default(3) int priority,
    @Default(<String>[]) List<String> tags,
    String? click,
    @Default(false) bool markdown,
    @JsonKey(name: 'incident_id') String? incidentId,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
}
