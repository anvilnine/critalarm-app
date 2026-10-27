import 'dart:convert';

import 'package:critalarm/core/alarm/alarm_signals.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the per-topic flash and strong vibration switches, on this phone
/// only.
///
/// Each switch is one preference row holding a JSON list of topic names. A
/// topic that is not in the list is off, so a new topic and a fresh install
/// both start with neither. The alarm rings with no Dart running, so the
/// native side reads the same two rows: `AlarmSignalStore.kt` on Android and
/// `AlarmSignalStore` in `AppDelegate.swift` on iOS. Keep the keys in step.
final class AlarmSignalStore {
  const AlarmSignalStore(this._prefs);

  /// Plain preference keys. The `shared_preferences` plugin stores them with
  /// a `flutter.` prefix on both platforms.
  static const String flashKey = 'alarm_flash_topics';
  static const String vibrationKey = 'alarm_strong_vibration_topics';

  final SharedPreferences _prefs;

  /// Reads without waiting. Anything missing or unreadable is off.
  AlarmSignals read() => AlarmSignals(
    flashTopics: _readTopics(flashKey),
    vibrationTopics: _readTopics(vibrationKey),
  );

  /// False when the phone could not save it.
  Future<bool> setFlash(String topic, {required bool on}) => _writeTopics(
    flashKey,
    read().withFlash(topic, on: on).flashTopics,
  );

  /// False when the phone could not save it.
  Future<bool> setStrongVibration(String topic, {required bool on}) =>
      _writeTopics(
        vibrationKey,
        read().withVibration(topic, on: on).vibrationTopics,
      );

  Set<String> _readTopics(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return const <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <String>{};
      return {
        for (final item in decoded)
          if (item is String && item.isNotEmpty) item,
      };
    } on FormatException {
      return const <String>{};
    }
  }

  Future<bool> _writeTopics(String key, Set<String> topics) =>
      _prefs.setString(key, jsonEncode(topics.toList()..sort()));
}
