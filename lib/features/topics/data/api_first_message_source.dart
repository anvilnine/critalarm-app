import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/features/local_reminders/domain/incident_kinds.dart';
import 'package:critalarm/features/topics/domain/first_message/first_message_source.dart';

/// [FirstMessageSource] over the poll route (api.md 2), with the credential
/// the app already holds.
///
/// A message is turned into its id here and the rest of it is dropped, so
/// nothing past this class can show, store or log a title or a body.
///
/// A test alarm is left out of the candidates: the one setup sends, and any
/// sent later from Settings. Every one of them carries the title the test
/// route gives its message (api.md 3.3), which is how the rest of the app
/// tells a test too. The title is compared here and goes no further.
class ApiFirstMessageSource implements FirstMessageSource {
  const ApiFirstMessageSource({required this._api});

  final ApiClient _api;

  @override
  Future<FirstMessagePage> read(String topic, String since) async {
    final messages = await _api.pollMessages(topic, poll: 1, since: since);
    if (messages.isEmpty) return const FirstMessagePage.empty();
    return FirstMessagePage(
      candidates: [
        for (final message in messages)
          if (message.event == 'message' &&
              message.title != IncidentKinds.testAlarmTitle)
            message.id,
      ],
      // The route answers oldest first.
      newestId: messages.last.id,
    );
  }
}
