// Spelling out a default in a fixture keeps the case readable.
// ignore_for_file: avoid_redundant_argument_values

import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/features/topics/domain/home_card/inbox_order.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_card_fixtures.dart';

InboxEntry entry(
  String name, {
  InboxRowKind kind = InboxRowKind.normal,
  bool pinned = false,
  bool muted = false,
  int unread = 0,
  DateTime? at,
}) => InboxEntry(
  name: name,
  kind: kind,
  pinned: pinned,
  muted: muted,
  unreadCount: unread,
  lastMessageAt: at,
);

DateTime ago(Duration d) => now.subtract(d);

void main() {
  group('rowKindFor', () {
    InboxRowKind kindOf(
      List<Incident> incidents, {
      Set<String> warnings = const {},
      int deskTimerS = 600,
    }) => rowKindFor(
      topic: 'prod-db',
      incidents: incidents,
      warningTopics: warnings,
      now: now,
      deskTimerS: deskTimerS,
    );

    test('no incident is normal', () {
      expect(kindOf(const []), InboxRowKind.normal);
    });

    test('an open incident with a priority 5 message is ringing', () {
      expect(
        kindOf([
          incident(messages: [message(priority: 5)]),
        ]),
        InboxRowKind.ringing,
      );
    });

    test('an open incident with no priority 5 message is normal', () {
      expect(
        kindOf([
          incident(messages: [message()]),
        ]),
        InboxRowKind.normal,
      );
    });

    test("another topic's incident is ignored", () {
      expect(
        kindOf([
          incident(topic: 'nas', messages: [message(priority: 5)]),
        ]),
        InboxRowKind.normal,
      );
    });

    test('a warning topic is warning', () {
      expect(kindOf(const [], warnings: {'prod-db'}), InboxRowKind.warning);
      expect(kindOf(const [], warnings: {'nas'}), InboxRowKind.normal);
    });

    test('ringing beats warning and warning beats acknowledged', () {
      final ringing = incident(id: 'r', messages: [message(priority: 5)]);
      final acked = incident(
        id: 'a',
        state: IncidentStates.acked,
        ackedAt: ago(const Duration(minutes: 1)),
      );
      expect(
        kindOf([acked, ringing], warnings: {'prod-db'}),
        InboxRowKind.ringing,
      );
      expect(kindOf([acked], warnings: {'prod-db'}), InboxRowKind.warning);
    });

    test('an acknowledged incident counts down the server deadline', () {
      final acked = incident(
        state: IncidentStates.acked,
        ackedAt: ago(const Duration(minutes: 20)),
        deskTimerFiresAt: now.add(const Duration(minutes: 2)),
      );
      expect(kindOf([acked]), InboxRowKind.acknowledged);
    });

    test(
      'an acknowledged incident falls back to the ack time and desk timer',
      () {
        final acked = incident(
          state: IncidentStates.acked,
          ackedAt: ago(const Duration(minutes: 5)),
        );
        expect(kindOf([acked]), InboxRowKind.acknowledged);
        expect(kindOf([acked], deskTimerS: 120), InboxRowKind.normal);
      },
    );

    test('a close within the hour is handled', () {
      final closed = incident(
        state: IncidentStates.closed,
        closedAt: ago(const Duration(minutes: 30)),
      );
      expect(kindOf([closed]), InboxRowKind.handled);
    });

    test('an alarm that ran out within the hour is missed', () {
      final expired = incident(
        state: IncidentStates.expired,
        closedAt: ago(const Duration(minutes: 30)),
      );
      expect(kindOf([expired]), InboxRowKind.missed);
    });

    test('a close older than the hour is normal', () {
      final closed = incident(
        state: IncidentStates.closed,
        closedAt: ago(const Duration(hours: 1, minutes: 1)),
      );
      expect(kindOf([closed]), InboxRowKind.normal);
    });

    test('the newest close decides between handled and missed', () {
      final olderClosed = incident(
        id: 'a',
        state: IncidentStates.closed,
        closedAt: ago(const Duration(minutes: 50)),
      );
      final newerExpired = incident(
        id: 'b',
        state: IncidentStates.expired,
        closedAt: ago(const Duration(minutes: 10)),
      );
      expect(kindOf([olderClosed, newerExpired]), InboxRowKind.missed);
      expect(kindOf([newerExpired, olderClosed]), InboxRowKind.missed);
    });
  });

  group('orderInbox', () {
    test(
      'needs-you rows come first: ringing, acknowledged, warning, missed',
      () {
        final order = orderInbox([
          entry('normal', at: ago(const Duration(minutes: 1))),
          entry('missed', kind: InboxRowKind.missed),
          entry('warning', kind: InboxRowKind.warning),
          entry('acked', kind: InboxRowKind.acknowledged),
          entry('ringing', kind: InboxRowKind.ringing),
        ]);
        expect(order, ['ringing', 'acked', 'warning', 'missed', 'normal']);
      },
    );

    test('inside a kind of needs-you row, the newest message goes first', () {
      final order = orderInbox([
        entry(
          'old',
          kind: InboxRowKind.warning,
          at: ago(const Duration(hours: 2)),
        ),
        entry(
          'new',
          kind: InboxRowKind.warning,
          at: ago(const Duration(minutes: 5)),
        ),
      ]);
      expect(order, ['new', 'old']);
    });

    test('pinned rows follow needs-you rows and go before unread rows', () {
      final order = orderInbox([
        entry('unread', unread: 3, at: ago(const Duration(minutes: 1))),
        entry('pinned', pinned: true, at: ago(const Duration(days: 3))),
        entry('ringing', kind: InboxRowKind.ringing),
      ]);
      expect(order, ['ringing', 'pinned', 'unread']);
    });

    test('a pinned row never pushes a needs-you row down', () {
      final order = orderInbox([
        entry('pinned', pinned: true, at: ago(const Duration(minutes: 1))),
        entry('warning', kind: InboxRowKind.warning),
      ]);
      expect(order, ['warning', 'pinned']);
    });

    test('a pinned row that needs you stays in the needs-you group', () {
      final order = orderInbox([
        entry('pinned', pinned: true, at: ago(const Duration(minutes: 1))),
        entry('ringing', kind: InboxRowKind.ringing, pinned: true),
        entry('other-pin', pinned: true),
      ]);
      expect(order, ['ringing', 'pinned', 'other-pin']);
    });

    test('unread rows go before read rows, whatever their age', () {
      final order = orderInbox([
        entry('read-new', at: ago(const Duration(minutes: 1))),
        entry('unread-old', unread: 1, at: ago(const Duration(days: 2))),
      ]);
      expect(order, ['unread-old', 'read-new']);
    });

    test('the rest go newest first', () {
      final order = orderInbox([
        entry('b', at: ago(const Duration(hours: 5))),
        entry('a', at: ago(const Duration(hours: 1))),
        entry('c', at: ago(const Duration(days: 1))),
      ]);
      expect(order, ['a', 'b', 'c']);
    });

    test('muted rows go last, even when unread or newest', () {
      final order = orderInbox([
        entry(
          'muted',
          muted: true,
          unread: 5,
          at: ago(const Duration(minutes: 1)),
        ),
        entry('old', at: ago(const Duration(days: 30))),
      ]);
      expect(order, ['old', 'muted']);
    });

    test('muted rows are ordered newest first among themselves', () {
      final order = orderInbox([
        entry('m-old', muted: true, at: ago(const Duration(days: 2))),
        entry('m-new', muted: true, at: ago(const Duration(hours: 2))),
      ]);
      expect(order, ['m-new', 'm-old']);
    });

    test('a muted row that needs you does not sink', () {
      final order = orderInbox([
        entry('read', at: ago(const Duration(minutes: 1))),
        entry('muted-ringing', kind: InboxRowKind.ringing, muted: true),
        entry('muted-warning', kind: InboxRowKind.warning, muted: true),
      ]);
      expect(order, ['muted-ringing', 'muted-warning', 'read']);
    });

    test('a handled row is ordered like any other row', () {
      final order = orderInbox([
        entry('read', at: ago(const Duration(minutes: 1))),
        entry(
          'handled',
          kind: InboxRowKind.handled,
          at: ago(const Duration(minutes: 9)),
        ),
      ]);
      expect(order, ['read', 'handled']);
    });

    test('a pinned muted row stays pinned', () {
      final order = orderInbox([
        entry('read', at: ago(const Duration(minutes: 1))),
        entry('pinned-muted', pinned: true, muted: true),
      ]);
      expect(order, ['pinned-muted', 'read']);
    });

    test(
      'a topic with no messages keeps its place after topics with messages',
      () {
        final order = orderInbox([
          entry('empty-1'),
          entry('has', at: ago(const Duration(days: 9))),
          entry('empty-2'),
        ]);
        expect(order, ['has', 'empty-1', 'empty-2']);
      },
    );

    test('a tie is stable', () {
      final at = ago(const Duration(hours: 1));
      final entries = [
        for (final name in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j'])
          entry(name, at: at),
      ];
      expect(orderInbox(entries), [for (final e in entries) e.name]);
      expect(orderInbox(entries.reversed.toList()), [
        for (final e in entries.reversed) e.name,
      ]);
    });

    test('an empty list stays empty and the input is not changed', () {
      expect(orderInbox(const []), isEmpty);
      final entries = [entry('b'), entry('a', unread: 1)];
      orderInbox(entries);
      expect(entries.map((e) => e.name), ['b', 'a']);
    });
  });

  group('timeStyleFor', () {
    InboxTimeStyle style(
      DateTime? at, [
      InboxRowKind kind = InboxRowKind.normal,
    ]) => timeStyleFor(at, now, kind);

    test('today is a clock time', () {
      expect(style(DateTime(2026, 10, 9, 0, 1)), InboxTimeStyle.clock);
      expect(style(ago(const Duration(minutes: 3))), InboxTimeStyle.clock);
    });

    test('yesterday is yesterday, by calendar day', () {
      expect(style(DateTime(2026, 10, 8, 23, 59)), InboxTimeStyle.yesterday);
      expect(style(DateTime(2026, 10, 8, 0, 1)), InboxTimeStyle.yesterday);
    });

    test('2 to 6 days back is a weekday', () {
      expect(style(DateTime(2026, 10, 7, 12)), InboxTimeStyle.weekday);
      expect(style(DateTime(2026, 10, 3, 12)), InboxTimeStyle.weekday);
    });

    test('a week or more back is a date', () {
      expect(style(DateTime(2026, 10, 2, 12)), InboxTimeStyle.date);
      expect(style(DateTime(2026, 9, 1)), InboxTimeStyle.date);
      expect(style(DateTime(2025, 10, 9)), InboxTimeStyle.date);
    });

    test('a time in the future reads as a clock time', () {
      expect(
        style(now.add(const Duration(minutes: 5))),
        InboxTimeStyle.clock,
      );
    });

    test('rows that name a state use the state style', () {
      for (final kind in [
        InboxRowKind.ringing,
        InboxRowKind.acknowledged,
        InboxRowKind.missed,
        InboxRowKind.handled,
      ]) {
        expect(
          style(ago(const Duration(days: 20)), kind),
          InboxTimeStyle.state,
        );
        expect(style(null, kind), InboxTimeStyle.state);
      }
    });

    test('a warning row shows the message time', () {
      expect(
        style(ago(const Duration(minutes: 3)), InboxRowKind.warning),
        InboxTimeStyle.clock,
      );
    });

    test('a row with no messages has no time', () {
      expect(style(null), InboxTimeStyle.none);
      expect(style(null, InboxRowKind.warning), InboxTimeStyle.none);
    });
  });
}
