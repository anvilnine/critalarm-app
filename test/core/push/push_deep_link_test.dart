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

  group('the marker a native Done button puts on its link', () {
    test('a tap map with it opens the incident, marked', () {
      final location = PushDeepLink.fromNotificationData({
        'incident_id': 'inc_1',
        'from': 'done',
        'tap_id': '4',
      })!;
      expect(location, '/incidents/inc_1?from=done');
      expect(PushDeepLink.cameFromDone(Uri.parse(location)), isTrue);
      expect(PushDeepLink.incidentIdIn(location), 'inc_1');
    });

    test('an app link with it opens the incident, marked', () {
      final location = PushDeepLink.fromAppUri(
        Uri.parse('critalarm://incidents/inc_1?from=done'),
      )!;
      expect(location, '/incidents/inc_1?from=done');
      expect(PushDeepLink.cameFromDone(Uri.parse(location)), isTrue);
    });

    test('a plain tap on a card carries none, in either form', () {
      final tapped = PushDeepLink.fromNotificationData({
        'incident_id': 'inc_1',
      })!;
      final linked = PushDeepLink.fromAppUri(
        Uri.parse('critalarm://incidents/inc_1'),
      )!;
      expect(tapped, '/incidents/inc_1');
      expect(linked, '/incidents/inc_1');
      expect(PushDeepLink.cameFromDone(Uri.parse(tapped)), isFalse);
      expect(PushDeepLink.cameFromDone(Uri.parse(linked)), isFalse);
    });

    test('no other word is the marker', () {
      expect(
        PushDeepLink.fromNotificationData({
          'incident_id': 'inc_1',
          'from': 'card',
        }),
        '/incidents/inc_1',
      );
      expect(
        PushDeepLink.fromAppUri(
          Uri.parse('critalarm://incidents/inc_1?from=card'),
        ),
        '/incidents/inc_1',
      );
      expect(
        PushDeepLink.cameFromDone(Uri.parse('/incidents/inc_1?from=card')),
        isFalse,
      );
    });

    test('it means nothing on a topic', () {
      expect(
        PushDeepLink.fromNotificationData({'topic': 'prod', 'from': 'done'}),
        '/topics/prod',
      );
      expect(
        PushDeepLink.fromAppUri(
          Uri.parse('critalarm://topics/prod?from=done'),
        ),
        '/topics/prod',
      );
    });

    test('the incident id never takes the marker with it', () {
      expect(PushDeepLink.incidentIdIn('/incidents/inc_1?from=done'), 'inc_1');
      expect(PushDeepLink.incidentIdIn('/incidents/inc_1'), 'inc_1');
      expect(PushDeepLink.incidentIdIn('/incidents/a%20b'), 'a b');
      expect(PushDeepLink.incidentIdIn('/alarm'), isNull);
      expect(PushDeepLink.incidentIdIn('/topics/prod'), isNull);
      expect(PushDeepLink.incidentIdIn('/incidents/'), isNull);
    });
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

  test('open=paywall opens the paywall', () {
    expect(
      PushDeepLink.fromNotificationData({'open': 'paywall'}),
      '/paywall?source=widget_locked',
    );
  });

  test('the locked widget link carries the widget_locked source tag', () {
    expect(PushDeepLink.paywallLocation, '/paywall?source=widget_locked');
    expect(
      PushDeepLink.tagged('/paywall'),
      '/paywall?source=widget_locked',
    );
  });

  group('fromAppUri', () {
    String? map(String u) => PushDeepLink.fromAppUri(Uri.parse(u));

    test('the demo incident tap URI opens the incident route', () {
      expect(map('critalarm://incidents/inc_demo'), '/incidents/inc_demo');
    });

    test('an incident id is escaped', () {
      expect(
        map('critalarm://incidents/inc%20a%2Fb'),
        '/incidents/inc%20a%2Fb',
      );
    });

    test('a topic URI opens that topic', () {
      expect(map('critalarm://topics/deploys'), '/topics/deploys');
    });

    test('a reminder URI opens Home', () {
      expect(map('critalarm://reminders/fire_drill/open'), '/');
    });

    test('a bare or unknown critalarm URI opens Home', () {
      expect(map('critalarm://incidents'), '/');
      expect(map('critalarm://other/x'), '/');
    });

    test('a normal location is left alone', () {
      expect(map('/incidents/inc_1'), isNull);
      expect(map('/'), isNull);
      expect(map('https://example.com/incidents/x'), isNull);
    });
  });
}
