import 'package:critalarm/core/push/incident_push.dart';
import 'package:critalarm/core/push/push_deep_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a push with an incident opens that incident', () {
    final push = IncidentPush.fromFcmData({
      'incident_id': 'inc_9a8b7c',
      'server': 'https://alerts.example.com',
      'kind': 'open',
      'priority': '5',
    })!;
    expect(PushDeepLink.forPush(push), '/incidents/inc_9a8b7c');
  });

  test('a p4 forward has nothing specific to open', () {
    final push = IncidentPush.fromFcmData({
      'server': 'https://alerts.example.com',
      'kind': 'p4',
      'priority': '4',
    })!;
    expect(PushDeepLink.forPush(push), isNull);
  });

  test('an incident id wins over a topic', () {
    expect(
      PushDeepLink.fromNotificationData({
        'incident_id': 'inc_1',
        'topic': 'prod',
      }),
      '/incidents/inc_1',
    );
  });

  test('a priority 1-3 notification opens its topic', () {
    expect(
      PushDeepLink.fromNotificationData({'topic': 'prod'}),
      '/topics/prod',
    );
  });

  test('ids and topic names are escaped', () {
    expect(
      PushDeepLink.fromNotificationData({'topic': 'my topic/x'}),
      '/topics/my%20topic%2Fx',
    );
    expect(PushDeepLink.incidentLocation('inc 1'), '/incidents/inc%201');
  });

  test('empty values are the same as absent', () {
    expect(
      PushDeepLink.fromNotificationData({'incident_id': '', 'topic': ''}),
      isNull,
    );
    expect(PushDeepLink.fromNotificationData({}), isNull);
  });

  test('the open count widget opens Home', () {
    expect(PushDeepLink.fromNotificationData({'open': 'home'}), '/');
  });

  test('an incident or topic still wins over open=home', () {
    expect(
      PushDeepLink.fromNotificationData({'open': 'home', 'topic': 'prod'}),
      '/topics/prod',
    );
  });

  test('any other open value opens nothing', () {
    expect(PushDeepLink.fromNotificationData({'open': 'settings'}), isNull);
  });
}
