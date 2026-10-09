import 'dart:convert';

import 'package:critalarm/features/reliability/domain/proof/proof_entry.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_log_store.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_weeks.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the proof log under one prefs key, `proof_log`: a JSON list of
/// `{"w": "YYYY-MM-DD", "r": seconds, "f": seconds}`, with `r` and `f` left
/// out when there is no such time.
class SharedPrefsProofLogStore implements ProofLogStore {
  SharedPrefsProofLogStore(this._prefs);

  static const key = 'proof_log';

  final SharedPreferences _prefs;

  @override
  List<ProofEntry> read() {
    final raw = _prefs.getString(key);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      var entries = <ProofEntry>[];
      for (final item in decoded) {
        final entry = _entryFrom(item);
        if (entry != null) entries = proofMerge(entries, entry);
      }
      return entries;
    } on Object {
      return const [];
    }
  }

  @override
  Future<void> write(List<ProofEntry> entries) async {
    final kept = proofPrune(entries);
    await _prefs.setString(
      key,
      jsonEncode([
        for (final entry in kept)
          {
            'w': entry.key,
            if (entry.rangAt != null) 'r': _seconds(entry.rangAt!),
            if (entry.failedAt != null) 'f': _seconds(entry.failedAt!),
          },
      ]),
    );
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(key);
  }

  static int _seconds(DateTime at) => at.millisecondsSinceEpoch ~/ 1000;

  static ProofEntry? _entryFrom(Object? item) {
    if (item is! Map) return null;
    final week = proofWeekFromKey(item['w']);
    if (week == null) return null;
    DateTime? time(Object? value) => value is num
        ? DateTime.fromMillisecondsSinceEpoch(value.toInt() * 1000)
        : null;
    final rang = time(item['r']);
    final failed = time(item['f']);
    if (rang == null && failed == null) return null;
    return ProofEntry(weekStart: week, rangAt: rang, failedAt: failed);
  }
}
