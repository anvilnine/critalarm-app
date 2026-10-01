import 'dart:async';

import 'package:critalarm/features/local_reminders/domain/device_time_zone.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_kind.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_scheduler.dart';
import 'package:flutter/services.dart';

/// The app's own reminder scheduler: Swift in `AppDelegate.swift`, Kotlin
/// under `android/.../reminders/`, one method channel between them and Dart.
///
/// A platform with no handler answers `MissingPluginException`; every call
/// but `schedule` then hands back a safe default instead of throwing.
/// `schedule` throws [LocalReminderScheduleRefused] so a refused reminder is
/// never recorded as sent.
final class NativeLocalReminderScheduler implements LocalReminderScheduler {
  NativeLocalReminderScheduler([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_handle);
  }

  static const channelName = 'app.critalarm/local_reminders';

  final MethodChannel _channel;
  final _taps = StreamController<LocalReminderTap>.broadcast();

  /// The platform holds a tap until Dart takes it and also sends it live,
  /// so one tap can arrive twice. Only the first copy counts.
  String? _lastTapId;

  static Map<String, Object?> encode(LocalReminderRequest request) => {
    'id': request.id,
    'kind': request.kind.wireName,
    'category': request.kind.categoryId,
    'channel': request.channelId,
    'year': request.fireAt.year,
    'month': request.fireAt.month,
    'day': request.fireAt.day,
    'hour': request.fireAt.hour,
    'minute': request.fireAt.minute,
    'second': request.fireAt.second,
    'title': request.title,
    'body': request.body,
    'hidden_preview': request.hiddenPreview,
    'face_asset': request.faceAsset,
    'actions': [for (final action in request.actions) action.toMap()],
    'payload': request.payload,
  };

  static Map<String, String> _strings(Object? raw) => raw is Map
      ? {
          for (final entry in raw.entries)
            if (entry.value != null) '${entry.key}': '${entry.value}',
        }
      : const {};

  static LocalReminderTap? decodeTap(Object? raw) {
    if (raw is! Map) return null;
    final wire = raw['kind'];
    final kind = wire is String ? LocalReminderKind.fromWire(wire) : null;
    final action = raw['action'];
    if (kind == null || action is! String?) return null;
    return LocalReminderTap(
      kind: kind,
      actionId: action ?? LocalReminderActionIds.open,
      payload: _strings(raw['payload']),
      tapId: raw['tap_id']?.toString(),
    );
  }

  static PendingReminder? decodePending(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! int) return null;
    final year = raw['year'];
    final month = raw['month'];
    final day = raw['day'];
    final hour = raw['hour'];
    final minute = raw['minute'];
    final second = raw['second'];
    final hasTime =
        year is int &&
        month is int &&
        day is int &&
        hour is int &&
        minute is int;
    // A bad kind still keeps the id, so a plan pass can cancel it.
    final kind = raw['kind'];
    return PendingReminder(
      id: id,
      kind: kind is String ? LocalReminderKind.fromWire(kind) : null,
      fireAt: hasTime
          ? DateTime(year, month, day, hour, minute, second is int ? second : 0)
          : null,
    );
  }

  @override
  Future<void> schedule(LocalReminderRequest request) async {
    Object? answer;
    try {
      answer = await _channel.invokeMethod<Object?>(
        'schedule',
        encode(request),
      );
    } on MissingPluginException {
      throw const LocalReminderScheduleRefused();
    } on PlatformException {
      throw const LocalReminderScheduleRefused();
    }
    // Both platforms answer true once the reminder is armed.
    if (answer != true) throw const LocalReminderScheduleRefused();
  }

  @override
  Future<void> cancel(List<int> ids) async {
    if (ids.isEmpty) return;
    await _invoke<Object?>('cancel', {'ids': ids});
  }

  @override
  Future<List<PendingReminder>> pending() async {
    final raw = await _invoke<List<Object?>>('pending');
    return [
      for (final item in raw ?? const <Object?>[]) ?decodePending(item),
    ];
  }

  @override
  Future<LocalReminderSystemState> systemState() async {
    final raw = await _invoke<Map<Object?, Object?>>('systemState');
    return LocalReminderSystemState(
      notificationsAllowed: raw?['notifications_allowed'] as bool? ?? true,
    );
  }

  @override
  Future<DeviceTimeZone> deviceTimeZone() async {
    final raw = await _invoke<Map<Object?, Object?>>('deviceTimeZone');
    final name = raw?['name'];
    final offset = raw?['offset_minutes'];
    if (name is String && offset is int) {
      return DeviceTimeZone(name: name, offsetMinutes: offset);
    }
    return DeviceTimeZone.fromDart();
  }

  @override
  Stream<LocalReminderTap> get taps => _taps.stream;

  @override
  Future<LocalReminderTap?> takePendingTap() async {
    final tap = decodeTap(await _invoke<Object?>('takePendingTap'));
    if (tap == null || _isRepeat(tap)) return null;
    return tap;
  }

  Future<void> _handle(MethodCall call) async {
    if (call.method != 'onReminderTap') return;
    final tap = decodeTap(call.arguments);
    if (tap == null || _isRepeat(tap)) return;
    _taps.add(tap);
  }

  bool _isRepeat(LocalReminderTap tap) {
    final id = tap.tapId;
    if (id == null) return false;
    if (id == _lastTapId) return true;
    _lastTapId = id;
    return false;
  }

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
