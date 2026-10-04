import 'package:critalarm/features/topics/domain/first_message/first_message_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [FirstMessageStore] on the phone: the flag under
/// `first_message_received`, and one `first_message_since.<topic>` per
/// topic that was watched.
class PrefsFirstMessageStore implements FirstMessageStore {
  const PrefsFirstMessageStore(this._prefs);

  final SharedPreferences _prefs;

  static const receivedKey = 'first_message_received';
  static const cursorPrefix = 'first_message_since.';

  @override
  bool get isReceived => _prefs.getBool(receivedKey) ?? false;

  @override
  Future<void> markReceived() async {
    if (isReceived) return;
    await _prefs.setBool(receivedKey, true);
  }

  @override
  String? cursorFor(String topic) => _prefs.getString('$cursorPrefix$topic');

  @override
  Future<void> saveCursor(String topic, String cursor) =>
      _prefs.setString('$cursorPrefix$topic', cursor);

  @override
  Future<void> forgetTopic(String topic) =>
      _prefs.remove('$cursorPrefix$topic');
}
