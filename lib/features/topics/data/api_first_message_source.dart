import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/features/topics/domain/first_message/first_message_source.dart';

/// [FirstMessageSource] over the poll route (api.md 2) and the incident
/// route (api.md 3.2), with the credential the app already holds.
///
/// A message is turned into its id here and the rest of it is dropped, so
/// nothing past this class can show, store or log a title or a body.
class ApiFirstMessageSource implements FirstMessageSource {
  const ApiFirstMessageSource({
    required this._api,
    required this._testIncidentIds,
  });

  final ApiClient _api;

  /// The incidents of the test alarms setup asked the server to send.
  final Set<String> Function() _testIncidentIds;

  @override
  Future<List<String>> newerThan(String topic, String since) async {
    final messages = await _api.pollMessages(topic, poll: 1, since: since);
    return [
      for (final message in messages)
        if (message.event == 'message') message.id,
    ];
  }

  /// The test route answers an incident id, not a message id, so the
  /// message is read from the incident.
  @override
  Future<FirstMessageBaseline> testBaseline() async {
    Message? newest;
    for (final id in _testIncidentIds()) {
      final List<Message> messages;
      try {
        messages = (await _api.getIncident(id)).messages;
      } on ApiException catch (error) {
        // Gone from the server, so there is no message of it to skip.
        if (error.statusCode == 404) continue;
        rethrow;
      }
      for (final message in messages) {
        if (newest == null || message.time >= newest.time) newest = message;
      }
    }
    return newest == null
        ? const FirstMessageBaseline.noTest()
        : FirstMessageBaseline.after(newest.id);
  }
}
