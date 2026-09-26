import 'package:flutter/foundation.dart';

/// The phone's time zone as the native side reports it on every resume.
///
/// Rules work in wall-clock time ("10:00 on Saturday where the phone is"),
/// so every stored instant goes through [toWall] before a rule sees it.
/// Dart's own idea of the zone can lag behind a zone change until the app
/// restarts, which is why the offset comes from the platform.
@immutable
final class DeviceTimeZone {
  const DeviceTimeZone({required this.name, required this.offsetMinutes});

  /// What Dart itself thinks. Used on web and in tests.
  factory DeviceTimeZone.fromDart([DateTime? at]) {
    final now = at ?? DateTime.now();
    return DeviceTimeZone(
      name: now.timeZoneName,
      offsetMinutes: now.timeZoneOffset.inMinutes,
    );
  }

  static const DeviceTimeZone utc = DeviceTimeZone(
    name: 'UTC',
    offsetMinutes: 0,
  );

  /// IANA name, for example `Asia/Manila`.
  final String name;

  /// Minutes ahead of UTC right now.
  final int offsetMinutes;

  /// The wall-clock time on the phone at [instant]. Only the fields matter;
  /// the result is a plain local `DateTime` built from them.
  DateTime toWall(DateTime instant) {
    final shifted = instant.toUtc().add(Duration(minutes: offsetMinutes));
    return DateTime(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
      shifted.second,
    );
  }

  /// The instant a wall-clock [wall] time stands for, in UTC.
  DateTime toInstant(DateTime wall) => DateTime.utc(
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
    wall.second,
  ).subtract(Duration(minutes: offsetMinutes));

  @override
  bool operator ==(Object other) =>
      other is DeviceTimeZone &&
      other.name == name &&
      other.offsetMinutes == offsetMinutes;

  @override
  int get hashCode => Object.hash(name, offsetMinutes);
}
