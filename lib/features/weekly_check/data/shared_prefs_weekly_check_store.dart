import 'dart:convert';

import 'package:critalarm/core/models/weekly_check.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [WeeklyCheckStore] in the app's preferences.
///
/// [arrivalKey] is written by native code only: `WeeklyCheckResponder` on
/// both platforms, which answers a check push with no Dart running. Dart
/// reads it and never writes it, except to remove it.
final class SharedPrefsWeeklyCheckStore implements WeeklyCheckStore {
  const SharedPrefsWeeklyCheckStore(this._prefs);

  static const checkKey = 'weekly_check.kept';
  static const dismissedKey = 'weekly_check.notice_dismissed_at';
  static const planAwayKey = 'weekly_check.plan_away_at';

  /// Keep in step with `WeeklyCheckResponder.kt` and
  /// `WeeklyCheckResponder.swift`, which add the `flutter.` prefix the
  /// shared_preferences plugin puts on every key it owns.
  static const arrivalKey = 'weekly_check.native';

  final SharedPreferences _prefs;

  @override
  KeptWeeklyCheck? readCheck() {
    final json = _decode(_prefs.getString(checkKey));
    final check = json?['check'];
    final seenAt = json?['seen_at'];
    if (check is! Map<String, dynamic> || seenAt is! int) return null;
    final deviceId = json?['device_id'];
    return KeptWeeklyCheck(
      check: WeeklyCheck.fromJson(check),
      seenAt: seenAt,
      deviceId: deviceId is String ? deviceId : null,
    );
  }

  @override
  Future<void> writeCheck(KeptWeeklyCheck kept) => _prefs.setString(
    checkKey,
    jsonEncode({
      'check': kept.check.toJson(),
      'seen_at': kept.seenAt,
      'device_id': kept.deviceId,
    }),
  );

  @override
  Future<WeeklyCheckArrival?> readArrival() async {
    // Native code wrote this behind the plugin's back, so what Dart holds
    // in memory can be stale.
    await _prefs.reload();
    final json = _decode(_prefs.getString(arrivalKey));
    if (json == null) return null;
    int? seconds(String key) {
      final value = json[key];
      return value is num ? value.toInt() : null;
    }

    return WeeklyCheckArrival(
      receivedAt: seconds('received_at'),
      noticeAfter: seconds('notice_after'),
      noticeAfterSeenAt: seconds('notice_after_seen_at'),
      nextDueAt: seconds('next_due_at'),
    );
  }

  @override
  int? readDismissedAt() => _prefs.getInt(dismissedKey);

  @override
  Future<void> writeDismissedAt(int at) => _prefs.setInt(dismissedKey, at);

  @override
  int? readPlanAwayAt() => _prefs.getInt(planAwayKey);

  @override
  Future<void> writePlanAwayAt(int at) => _prefs.setInt(planAwayKey, at);

  @override
  Future<void> clear() async {
    await _prefs.remove(checkKey);
    await _prefs.remove(dismissedKey);
    await _prefs.remove(planAwayKey);
    await _prefs.remove(arrivalKey);
  }

  /// A value that does not read back is the same as none.
  static Map<String, dynamic>? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      return json is Map<String, dynamic> ? json : null;
    } on FormatException {
      return null;
    }
  }
}
