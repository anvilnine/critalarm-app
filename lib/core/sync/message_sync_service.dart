import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Catches the app up on the messages push never delivers.
///
/// api.md §1.7 keeps priority 1-3 off the relay entirely, so the only way to
/// see them is `GET /{topic}/json?poll=1&since=<last id>` (§2). This runs when
/// the app opens and when the user pulls to refresh. Nothing here runs in the
/// background: a timer that polls while the app is closed would drain the
/// battery for messages that are, by definition, not urgent.
final class MessageSyncService {
  MessageSyncService(this._prefs, this._api);

  static const _lastIdPrefix = 'msg_sync_last_id.';

  /// Highest priority this service is responsible for. 4 and 5 arrive as push.
  static const maxPolledPriority = 3;

  final SharedPreferences _prefs;
  final ApiClient _api;

  /// Id of the newest message already seen on [topic], or null on first run.
  String? lastMessageId(String topic) =>
      _prefs.getString('$_lastIdPrefix$topic');

  /// Polls one topic and returns the priority 1-3 messages that are new.
  ///
  /// The cursor moves to the newest message the server returned, including any
  /// priority 4-5 rows, so a later poll does not walk over them again.
  Future<List<Message>> syncTopic(String topic) async {
    final since = lastMessageId(topic);
    final messages = await _api.pollMessages(
      topic,
      poll: 1,
      since: since,
    );
    if (messages.isEmpty) return const [];
    await _prefs.setString('$_lastIdPrefix$topic', messages.last.id);
    return messages
        .where((message) => message.priority <= maxPolledPriority)
        .toList();
  }

  /// Polls every topic. One topic failing does not stop the rest.
  Future<Map<String, List<Message>>> syncAll(Iterable<String> topics) async {
    final results = <String, List<Message>>{};
    for (final topic in topics) {
      try {
        final fresh = await syncTopic(topic);
        if (fresh.isNotEmpty) results[topic] = fresh;
      } on Object catch (_) {
        // Skip this topic; the next refresh picks it up from the same cursor.
      }
    }
    return results;
  }

  /// Forgets the cursor for [topic], so the next poll uses the server default
  /// of the last 12 hours.
  Future<void> resetCursor(String topic) async {
    await _prefs.remove('$_lastIdPrefix$topic');
  }
}
