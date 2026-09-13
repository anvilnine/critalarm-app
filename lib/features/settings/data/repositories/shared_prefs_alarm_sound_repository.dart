import 'dart:convert';

import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/bundled_sounds.dart';
import 'package:critalarm/core/sound/sound_assignments.dart';
import 'package:critalarm/features/settings/domain/repositories/alarm_sound_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the sound choices in `SharedPreferences`, on the device only.
class SharedPrefsAlarmSoundRepository implements AlarmSoundRepository {
  const SharedPrefsAlarmSoundRepository(this._prefs);

  final SharedPreferences _prefs;

  static const defaultKey = 'alarm_sound_default';
  static const perTopicKey = 'alarm_sound_per_topic';
  static const userSoundsKey = 'alarm_sound_user_list';

  @override
  Future<AppResult<SoundAssignments>> getAssignments() async =>
      _readAssignments().toSuccess();

  @override
  Future<AppResult<Unit>> setDefaultSoundId(String soundId) =>
      _write(_readAssignments().withDefault(soundId));

  @override
  Future<AppResult<Unit>> setTopicSoundId(
    String topicName,
    String? soundId,
  ) => _write(_readAssignments().withTopicSound(topicName, soundId));

  @override
  Future<AppResult<List<AlarmSound>>> getUserSounds() async =>
      _readUserSounds().toSuccess();

  @override
  Future<AppResult<Unit>> addUserSound(AlarmSound sound) async {
    final next = [..._readUserSounds().where((s) => s.id != sound.id), sound];
    return _writeUserSounds(next);
  }

  @override
  Future<AppResult<Unit>> deleteUserSound(String soundId) async {
    final written = await _writeUserSounds(
      _readUserSounds().where((s) => s.id != soundId).toList(),
    );
    if (written.isError()) return written;
    // The fallback rule. Anything still pointing at the deleted sound moves,
    // so nothing is left holding an id that no longer resolves.
    return _write(
      _readAssignments().withSoundDeleted(
        soundId,
        fallbackSoundId: BundledSounds.fallbackId,
      ),
    );
  }

  SoundAssignments _readAssignments() {
    final stored = _prefs.getString(defaultKey);
    final defaultId = stored != null && stored.isNotEmpty
        ? stored
        : BundledSounds.fallbackId;
    return SoundAssignments(
      defaultSoundId: defaultId,
      perTopic: _readPerTopic(),
    );
  }

  Map<String, String> _readPerTopic() {
    final raw = _prefs.getString(perTopicKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return {
        for (final entry in decoded.entries)
          if (entry.key is String && entry.value is String)
            entry.key as String: entry.value as String,
      };
    } on FormatException {
      return const {};
    }
  }

  List<AlarmSound> _readUserSounds() {
    final raw = _prefs.getString(userSoundsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map<String, dynamic>) AlarmSound.fromJson(item),
      ];
    } on Object catch (_) {
      // A half-written or hand-edited list is treated as empty rather than
      // taking the picker down with it.
      return const [];
    }
  }

  Future<AppResult<Unit>> _write(SoundAssignments assignments) async {
    final savedDefault = await _prefs.setString(
      defaultKey,
      assignments.defaultSoundId,
    );
    final savedTopics = await _prefs.setString(
      perTopicKey,
      jsonEncode(assignments.perTopic),
    );
    if (!savedDefault || !savedTopics) {
      return const Failure.database(
        message: 'Could not save the alarm sound choice.',
      ).toFailure<Unit>();
    }
    return unit.toSuccess();
  }

  Future<AppResult<Unit>> _writeUserSounds(List<AlarmSound> sounds) async {
    final saved = await _prefs.setString(
      userSoundsKey,
      jsonEncode([for (final s in sounds) s.toJson()]),
    );
    if (!saved) {
      return const Failure.database(
        message: 'Could not save the imported sound.',
      ).toFailure<Unit>();
    }
    return unit.toSuccess();
  }
}
