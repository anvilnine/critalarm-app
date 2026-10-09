import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/features/topics/domain/topic_messages_page.dart';
import 'package:critalarm/features/topics/presentation/widgets/messages_page_header.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Thursday 8 October 2026, 18:30 on the phone's clock.
  final now = DateTime(2026, 10, 8, 18, 30);

  DateTime at(int daysAgo, [int hour = 12, int minute = 0]) =>
      DateTime(2026, 10, 8 - daysAgo, hour, minute);

  group('messageDayBars', () {
    test('gives seven days, oldest first, the last one today', () {
      final bars = messageDayBars(messages: const [], now: now);
      expect(bars, hasLength(kMessageBarDays));
      expect(bars.first.day, DateTime(2026, 10, 2));
      expect(bars.last.day, DateTime(2026, 10, 8));
      expect(bars.last.isToday, isTrue);
      expect(bars.take(6).any((b) => b.isToday), isFalse);
    });

    test('a week with nothing in it is seven quiet days', () {
      final bars = messageDayBars(messages: const [], now: now);
      for (final bar in bars) {
        expect(bar.count, 0);
        expect(bar.fraction, 0);
        expect(bar.hasRang, isFalse);
      }
    });

    test('counts each message on its own day', () {
      final bars = messageDayBars(
        messages: [
          (at: at(0, 9), rang: false),
          (at: at(0, 18), rang: false),
          (at: at(1, 23, 59), rang: false),
          (at: at(6, 0, 1), rang: false),
        ],
        now: now,
      );
      expect(bars.map((b) => b.count), [1, 0, 0, 0, 0, 1, 2]);
    });

    test('heights follow the busiest day', () {
      final bars = messageDayBars(
        messages: [
          for (var i = 0; i < 4; i++) (at: at(0), rang: false),
          for (var i = 0; i < 2; i++) (at: at(1), rang: false),
          (at: at(2), rang: false),
        ],
        now: now,
      );
      expect(bars[6].fraction, 1);
      expect(bars[5].fraction, 0.5);
      expect(bars[4].fraction, 0.25);
      expect(bars[3].fraction, 0);
    });

    test('a day marks as rang when any one message on it rang', () {
      final bars = messageDayBars(
        messages: [
          (at: at(0, 8), rang: false),
          (at: at(0, 9), rang: true),
          (at: at(1, 9), rang: false),
        ],
        now: now,
      );
      expect(bars[6].hasRang, isTrue);
      expect(bars[5].hasRang, isFalse);
    });

    test('a message older than the week is left out', () {
      final bars = messageDayBars(
        messages: [(at: at(7), rang: true), (at: at(30), rang: true)],
        now: now,
      );
      expect(bars.map((b) => b.count).reduce((a, b) => a + b), 0);
      expect(bars.any((b) => b.hasRang), isFalse);
    });

    test('a message after now counts as today', () {
      final bars = messageDayBars(
        messages: [(at: now.add(const Duration(hours: 3)), rang: false)],
        now: now,
      );
      expect(bars.last.count, 1);
    });

    test('days are calendar days, so a clock change does not lose one', () {
      // 29 March 2026 is a day of 23 hours in many zones.
      final spring = DateTime(2026, 3, 30, 12);
      final bars = messageDayBars(
        messages: [(at: DateTime(2026, 3, 28, 12), rang: false)],
        now: spring,
      );
      expect(bars[4].day, DateTime(2026, 3, 28));
      expect(bars[4].count, 1);
    });
  });

  group('messageBarHeight', () {
    MessageDayBar bar(int count, double fraction) => MessageDayBar(
      day: now,
      count: count,
      hasRang: false,
      fraction: fraction,
      isToday: false,
    );

    test('a quiet day is a short stub', () {
      expect(messageBarHeight(bar(0, 0)), 8);
    });

    test('the busiest day reaches the full height', () {
      expect(messageBarHeight(bar(5, 1)), 72);
    });

    test('a day with one message is taller than a quiet day', () {
      expect(messageBarHeight(bar(1, 0.1)), greaterThan(8));
      expect(messageBarHeight(bar(1, 0.1)), lessThan(72));
    });
  });

  group('messageBarGrowth', () {
    test('starts at nothing and ends whole', () {
      expect(messageBarGrowth(0, 0.5), 0);
      expect(messageBarGrowth(0.5, 0.5), closeTo(1, 1e-9));
      expect(messageBarGrowth(9, 0.5), closeTo(1, 1e-9));
    });

    test('waits at nothing for a bar that has not started', () {
      expect(messageBarGrowth(-1, 0.5), 0);
    });
  });

  group('groupMessagesByDay', () {
    List<DateTime> times(List<DateTime> list) => list;

    test('names today and yesterday and the rest by date', () {
      final groups = groupMessagesByDay<DateTime>(
        times([at(0, 18), at(0, 11), at(1, 0, 45), at(3, 10)]),
        timeOf: (t) => t,
        now: now,
      );
      expect(groups.map((g) => g.kind), [
        MessageDayKind.today,
        MessageDayKind.yesterday,
        MessageDayKind.earlier,
      ]);
      expect(groups.map((g) => g.items.length), [2, 1, 1]);
      expect(groups.last.day, DateTime(2026, 10, 5));
    });

    test('keeps the order it was given', () {
      final groups = groupMessagesByDay<DateTime>(
        times([at(0, 18), at(0, 11), at(1, 20), at(1, 2)]),
        timeOf: (t) => t,
        now: now,
      );
      expect(groups.first.items, [at(0, 18), at(0, 11)]);
      expect(groups.last.items, [at(1, 20), at(1, 2)]);
    });

    test('a message after now falls in today', () {
      final groups = groupMessagesByDay<DateTime>(
        [now.add(const Duration(days: 1))],
        timeOf: (t) => t,
        now: now,
      );
      expect(groups.single.kind, MessageDayKind.today);
      expect(groups.single.day, DateTime(2026, 10, 8));
    });

    test('an empty list is no groups', () {
      expect(
        groupMessagesByDay<DateTime>(
          const [],
          timeOf: (t) => t,
          now: now,
        ),
        isEmpty,
      );
    });

    test('a message on the other side of midnight starts a new day', () {
      final groups = groupMessagesByDay<DateTime>(
        [DateTime(2026, 10, 8, 0, 5), DateTime(2026, 10, 7, 23, 55)],
        timeOf: (t) => t,
        now: now,
      );
      expect(groups, hasLength(2));
    });
  });

  group('rangLineFor', () {
    final opened = DateTime.utc(2026, 10, 8, 10);

    Incident incident(
      String state, {
      DateTime? openedAt,
      DateTime? ackedAt,
      DateTime? closedAt,
    }) => Incident(
      id: 'inc_1',
      topic: 'prod',
      state: state,
      openedAt: openedAt ?? opened,
      ackedAt: ackedAt,
      closedAt: closedAt,
    );

    test('open is ringing now, with no length', () {
      final line = rangLineFor(incident('open'));
      expect(line, const RangLine(end: RangEnd.ringing));
    });

    test('acknowledged is answered after the time to the acknowledge', () {
      final line = rangLineFor(
        incident('acked', ackedAt: opened.add(const Duration(seconds: 12))),
      );
      expect(
        line,
        const RangLine(end: RangEnd.answered, duration: Duration(seconds: 12)),
      );
    });

    test('closed after an acknowledge is answered, and rang to the ack', () {
      final line = rangLineFor(
        incident(
          'closed',
          ackedAt: opened.add(const Duration(minutes: 3)),
          closedAt: opened.add(const Duration(minutes: 20)),
        ),
      );
      expect(
        line,
        const RangLine(end: RangEnd.answered, duration: Duration(minutes: 3)),
      );
    });

    test('closed with no acknowledge is resolved, to the close', () {
      final line = rangLineFor(
        incident('closed', closedAt: opened.add(const Duration(seconds: 90))),
      );
      expect(
        line,
        const RangLine(
          end: RangEnd.resolved,
          duration: Duration(seconds: 90),
        ),
      );
    });

    test('expired is expired, to the close when there is one', () {
      final line = rangLineFor(
        incident('expired', closedAt: opened.add(const Duration(minutes: 5))),
      );
      expect(
        line,
        const RangLine(end: RangEnd.expired, duration: Duration(minutes: 5)),
      );
    });

    test('leaves the length out when the incident does not say', () {
      expect(
        rangLineFor(incident('expired')),
        const RangLine(end: RangEnd.expired),
      );
      expect(
        rangLineFor(incident('acked')),
        const RangLine(end: RangEnd.answered),
      );
    });

    test('leaves the length out when it would be negative', () {
      final line = rangLineFor(
        incident('acked', ackedAt: opened.subtract(const Duration(seconds: 4))),
      );
      expect(line.duration, isNull);
    });

    test('leaves the length out when it never says when it opened', () {
      final line = rangLineFor(
        const Incident(id: 'inc_2', topic: 'prod', state: 'acked'),
      );
      expect(line.end, RangEnd.answered);
      expect(line.duration, isNull);
    });
  });

  group('RangIndex', () {
    Message message(
      String id, {
      required int time,
      String? title,
      String body = 'triggered',
    }) => Message(
      id: id,
      topic: 'prod',
      time: time,
      title: title,
      message: body,
      priority: 5,
      incidentId: 'inc_1',
    );

    final first = message('m1', time: 1000, title: 'Down', body: 'api down');
    final repeat = message('m2', time: 1060, title: 'Down', body: 'api down');
    final incident = Incident(
      id: 'inc_1',
      topic: 'prod',
      state: 'acked',
      openedAt: DateTime.fromMillisecondsSinceEpoch(1000 * 1000, isUtc: true),
      ackedAt: DateTime.fromMillisecondsSinceEpoch(1012 * 1000, isUtc: true),
      // Newest first, as a server may send them.
      messages: [repeat, first],
    );

    RangMatch? find(
      RangIndex index,
      int seconds,
      String title,
      String body,
    ) => index.find(
      at: DateTime.fromMillisecondsSinceEpoch(seconds * 1000),
      title: title,
      body: body,
    );

    test('finds the incident that holds a message', () {
      final index = RangIndex.of([incident]);
      final match = find(index, 1000, 'Down', 'api down');
      expect(match, isNotNull);
      expect(match!.incident.id, 'inc_1');
    });

    test('only the message that opened the incident carries the line', () {
      final index = RangIndex.of([incident]);
      final opening = find(index, 1000, 'Down', 'api down')!;
      final later = find(index, 1060, 'Down', 'api down')!;
      expect(opening.opensIncident, isTrue);
      expect(
        opening.line,
        const RangLine(end: RangEnd.answered, duration: Duration(seconds: 12)),
      );
      expect(later.opensIncident, isFalse);
      expect(later.line, isNull);
    });

    test('a message no incident holds did not ring', () {
      final index = RangIndex.of([incident]);
      expect(find(index, 2000, 'Down', 'api down'), isNull);
      expect(find(index, 1000, 'Up', 'api down'), isNull);
      expect(find(index, 1000, 'Down', 'other'), isNull);
    });

    test('a message with no title is matched under its topic name', () {
      final bare = Incident(
        id: 'inc_3',
        topic: 'prod',
        messages: [message('m9', time: 500)],
      );
      final index = RangIndex.of([bare]);
      expect(find(index, 500, 'prod', 'triggered'), isNotNull);
    });

    test('an incident with no messages adds nothing', () {
      final index = RangIndex.of([
        const Incident(id: 'inc_4', topic: 'prod'),
      ]);
      expect(find(index, 1000, 'Down', 'api down'), isNull);
    });
  });
}
