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
    @JsonKey(name: 'opened_at') @NullableDateTimeConverter() DateTime? openedAt,
    @JsonKey(name: 'acked_at') @NullableDateTimeConverter() DateTime? ackedAt,
    @JsonKey(name: 'closed_at') @NullableDateTimeConverter() DateTime? closedAt,
    @JsonKey(name: 'last_message_at')
    @NullableDateTimeConverter()
    DateTime? lastMessageAt,
    @JsonKey(name: 'desk_timer_fires_at')
    @NullableDateTimeConverter()
    DateTime? deskTimerFiresAt,
    @JsonKey(name: 'updated_at')
    @NullableDateTimeConverter()
    DateTime? updatedAt,
    @Default(<Message>[]) List<Message> messages,
  }) = _Incident;

  const Incident._();

  /// Reads [updatedAt], and when a 1.16 server has not sent it, takes the
  /// newest of the three times it does send.
  factory Incident.fromJson(Map<String, dynamic> json) =>
      _$IncidentFromJson(_withUpdatedAt(json));

  bool get isOpen => state == IncidentStates.open;
  bool get isAcked => state == IncidentStates.acked;
  bool get isClosed => state == IncidentStates.closed;
  bool get isExpired => state == IncidentStates.expired;

  IncidentState get incidentState => IncidentState.fromString(state);
}

/// Adds `updated_at` to [json] when it is missing, from the newest of the
/// three times a 1.16 server sends.
Map<String, dynamic> _withUpdatedAt(Map<String, dynamic> json) {
  if (json.containsKey('updated_at')) return json;
  const converter = NullableDateTimeConverter();
  final fallback = _latestOf(
    converter.fromJson(json['closed_at']),
    converter.fromJson(json['acked_at']),
    converter.fromJson(json['opened_at']),
  );
  if (fallback == null) return json;
  return {...json, 'updated_at': fallback.toIso8601String()};
}

/// The most recent non-null of the three, or null when all are null.
DateTime? _latestOf(DateTime? a, DateTime? b, DateTime? c) {
  final times = [a, b, c].whereType<DateTime>().toList();
  if (times.isEmpty) return null;
  return times.reduce((x, y) => x.isAfter(y) ? x : y);
}
