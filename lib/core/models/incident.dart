import 'package:critalarm/core/models/date_time_converter.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'incident.freezed.dart';
part 'incident.g.dart';

abstract final class IncidentStates {
  static const open = 'open';
  static const acked = 'acked';
  static const closed = 'closed';
  static const expired = 'expired';
}

enum IncidentState {
  open,
  acked,
  closed,
  expired;

  static IncidentState fromString(String value) {
    return switch (value.toLowerCase()) {
      'acked' => IncidentState.acked,
      'closed' => IncidentState.closed,
      'expired' => IncidentState.expired,
      _ => IncidentState.open,
    };
  }
}

/// An alarm incident grouping repeats and tracking lifecycle state.
@freezed
abstract class Incident with _$Incident {
  const factory Incident({
    required String id,
    required String topic,
    @Default(IncidentStates.open) String state,
    @JsonKey(name: 'opened_at')
    @NullableDateTimeConverter()
    DateTime? openedAt,
    @JsonKey(name: 'acked_at')
    @NullableDateTimeConverter()
    DateTime? ackedAt,
    @JsonKey(name: 'closed_at')
    @NullableDateTimeConverter()
    DateTime? closedAt,
    @JsonKey(name: 'last_message_at')
    @NullableDateTimeConverter()
    DateTime? lastMessageAt,
    @JsonKey(name: 'desk_timer_fires_at')
    @NullableDateTimeConverter()
    DateTime? deskTimerFiresAt,
    @Default(<Message>[]) List<Message> messages,
  }) = _Incident;

  const Incident._();

  factory Incident.fromJson(Map<String, dynamic> json) =>
      _$IncidentFromJson(json);

  bool get isOpen => state == IncidentStates.open;
  bool get isAcked => state == IncidentStates.acked;
  bool get isClosed => state == IncidentStates.closed;
  bool get isExpired => state == IncidentStates.expired;

  IncidentState get incidentState => IncidentState.fromString(state);
}
