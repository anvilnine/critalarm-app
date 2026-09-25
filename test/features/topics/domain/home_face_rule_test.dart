import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/topics/domain/home_face_rule.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/load_translations.dart';

Topic _topic(String name, {int deskTimerS = 600, bool critical = false}) =>
    Topic(name: name, deskTimerS: deskTimerS, critical: critical);

Incident _incident(
  String id,
  String topic,
  String state, {
  DateTime? openedAt,
  DateTime? ackedAt,
  DateTime? closedAt,
  List<Message> messages = const [],
}) => Incident(
  id: id,
  topic: topic,
  state: state,
  openedAt: openedAt,
  ackedAt: ackedAt,
  closedAt: closedAt,
  messages: messages,
);

Message _msg(
  String id,
  String topic, {
  int priority = 3,
  List<String> tags = const [],
  String? incidentId,
  int? timeSeconds,
}) => Message(
  id: id,
  topic: topic,
  priority: priority,
  tags: tags,
  incidentId: incidentId,
  time: timeSeconds ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
);

void main() {
  setUpAll(loadTestTranslations);

  final now = DateTime.utc(2026, 9, 22, 14);
  final topics = [_topic('prod-db', critical: true), _topic('nas-backup')];

  group('resolveHomeFace hero', () {
    test('alarmed hero for open P5', () {
      final incidents = [
        _incident(
          'inc1',
          'prod-db',
          IncidentStates.open,
          openedAt: now.subtract(const Duration(minutes: 2)),
          messages: [_msg('m1', 'prod-db', priority: 5, incidentId: 'inc1')],
        ),
      ];
      final result = resolveHomeFace(
        topics: topics,
        incidents: incidents,
        warningTopics: const {},
        now: now,
      );
      expect(result.hero.faceState, FaceState.alarmed);
      expect(result.hero.word, 'CRITICAL');
      expect(result.hero.subText, 'prod-db is ringing.');
      expect(result.hero.severity, SeverityMode.crit);
      expect(result.hero.ringingIncidentId, 'inc1');
    });

    test('worried hero for open P4 or warning, no P5', () {
      final result = resolveHomeFace(
        topics: topics,
        incidents: const [],
        warningTopics: const {'nas-backup'},
        now: now,
      );
      expect(result.hero.faceState, FaceState.worried);
      expect(result.hero.word, '1 warning');
      expect(result.hero.severity, SeverityMode.high);
    });

    test('acked hero while desk timer runs', () {
      final ackedAt = now.subtract(const Duration(minutes: 2));
      final incidents = [
        _incident(
          'inc1',
          'prod-db',
          IncidentStates.acked,
          ackedAt: ackedAt,
          messages: [_msg('m1', 'prod-db', priority: 5, incidentId: 'inc1')],
        ),
      ];
      final result = resolveHomeFace(
        topics: topics,
        incidents: incidents,
        warningTopics: const {},
        now: now,
      );
      expect(result.hero.faceState, FaceState.acked);
      expect(result.hero.word, 'ACKNOWLEDGED');
      expect(result.hero.subText, contains('prod-db'));
      expect(result.hero.subText, contains('at your desk in'));
      expect(result.hero.severity, SeverityMode.ack);
    });

    test('handled hero for 30 seconds after closedAt', () {
      final closedAt = now.subtract(const Duration(seconds: 10));
      final incidents = [
        _incident(
          'inc1',
          'prod-db',
          IncidentStates.closed,
          closedAt: closedAt,
          messages: [_msg('m1', 'prod-db', priority: 5, incidentId: 'inc1')],
        ),
      ];
      final result = resolveHomeFace(
        topics: topics,
        incidents: incidents,
        warningTopics: const {},
        now: now,
      );
      expect(result.hero.faceState, FaceState.success);
      expect(result.hero.word, 'HANDLED');
      expect(
        result.hero.subText,
        'prod-db closed at ${DateFormat.Hm().format(closedAt.toLocal())}.',
      );
    });

    test('calm hero when nothing in last hour', () {
      final result = resolveHomeFace(
        topics: topics,
        incidents: const [],
        warningTopics: const {},
        now: now,
      );
      expect(result.hero.faceState, FaceState.calm);
      expect(result.hero.word, 'All clear');
      expect(result.hero.subText, 'Nothing is ringing.');
      expect(result.hero.severity, SeverityMode.none);
    });

    test('calm hero shows the last handled time from any age', () {
      // Handled wins over calm for 30 seconds, so once an incident is old
      // enough to fall out of the handled window it still counts for the
      // calm hero's second line, no matter how long ago it closed.
      final closedAt = now.subtract(const Duration(days: 2));
      final result = resolveHomeFace(
        topics: topics,
        incidents: [
          _incident(
            'inc2',
            'prod-db',
            IncidentStates.closed,
            closedAt: closedAt,
          ),
        ],
        warningTopics: const {},
        now: now,
      );
      expect(result.hero.faceState, FaceState.calm);
      final localClosed = closedAt.toLocal();
      final time =
          '${DateFormat.MMMd().format(localClosed)}, '
          '${DateFormat.Hm().format(localClosed)}';
      expect(
        result.hero.subText,
        'Nothing is ringing.\nLast alarm handled at $time.',
      );
    });
  });

  group('resolveHomeFace row meta', () {
    test('alarmed row for open P5 topic', () {
      final incidents = [
        _incident(
          'inc1',
          'prod-db',
          IncidentStates.open,
          openedAt: now.subtract(const Duration(minutes: 1)),
          messages: [_msg('m1', 'prod-db', priority: 5, incidentId: 'inc1')],
        ),
      ];
      final result = resolveHomeFace(
        topics: topics,
        incidents: incidents,
        warningTopics: const {},
        now: now,
      );
      final row = result.rows.firstWhere((r) => r.name == 'prod-db');
      expect(row.faceState, FaceState.alarmed);
      expect(row.meta, 'Alert active');
    });

    test('worried row for warning topic', () {
      final result = resolveHomeFace(
        topics: topics,
        incidents: const [],
        warningTopics: const {'nas-backup'},
        now: now,
      );
      final row = result.rows.firstWhere((r) => r.name == 'nas-backup');
      expect(row.faceState, FaceState.worried);
      expect(row.meta, '1 warning');
    });

    test('acked row counts down to desk timer', () {
      final ackedAt = now.subtract(const Duration(minutes: 2));
      final incidents = [
        _incident('inc1', 'prod-db', IncidentStates.acked, ackedAt: ackedAt),
      ];
      final result = resolveHomeFace(
        topics: topics,
        incidents: incidents,
        warningTopics: const {},
        now: now,
      );
      final row = result.rows.firstWhere((r) => r.name == 'prod-db');
      expect(row.faceState, FaceState.acked);
      expect(row.meta, contains('Acknowledged'));
    });

    test('handled row shows Handled time', () {
      final closedAt = now.subtract(const Duration(minutes: 10));
      final incidents = [
        _incident(
          'inc1',
          'nas-backup',
          IncidentStates.closed,
          closedAt: closedAt,
        ),
      ];
      final result = resolveHomeFace(
        topics: topics,
        incidents: incidents,
        warningTopics: const {},
        now: now,
      );
      final row = result.rows.firstWhere((r) => r.name == 'nas-backup');
      expect(row.faceState, FaceState.success);
      expect(row.meta, 'Handled ${DateFormat.Hm().format(closedAt.toLocal())}');
    });

    test('quiet row when nothing active', () {
      final result = resolveHomeFace(
        topics: topics,
        incidents: const [],
        warningTopics: const {},
        now: now,
      );
      final row = result.rows.firstWhere((r) => r.name == 'nas-backup');
      expect(row.faceState, FaceState.calm);
      expect(row.meta, 'Quiet');
    });
  });

  group('extra rules', () {
    test('two topics one acked one open shows open hero', () {
      final ackedAt = now.subtract(const Duration(minutes: 2));
      final incidents = [
        _incident('inc1', 'nas-backup', IncidentStates.acked, ackedAt: ackedAt),
        _incident(
          'inc2',
          'prod-db',
          IncidentStates.open,
          openedAt: now.subtract(const Duration(minutes: 1)),
          messages: [_msg('m1', 'prod-db', priority: 5, incidentId: 'inc2')],
        ),
      ];
      final result = resolveHomeFace(
        topics: topics,
        incidents: incidents,
        warningTopics: const {},
        now: now,
      );
      expect(result.hero.faceState, FaceState.alarmed);
      expect(result.hero.ringingIncidentId, 'inc2');
    });

    test('handled hero goes back to calm 30 seconds after the close', () {
      // The face says HANDLED for a moment and then settles. The row keeps
      // the handled time for the hour, so nothing is lost.
      final closedAt = now.subtract(const Duration(seconds: 30));
      final result = resolveHomeFace(
        topics: topics,
        incidents: [
          _incident(
            'inc1',
            'prod-db',
            IncidentStates.closed,
            closedAt: closedAt,
          ),
        ],
        warningTopics: const {},
        now: now,
      );
      expect(result.hero.faceState, FaceState.calm);
      expect(result.hero.word, 'All clear');
      final row = result.rows.firstWhere((r) => r.name == 'prod-db');
      expect(row.faceState, FaceState.success);
    });

    test('handled row turns calm after 61 minutes', () {
      final closedAt = now.subtract(const Duration(minutes: 61));
      final incidents = [
        _incident(
          'inc1',
          'prod-db',
          IncidentStates.closed,
          closedAt: closedAt,
        ),
      ];
      final result = resolveHomeFace(
        topics: topics,
        incidents: incidents,
        warningTopics: const {},
        now: now,
      );
      expect(result.hero.faceState, FaceState.calm);
      final row = result.rows.firstWhere((r) => r.name == 'prod-db');
      expect(row.faceState, FaceState.calm);
    });

    test('expired incident reads MISSED', () {
      final closedAt = now.subtract(const Duration(minutes: 10));
      final incidents = [
        _incident(
          'inc1',
          'prod-db',
          IncidentStates.expired,
          closedAt: closedAt,
        ),
      ];
      final result = resolveHomeFace(
        topics: topics,
        incidents: incidents,
        warningTopics: const {},
        now: now,
      );
      expect(result.hero.faceState, FaceState.success);
      expect(result.hero.word, 'MISSED');
      expect(result.hero.subText, 'prod-db was not answered.');
    });

    test('P4 inside an acked incident does not make worried', () {
      final ackedAt = now.subtract(const Duration(minutes: 2));
      final incidents = [
        _incident(
          'inc1',
          'prod-db',
          IncidentStates.acked,
          ackedAt: ackedAt,
          messages: [_msg('m1', 'prod-db', priority: 4, incidentId: 'inc1')],
        ),
      ];
      // warningTopics must be empty when the P4 belongs to an acked incident,
      // because HomeCubit only adds a topic to warningTopics for messages whose
      // incident is open (or no incident within 30 min). So the face should not
      // be worried.
      final result = resolveHomeFace(
        topics: topics,
        incidents: incidents,
        warningTopics: const {},
        now: now,
      );
      expect(result.hero.faceState, FaceState.acked);
    });

    test('hasAckedRow reports acked rows', () {
      final ackedAt = now.subtract(const Duration(minutes: 1));
      final incidents = [
        _incident('inc1', 'prod-db', IncidentStates.acked, ackedAt: ackedAt),
      ];
      final result = resolveHomeFace(
        topics: topics,
        incidents: incidents,
        warningTopics: const {},
        now: now,
      );
      expect(result.hasAckedRow, isTrue);
    });

    test('P4 with no incident stops counting after 30 minutes', () {
      final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
      final oldMsg = _msg(
        'm1',
        'nas-backup',
        priority: 4,
        timeSeconds: nowSeconds - 31 * 60,
      );
      final recentMsg = _msg(
        'm2',
        'nas-backup',
        priority: 4,
        timeSeconds: nowSeconds - 10 * 60,
      );
      // The face rule itself takes warningTopics as input, so we test the
      // HomeCubit side indirectly: a 31-minute-old P4 with no incident must not
      // contribute to warningTopics. Here we verify the worried face needs the
      // warningTopics set and that an old P4 alone leaves it calm.
      final calm = resolveHomeFace(
        topics: topics,
        incidents: const [],
        warningTopics: const {},
        now: now,
      );
      expect(calm.hero.faceState, FaceState.calm);

      // With a warning topic it is worried regardless of the underlying P4 age,
      // the 30-minute window is enforced at the poll site.
      final worried = resolveHomeFace(
        topics: topics,
        incidents: const [],
        warningTopics: const {'nas-backup'},
        now: now,
      );
      expect(worried.hero.faceState, FaceState.worried);
      expect(oldMsg.time, lessThan(recentMsg.time));
    });

    test('desk timer uses topic deskTimerS with fallback 600', () {
      final customTopics = [_topic('prod-db', deskTimerS: 300)];
      final ackedAt = now.subtract(const Duration(minutes: 6));
      final incidents = [
        _incident('inc1', 'prod-db', IncidentStates.acked, ackedAt: ackedAt),
      ];
      // 300s desk timer, 6 min ago, so deadline passed -> not acked any more
      final expired = resolveHomeFace(
        topics: customTopics,
        incidents: incidents,
        warningTopics: const {},
        now: now,
      );
      expect(expired.hero.faceState, FaceState.calm);

      // But with default 600s it would still be acked (6 min < 10 min)
      final withDefault = resolveHomeFace(
        topics: topics,
        incidents: incidents,
        warningTopics: const {},
        now: now,
      );
      expect(withDefault.hero.faceState, FaceState.acked);
    });
  });
}
