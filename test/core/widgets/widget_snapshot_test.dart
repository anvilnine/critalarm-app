import 'dart:convert';
import 'dart:io';

import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/widgets/widget_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.fromMillisecondsSinceEpoch(
  1759046400 * 1000,
  isUtc: true,
);

DateTime _at(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

Incident _incident(
  String id, {
  String topic = 'prod',
  String state = IncidentStates.open,
  int openedAt = 1759046000,
  int? ackedAt,
  List<Message> messages = const [],
}) => Incident(
  id: id,
  topic: topic,
  state: state,
  openedAt: _at(openedAt),
  ackedAt: ackedAt == null ? null : _at(ackedAt),
  messages: messages,
);

Message _message({String? title, String message = 'body', int time = 0}) =>
    Message(
      id: 'msg_$time',
      topic: 'prod',
      title: title,
      message: message,
      time: time,
    );

WidgetSnapshot _build(List<Topic> topics, List<Incident> incidents) =>
    buildWidgetSnapshot(
      topics: topics,
      incidents: incidents,
      connected: true,
      now: _now,
    );

Map<String, dynamic> _readFixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  group('the shared fixture', () {
    test('the server sample builds exactly widget_snapshot_v1.json', () {
      final server = _readFixture('widget_server_v1.json');
      final topics = [
        for (final json in server['topics'] as List)
          Topic.fromJson(json as Map<String, dynamic>),
      ];
      final incidents = [
        for (final json in [
          ...server['open'] as List,
          ...server['acked'] as List,
        ])
          Incident.fromJson(json as Map<String, dynamic>),
      ];

      final snapshot = buildWidgetSnapshot(
        topics: topics,
        incidents: incidents,
        connected: true,
        now: _at(server['now'] as int),
      );

      expect(snapshot.toJson(), _readFixture('widget_snapshot_v1.json'));
    });
  });

  group('which incident a topic shows', () {
    test('open beats acked, even an older open', () {
      final snapshot = _build(
        [const Topic(name: 'prod')],
        [
          _incident('inc_acked', state: IncidentStates.acked, openedAt: 200),
          _incident('inc_open', openedAt: 100),
        ],
      );
      expect(snapshot.topics.single.incident?.id, 'inc_open');
    });

    test('the newest opened_at wins inside a state', () {
      final snapshot = _build(
        [const Topic(name: 'prod')],
        [
          _incident('inc_old', openedAt: 100),
          _incident('inc_new', openedAt: 200),
        ],
      );
      expect(snapshot.topics.single.incident?.id, 'inc_new');
    });

    test('a tie on opened_at goes to the smaller id', () {
      final snapshot = _build(
        [const Topic(name: 'prod')],
        [_incident('inc_b', openedAt: 100), _incident('inc_a', openedAt: 100)],
      );
      expect(snapshot.topics.single.incident?.id, 'inc_a');
    });

    test('closed and expired incidents are dropped', () {
      final snapshot = _build(
        [const Topic(name: 'prod')],
        [
          _incident('inc_c', state: IncidentStates.closed),
          _incident('inc_e', state: IncidentStates.expired),
        ],
      );
      expect(snapshot.topics.single.incident, isNull);
      expect(snapshot.topics.single.count, 0);
      expect(snapshot.openCount, 0);
    });

    test('acked_at is written for acked and null for open', () {
      final snapshot = _build(
        [const Topic(name: 'a'), const Topic(name: 'b')],
        [
          _incident('inc_a', topic: 'a', ackedAt: 150),
          _incident(
            'inc_b',
            topic: 'b',
            state: IncidentStates.acked,
            openedAt: 100,
            ackedAt: 150,
          ),
        ],
      );
      expect(snapshot.topics[0].incident?.ackedAt, isNull);
      expect(snapshot.topics[1].incident?.ackedAt, 150);
    });
  });

  group('titles', () {
    test('the newest message title, whatever the list order', () {
      final incident = _incident(
        'inc_1',
        messages: [
          _message(title: 'newest', time: 20),
          _message(title: 'oldest', time: 10),
        ],
      );
      expect(widgetIncidentTitle(incident), 'newest');
    });

    test('falls back to the message text, then the topic', () {
      expect(
        widgetIncidentTitle(
          _incident(
            'inc_1',
            messages: [_message(title: ' ', message: ' x ')],
          ),
        ),
        'x',
      );
      expect(
        widgetIncidentTitle(
          _incident('inc_1', messages: [_message(message: '  ')]),
        ),
        'prod',
      );
      expect(widgetIncidentTitle(_incident('inc_1')), 'prod');
    });

    test('every case in widget_titles_v1.json', () {
      final fixture = _readFixture('widget_titles_v1.json');
      expect(fixture['max_code_points'], widgetTitleMaxLength);
      for (final raw in fixture['cases'] as List) {
        final c = raw as Map<String, dynamic>;
        expect(
          widgetTitle(c['raw'] as String, c['topic'] as String),
          c['title'],
          reason: c['note'] as String,
        );
      }
    });

    test('is cut to 120 characters', () {
      final long = 'a' * 200;
      final title = widgetIncidentTitle(
        _incident('inc_1', messages: [_message(title: long)]),
      );
      expect(title.length, widgetTitleMaxLength);
    });
  });

  group('order and counts', () {
    test('open topics first, then acked, then quiet, each by name', () {
      final snapshot = _build(
        [
          const Topic(name: 'quiet-b'),
          const Topic(name: 'acked'),
          const Topic(name: 'quiet-a'),
          const Topic(name: 'open-z'),
          const Topic(name: 'open-a'),
        ],
        [
          _incident('inc_1', topic: 'open-z'),
          _incident('inc_2', topic: 'open-a'),
          _incident('inc_3', topic: 'acked', state: IncidentStates.acked),
        ],
      );
      expect(snapshot.topics.map((t) => t.name), [
        'open-a',
        'open-z',
        'acked',
        'quiet-a',
        'quiet-b',
      ]);
    });

    test('counts are open plus acked, per topic and in total', () {
      final snapshot = _build(
        [const Topic(name: 'prod'), const Topic(name: 'dev')],
        [
          _incident('inc_1'),
          _incident('inc_2', state: IncidentStates.acked),
          _incident('inc_3', state: IncidentStates.closed),
          _incident('inc_4', topic: 'dev'),
        ],
      );
      expect(snapshot.topics.map((t) => t.count), [1, 2]);
      expect(snapshot.openCount, 3);
    });

    test('at most 50 topics, and the total counts only those', () {
      final topics = [
        for (var i = 0; i < 60; i++)
          Topic(name: 't${i.toString().padLeft(2, '0')}'),
      ];
      final snapshot = _build(topics, [_incident('inc_1', topic: 't59')]);
      expect(snapshot.topics, hasLength(WidgetSnapshot.maxTopics));
      expect(snapshot.topics.first.name, 't59');
      expect(snapshot.openCount, 1);
    });

    test('incidents on a topic that is not in the list are ignored', () {
      final snapshot = _build(
        [const Topic(name: 'prod')],
        [_incident('inc_1', topic: 'gone')],
      );
      expect(snapshot.topics.single.count, 0);
      expect(snapshot.openCount, 0);
    });
  });

  test('not connected is the disconnected shape', () {
    final snapshot = buildWidgetSnapshot(
      topics: [const Topic(name: 'prod')],
      incidents: [_incident('inc_1')],
      connected: false,
      now: _now,
    );
    expect(snapshot.toJson(), {
      'v': 1,
      'updated_at': 1759046400,
      'connected': false,
      'open_count': 0,
      'topics': <Object?>[],
    });
    expect(
      WidgetSnapshot.disconnected(_now).toJson(),
      snapshot.toJson(),
    );
  });

  test('times are whole seconds, rounded down', () {
    expect(
      epochSeconds(DateTime.fromMillisecondsSinceEpoch(1999, isUtc: true)),
      1,
    );
  });
}
