import 'package:critalarm/features/topics/domain/first_topic_handoff.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [FirstTopicHandoff] with the entry in memory and only the topic name on
/// the phone, under `onboarding_first_topic`. The id of a token the last
/// step made is under `onboarding_hook_up_token_id`.
class PrefsFirstTopicHandoff implements FirstTopicHandoff {
  PrefsFirstTopicHandoff(this._prefs);

  final SharedPreferences _prefs;

  static const topicNameKey = 'onboarding_first_topic';
  static const mintedTokenIdKey = 'onboarding_hook_up_token_id';

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
  String? get mintedTokenId {
    final id = _prefs.getString(mintedTokenIdKey);
    return id == null || id.isEmpty ? null : id;
  }

  @override
  Future<void> saveMintedTokenId(String tokenId) =>
      _prefs.setString(mintedTokenIdKey, tokenId);

  /// The token the id names stays on the server: once setup is over it is
  /// the user's own, in whatever they pasted the line into.
  @override
  Future<void> clear() async {
    _entry = null;
    await _prefs.remove(topicNameKey);
    await _prefs.remove(mintedTokenIdKey);
  }
}
