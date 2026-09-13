import 'dart:convert';
import 'dart:io';

import 'package:critalarm/core/push/incident_push.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FCM data (api.md 5.2)', () {
    final fixture =
        jsonDecode(
              File(
                'test/fixtures/android_delivery_cases.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;

    for (final vector in fixture['payloads'] as List<dynamic>) {
      final testCase = vector as Map<String, dynamic>;
      test(testCase['name'] as String, () {
        final data = (testCase['data'] as Map<String, dynamic>)
            .cast<String, String>();
        expect(IncidentPush.fromFcmData(data) != null, testCase['valid']);
      });
    }

    test('every field lands on the model', () {
      final push = IncidentPush.fromFcmData({
        'incident_id': 'inc_9a8b7c',
        'server': 'https://alerts.example.com',
        'kind': 'open',
        'priority': '5',
        'title': 'Uptime Kuma',
        'body': 'db01 is down',
      })!;
      expect(push.incidentId, 'inc_9a8b7c');
      expect(push.server, Uri.parse('https://alerts.example.com'));
      expect(push.kind, IncidentPushKind.open);
      expect(push.priority, 5);
      expect(push.title, 'Uptime Kuma');
      expect(push.body, 'db01 is down');
      expect(push.needsContentFetch, isFalse);
      expect(push.isIncident, isTrue);
    });

    test('relay_content none leaves the text to be fetched', () {
      final push = IncidentPush.fromFcmData({
        'incident_id': 'inc_1',
        'server': 'https://alerts.example.com',
        'kind': 'open',
        'priority': '5',
      })!;
      expect(push.title, isNull);
      expect(push.body, isNull);
      expect(push.needsContentFetch, isTrue);
    });

    test('empty strings count as absent', () {
      final push = IncidentPush.fromFcmData({
        'incident_id': 'inc_1',
        'server': 'https://alerts.example.com',
        'kind': 'open',
        'priority': '5',
        'title': '',
        'body': '',
      })!;
      expect(push.title, isNull);
      expect(push.body, isNull);
    });

    test('priority is required on FCM', () {
      expect(
        IncidentPush.fromFcmData({
          'incident_id': 'inc_1',
          'server': 'https://alerts.example.com',
          'kind': 'open',
        }),
        isNull,
      );
    });

    for (final kind in IncidentPushKind.values) {
      test('kind ${kind.name} parses', () {
        final push = IncidentPush.fromFcmData({
          if (kind != IncidentPushKind.p4) 'incident_id': 'inc_1',
          'server': 'https://alerts.example.com',
          'kind': kind.name,
          'priority': '${kind.impliedPriority}',
        })!;
        expect(push.kind, kind);
        expect(push.isIncident, kind != IncidentPushKind.p4);
      });
    }

    test('a p4 forward carries no incident id', () {
      final push = IncidentPush.fromFcmData({
        'server': 'https://alerts.example.com',
        'kind': 'p4',
        'priority': '4',
      })!;
      expect(push.incidentId, isNull);
      expect(push.isIncident, isFalse);
    });

    test('open without an incident id is not routable', () {
      expect(
        IncidentPush.fromFcmData({
          'server': 'https://alerts.example.com',
          'kind': 'open',
          'priority': '5',
        }),
        isNull,
      );
    });

    test('a server that is not http or https is rejected', () {
      for (final server in ['javascript:alert(1)', 'ftp://x', '', 'nonsense']) {
        expect(
          IncidentPush.fromFcmData({
            'incident_id': 'inc_1',
            'server': server,
            'kind': 'open',
            'priority': '5',
          }),
          isNull,
          reason: server,
        );
      }
    });

    test('priority outside 1-5 is rejected', () {
      for (final priority in ['0', '6', '-1', 'urgent']) {
        expect(
          IncidentPush.fromFcmData({
            'incident_id': 'inc_1',
            'server': 'https://alerts.example.com',
            'kind': 'open',
            'priority': priority,
          }),
          isNull,
          reason: priority,
        );
      }
    });
  });

  group('APNs custom keys (api.md 5.1)', () {
    Map<String, dynamic> payload({
      String kind = 'open',
      String? incidentId = 'inc_9a8b7c',
      String? title,
      String? body,
      bool mutableContent = true,
    }) => {
      'aps': {
        'alert': {'title': ?title, 'body': ?body},
        'interruption-level': 'critical',
        if (mutableContent) 'mutable-content': 1,
        'category': 'INCIDENT',
      },
      'incident_id': ?incidentId,
      'server': 'https://alerts.example.com',
      'kind': kind,
    };

    test('custom keys and the aps alert land on the same model', () {
      final push = IncidentPush.fromApnsPayload(
        payload(title: 'Crit Alarm', body: 'Critical alert on prod'),
      )!;
      expect(push.incidentId, 'inc_9a8b7c');
      expect(push.server, Uri.parse('https://alerts.example.com'));
      expect(push.kind, IncidentPushKind.open);
      expect(push.title, 'Crit Alarm');
      expect(push.body, 'Critical alert on prod');
    });

    test('priority comes from the kind, since APNs carries none', () {
      expect(IncidentPush.fromApnsPayload(payload())!.priority, 5);
      expect(
        IncidentPush.fromApnsPayload(
          payload(kind: 'p4', incidentId: null),
        )!.priority,
        4,
      );
    });

    for (final kind in IncidentPushKind.values) {
      test('kind ${kind.name} parses', () {
        final push = IncidentPush.fromApnsPayload(
          payload(
            kind: kind.name,
            incidentId: kind == IncidentPushKind.p4 ? null : 'inc_1',
          ),
        )!;
        expect(push.kind, kind);
        expect(push.priority, kind.impliedPriority);
      });
    }

    test('mutable-content marks the alert text as a placeholder', () {
      final push = IncidentPush.fromApnsPayload(
        payload(title: 'Crit Alarm', body: 'Critical alert on prod'),
      )!;
      expect(push.mutableContent, isTrue);
      expect(push.needsContentFetch, isTrue);
    });

    test('relay_content full drops mutable-content and keeps its text', () {
      final push = IncidentPush.fromApnsPayload(
        payload(
          title: 'Database down',
          body: 'db01 is unreachable',
          mutableContent: false,
        ),
      )!;
      expect(push.mutableContent, isFalse);
      expect(push.needsContentFetch, isFalse);
      expect(push.title, 'Database down');
    });

    test('an unknown kind is rejected', () {
      expect(IncidentPush.fromApnsPayload(payload(kind: 'closed')), isNull);
    });

    test('a missing aps block still parses the custom keys', () {
      final push = IncidentPush.fromApnsPayload({
        'incident_id': 'inc_1',
        'server': 'https://alerts.example.com',
        'kind': 'repeat',
      })!;
      expect(push.title, isNull);
      expect(push.needsContentFetch, isTrue);
    });
  });
}
