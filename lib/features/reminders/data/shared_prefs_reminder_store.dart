import 'dart:convert';

import 'package:critalarm/features/reminders/domain/planned_record.dart';
import 'package:critalarm/features/reminders/domain/reminder_store.dart';
import 'package:critalarm/features/reminders/domain/reminder_switches.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsReminderStore implements ReminderStore {
  const SharedPrefsReminderStore(this._prefs);

  final SharedPreferences _prefs;

  static const remindersKey = 'reminder_switch_reminders';
  static const offersKey = 'reminder_switch_offers';
  static const lastTestKey = 'reminder_last_test_at';
  static const lastTestFailedKey = 'reminder_last_test_failed_at';
  static const drillLastIndexKey = 'reminder_drill_last_index';
  static const sheetShownKey = 'reminder_sheet_shown';
  static const budgetSpentKey = 'reminder_budget_spent_at';
  static const plannedKey = 'reminder_planned';
  static const reviewFireKey = 'reminder_review_fire_at';
  static const feedbackFireKey = 'reminder_feedback_fire_at';
  static const createdHereKey = 'reminder_topics_created_here';
  static const silentDoneKey = 'reminder_silent_done';
  static const planNoticesKey = 'reminder_plan_notices_sent';
  static const morningAfterDoneKey = 'reminder_morning_after_done';
  static const proSheetOwedKey = 'reminder_pro_sheet_owed';
  static const skipRulesKey = 'reminder_skip_rules';

  /// Written by native code as `flutter.reminder_pending_pro_dismiss`.
  static const pendingProDismissKey = 'reminder_pending_pro_dismiss';

  static const List<String> allKeys = [
    remindersKey,
    offersKey,
    lastTestKey,
    lastTestFailedKey,
    drillLastIndexKey,
    sheetShownKey,
    budgetSpentKey,
    plannedKey,
    reviewFireKey,
    feedbackFireKey,
    createdHereKey,
    silentDoneKey,
    planNoticesKey,
    morningAfterDoneKey,
    proSheetOwedKey,
    skipRulesKey,
    pendingProDismissKey,
  ];

  DateTime? _readTime(String key) {
    final ms = _prefs.getInt(key);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  Future<void> _writeTime(String key, DateTime? at) => at == null
      ? _prefs.remove(key)
      : _prefs.setInt(key, at.millisecondsSinceEpoch);

  Map<String, DateTime> _readTimes(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          if (entry.key is String && entry.value is int)
            entry.key as String: DateTime.fromMillisecondsSinceEpoch(
              entry.value as int,
            ),
      };
    } on FormatException {
      return {};
    }
  }

  Future<void> _writeTimes(String key, Map<String, DateTime> times) =>
      _prefs.setString(
        key,
        jsonEncode({
          for (final entry in times.entries)
            entry.key: entry.value.millisecondsSinceEpoch,
        }),
      );

  Set<String> _readSet(String key) =>
      (_prefs.getStringList(key) ?? const <String>[]).toSet();

  Future<void> _addToSet(String key, String value) =>
      _prefs.setStringList(key, {..._readSet(key), value}.toList());

  @override
  Future<void> reload() => _prefs.reload();

  @override
  ReminderSwitches readSwitches() => ReminderSwitches(
    reminders:
        _prefs.getBool(remindersKey) ?? ReminderSwitches.defaults.reminders,
    offers: _prefs.getBool(offersKey) ?? ReminderSwitches.defaults.offers,
  );

  @override
  Future<void> writeSwitches(ReminderSwitches switches) async {
    await _prefs.setBool(remindersKey, switches.reminders);
    await _prefs.setBool(offersKey, switches.offers);
  }

  @override
  Map<String, DateTime> readLastTestAt() => _readTimes(lastTestKey);

  @override
  Future<void> markTested(String topic, DateTime at) =>
      _writeTimes(lastTestKey, {...readLastTestAt(), topic: at});

  @override
  DateTime? readLastTestFailedAt() => _readTime(lastTestFailedKey);

  @override
  Future<void> markTestFailed(DateTime at) => _writeTime(lastTestFailedKey, at);

  @override
  int? readDrillLastIndex() => _prefs.getInt(drillLastIndexKey);

  @override
  Future<void> writeDrillLastIndex(int index) =>
      _prefs.setInt(drillLastIndexKey, index);

  @override
  bool readSheetShown() => _prefs.getBool(sheetShownKey) ?? false;

  @override
  Future<void> markSheetShown() => _prefs.setBool(sheetShownKey, true);

  @override
  DateTime? readBudgetSpentAt() => _readTime(budgetSpentKey);

  @override
  Future<void> writeBudgetSpentAt(DateTime at) =>
      _writeTime(budgetSpentKey, at);

  @override
  List<PlannedRecord> readPlanned() {
    final raw = _prefs.getString(plannedKey);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          ?PlannedRecord.tryParse(item),
      ];
    } on FormatException {
      return const [];
    }
  }

  @override
  Future<void> writePlanned(List<PlannedRecord> records) => _prefs.setString(
    plannedKey,
    jsonEncode([for (final record in records) record.toJson()]),
  );

  @override
  DateTime? readReviewFireAt() => _readTime(reviewFireKey);

  @override
  Future<void> writeReviewFireAt(DateTime? at) => _writeTime(reviewFireKey, at);

  @override
  DateTime? readFeedbackFireAt() => _readTime(feedbackFireKey);

  @override
  Future<void> writeFeedbackFireAt(DateTime? at) =>
      _writeTime(feedbackFireKey, at);

  @override
  Map<String, DateTime> readTopicsCreatedHere() => _readTimes(createdHereKey);

  @override
  Future<void> recordTopicCreatedHere(String topic, DateTime at) =>
      _writeTimes(createdHereKey, {...readTopicsCreatedHere(), topic: at});

  @override
  Set<String> readSilentDone() => _readSet(silentDoneKey);

  @override
  Future<void> addSilentDone(String topic) => _addToSet(silentDoneKey, topic);

  @override
  Set<String> readPlanNoticesSent() => _readSet(planNoticesKey);

  @override
  Future<void> addPlanNoticeSent(String key) => _addToSet(planNoticesKey, key);

  @override
  Set<String> readMorningAfterDone() => _readSet(morningAfterDoneKey);

  @override
  Future<void> addMorningAfterDone(String incidentId) =>
      _addToSet(morningAfterDoneKey, incidentId);

  @override
  bool readProSheetOwed() => _prefs.getBool(proSheetOwedKey) ?? false;

  @override
  Future<void> writeProSheetOwed({required bool owed}) =>
      _prefs.setBool(proSheetOwedKey, owed);

  @override
  bool readSkipRules() => _prefs.getBool(skipRulesKey) ?? false;

  @override
  Future<void> writeSkipRules({required bool skip}) =>
      _prefs.setBool(skipRulesKey, skip);

  @override
  Future<bool> takePendingProDismiss() async {
    final isPending = _prefs.getBool(pendingProDismissKey) ?? false;
    if (isPending) await _prefs.remove(pendingProDismissKey);
    return isPending;
  }

  @override
  Future<void> resetAll() async {
    for (final key in allKeys) {
      await _prefs.remove(key);
    }
  }
}
