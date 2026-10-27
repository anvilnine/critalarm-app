import 'dart:convert';

import 'package:critalarm/features/in_app_notices/domain/cancel_question/cancel_answer.dart';
import 'package:critalarm/features/in_app_notices/domain/cancel_question/cancel_answer_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsCancelAnswerStore implements CancelAnswerStore {
  const SharedPrefsCancelAnswerStore(this._prefs);

  final SharedPreferences _prefs;

  static const _askedKey = 'cancel_question_asked_for';
  static const _pendingKey = 'cancel_question_pending_v1';

  @override
  String? readAskedFor() => _prefs.getString(_askedKey);

  @override
  Future<void> writeAskedFor(String key) => _prefs.setString(_askedKey, key);

  @override
  List<CancelAnswer> readPending() {
    try {
      final raw = _prefs.getString(_pendingKey);
      if (raw == null) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded) ?CancelAnswer.fromJson(item),
      ];
    } on Object catch (_) {
      // A value of another type under the key, or text that is not JSON.
      return const [];
    }
  }

  @override
  Future<void> writePending(List<CancelAnswer> entries) async {
    if (entries.isEmpty) {
      await _prefs.remove(_pendingKey);
      return;
    }
    await _prefs.setString(
      _pendingKey,
      jsonEncode([for (final entry in entries) entry.toJson()]),
    );
  }
}
