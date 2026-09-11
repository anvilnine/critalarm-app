import 'package:json_annotation/json_annotation.dart';

/// Converts between dynamic JSON values (integer epoch seconds/ms, ISO strings)
/// and [DateTime] instances.
class DateTimeConverter implements JsonConverter<DateTime, dynamic> {
  const DateTimeConverter();

  @override
  DateTime fromJson(dynamic json) {
    final result = const NullableDateTimeConverter().fromJson(json);
    if (result != null) return result;
    throw ArgumentError('Cannot parse DateTime from $json');
  }

  @override
  dynamic toJson(DateTime date) => date.toUtc().toIso8601String();
}

/// Converts between nullable dynamic JSON values and [DateTime?] instances.
class NullableDateTimeConverter implements JsonConverter<DateTime?, dynamic> {
  const NullableDateTimeConverter();

  @override
  DateTime? fromJson(dynamic json) {
    if (json == null) return null;
    if (json is DateTime) return json.toUtc();
    if (json is int) {
      if (json < 10000000000) {
        return DateTime.fromMillisecondsSinceEpoch(json * 1000, isUtc: true);
      }
      return DateTime.fromMillisecondsSinceEpoch(json, isUtc: true);
    }
    if (json is String) {
      final asInt = int.tryParse(json);
      if (asInt != null) {
        if (asInt < 10000000000) {
          return DateTime.fromMillisecondsSinceEpoch(asInt * 1000, isUtc: true);
        }
        return DateTime.fromMillisecondsSinceEpoch(asInt, isUtc: true);
      }
      return DateTime.tryParse(json)?.toUtc();
    }
    return null;
  }

  @override
  dynamic toJson(DateTime? date) => date?.toUtc().toIso8601String();
}
