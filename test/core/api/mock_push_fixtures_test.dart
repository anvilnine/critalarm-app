import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/push/incident_push.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockServer server;

  setUp(() => server = MockServer());

  test('the ladder has one message at every priority', () {
    final messages = server.seedPriorityLadder();
    expect(messages.map((m) => m.priority), [1, 2, 3, 4, 5]);
    expect(messages.last.incidentId, isNotNull);
    expect(messages[3].incidentId, isNull);
  });

  test('priority 1-3 has no push payload', () {
    for (final message in server.seedPriorityLadder().take(3)) {
      expect(server.pushPayloadFor(message), isNull);
    }
  });

  test('priority 4 becomes a p4 forward with no incident', () {
    final message = server.seedPriorityLadder()[3];
    final push = IncidentPush.fromFcmData(server.pushPayloadFor(message)!)!;
    expect(push.kind, IncidentPushKind.p4);
    expect(push.priority, 4);
    expect(push.incidentId, isNull);
    expect(push.needsContentFetch, isTrue);
  });

  test('priority 5 on a critical topic opens an incident', () {
    final message = server.seedPriorityLadder().last;
    final push = IncidentPush.fromFcmData(server.pushPayloadFor(message)!)!;
    expect(push.kind, IncidentPushKind.open);
    expect(push.priority, 5);
    expect(push.incidentId, message.incidentId);
    expect(push.isIncident, isTrue);
  });

  test('relay_content full carries the text with it', () {
    final message = server.seedPriorityLadder().last;
    final push = IncidentPush.fromFcmData(
      server.pushPayloadFor(message, relayContentFull: true)!,
    )!;
    expect(push.title, 'Database down');
    expect(push.body, startsWith('db01 is unreachable'));
    expect(push.needsContentFetch, isFalse);
  });

  test('the repeat and reopen kinds reuse the same incident', () {
    final message = server.seedPriorityLadder().last;
    for (final kind in ['repeat', 'reopen']) {
      final push = IncidentPush.fromFcmData(
        server.pushPayloadFor(message, kind: kind)!,
      )!;
      expect(push.kind.name, kind);
      expect(push.incidentId, message.incidentId);
    }
  });

  test('a failed fetch answers 503 instead of the incident', () {
    final message = server.seedPriorityLadder().last;
    final id = message.incidentId!;
    expect(server.getIncident(id).id, id);

    server.failIncidentFetch = true;
    expect(
      () => server.getIncident(id),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 503),
      ),
    );

    server.failIncidentFetch = false;
    expect(server.getIncident(id).id, id);
  });

  test('the incident carries the tags and click for rich rendering', () {
    final message = server.seedPriorityLadder().last;
    final incident = server.getIncident(message.incidentId!);
    final newest = incident.messages.last;
    expect(newest.tags, ['rotating_light', 'db01']);
    expect(newest.click, 'https://status.example.com/db01');
  });
}
