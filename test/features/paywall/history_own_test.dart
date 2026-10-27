import 'package:critalarm/features/paywall/domain/history_own.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _now = DateTime(2026, 10, 13, 12);

({String topic, DateTime openedAt}) _row(String topic, int daysAgo) =>
    (topic: topic, openedAt: _now.subtract(Duration(days: daysAgo, hours: 1)));

void main() {
  group('historyOwnFrom', () {
    test('nothing older than the window means no own rows', () {
      final own = historyOwnFrom(
        rows: [_row('prod-db', 0), _row('prod-db', 3), _row('nas', 6)],
        now: _now,
        freeDays: 7,
      );
      expect(own, isNull);
    });

    test('no rows at all means no own rows', () {
      expect(historyOwnFrom(rows: const [], now: _now, freeDays: 7), isNull);
    });

    test('rows inside and past the window are split at the window', () {
      final own = historyOwnFrom(
        rows: [
          _row('prod-db', 1),
          _row('uptime-kuma', 6),
          _row('nas', 7),
          _row('prod-db', 40),
        ],
        now: _now,
        freeDays: 7,
      )!;
      expect(own.inside.map((r) => (r.topic, r.ageDays)), [
        ('prod-db', 1),
        ('uptime-kuma', 6),
      ]);
      expect(own.beyond.map((r) => (r.topic, r.ageDays)), [
        ('nas', 7),
        ('prod-db', 40),
      ]);
    });

    test('a person who only has older rows still gets them', () {
      final own = historyOwnFrom(
        rows: [_row('nas', 20), _row('nas', 30)],
        now: _now,
        freeDays: 7,
      )!;
      expect(own.inside, isEmpty);
      expect(own.beyond.length, 2);
    });

    test(
      'the lists are capped and the older ones are spread across the reach',
      () {
        final rows = [
          for (var d = 0; d < 6; d++) _row('a$d', d),
          for (var d = 8; d < 90; d += 2) _row('b$d', d),
        ];
        final own = historyOwnFrom(rows: rows, now: _now, freeDays: 7)!;
        expect(own.inside.length, historyOwnMaxInside);
        expect(own.inside.first.ageDays, 0);
        expect(own.beyond.length, historyOwnMaxBeyond);
        expect(own.beyond.first.ageDays, 8);
        expect(own.beyond.last.ageDays, 88);
        final ages = own.beyond.map((r) => r.ageDays).toList();
        expect(ages, [...ages]..sort());
      },
    );

    test('a row from the future counts as today', () {
      final own = historyOwnFrom(
        rows: [
          (topic: 'x', openedAt: _now.add(const Duration(days: 2))),
          _row('nas', 12),
        ],
        now: _now,
        freeDays: 7,
      )!;
      expect(own.inside.single.ageDays, 0);
    });
  });

  group('HistoryOwn query', () {
    const own = HistoryOwn(
      inside: [HistoryOwnRow('prod-db', 1), HistoryOwnRow('nas', 5)],
      beyond: [HistoryOwnRow('nas', 12), HistoryOwnRow('prod-db', 81)],
    );

    test('round trips', () {
      expect(own.toQuery(), {
        'hin': 'prod-db:1,nas:5',
        'hbe': 'nas:12,prod-db:81',
      });
      final back = HistoryOwn.fromQuery(own.toQuery())!;
      expect(back.inside.map((r) => (r.topic, r.ageDays)), [
        ('prod-db', 1),
        ('nas', 5),
      ]);
      expect(back.beyond.map((r) => (r.topic, r.ageDays)), [
        ('nas', 12),
        ('prod-db', 81),
      ]);
    });

    test('an empty inside list is fine', () {
      final back = HistoryOwn.fromQuery({'hbe': 'nas:12'})!;
      expect(back.inside, isEmpty);
      expect(back.beyond.length, 1);
    });

    test('nothing beyond means no own rows', () {
      expect(HistoryOwn.fromQuery({'hin': 'nas:1'}), isNull);
      expect(HistoryOwn.fromQuery({'hin': 'nas:1', 'hbe': ''}), isNull);
    });

    test('junk entries are dropped, and junk everywhere is no rows', () {
      final back = HistoryOwn.fromQuery({
        'hbe': 'nas:12,bad name:3,x:-1,y:abc,z,:4,ok-one:99999,fine_2:7',
      })!;
      expect(back.beyond.map((r) => r.topic), ['nas', 'fine_2']);
      expect(HistoryOwn.fromQuery({'hbe': 'a b:1,:2,x'}), isNull);
    });

    test('more than four entries are cut to four', () {
      final back = HistoryOwn.fromQuery({
        'hbe': 'a:1,b:2,c:3,d:4,e:5,f:6',
      })!;
      expect(back.beyond.length, historyOwnMaxBeyond);
    });
  });
}
