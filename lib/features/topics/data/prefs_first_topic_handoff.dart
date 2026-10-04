import 'package:critalarm/features/topics/domain/first_topic_handoff.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [FirstTopicHandoff] with the entry in memory and only the topic name on
/// the phone, under `onboarding_first_topic`.
class PrefsFirstTopicHandoff implements FirstTopicHandoff {
  PrefsFirstTopicHandoff(this._prefs);

  final SharedPreferences _prefs;

  static const topicNameKey = 'onboarding_first_topic';

  FirstTopicHandoffEntry? _entry;

  @override
  FirstTopicHandoffEntry? get entry => _entry;

  @override
  String? get savedTopicName => _prefs.getString(topicNameKey);

  @override
  Future<void> hold(FirstTopicHandoffEntry entry) async {
    _entry = entry;
    await _prefs.setString(topicNameKey, entry.topicName);
  }

  @override
  Future<void> clear() async {
    _entry = null;
    await _prefs.remove(topicNameKey);
  }
}
