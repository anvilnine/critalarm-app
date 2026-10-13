import 'package:critalarm/features/paywall/domain/leaving_numbers.dart';
import 'package:critalarm/features/paywall/domain/leaving_seen.dart';
import 'package:critalarm/features/paywall/domain/paywall_leaving.dart';
import 'package:flutter_test/flutter_test.dart';

const _facts = LeavingFacts(
  rang: 142,
  answered: 139,
  nights: 9,
  criticalTopics: 4,
  historyDaysHeld: 61,
);

void main() {
  group('PaywallLeaving query', () {
    test('round trips the date, the rest flag and the facts', () {
      final leaving = PaywallLeaving(
        endsOn: DateTime(2026, 10, 20),
        atRest: true,
        facts: _facts,
      );
      expect(leaving.toQuery(), {
        'ends': '2026-10-20',
        'rest': '1',
        'rang': '142',
        'ans': '139',
        'nights': '9',
        'crit': '4',
        'days': '61',
      });
      final back = PaywallLeaving.fromQuery(leaving.toQuery())!;
      expect(back.endsOn, DateTime(2026, 10, 20));
      expect(back.atRest, isTrue);
      expect(back.facts, _facts);
    });

    test('a first open has no rest flag and may have no facts', () {
      final leaving = PaywallLeaving(endsOn: DateTime(2026, 1, 5));
      expect(leaving.toQuery(), {'ends': '2026-01-05'});
      final back = PaywallLeaving.fromQuery(leaving.toQuery())!;
      expect(back.atRest, isFalse);
      expect(back.facts, isNull);
    });

    test('no valid date, no leaving', () {
      for (final junk in [
        null,
        '',
        '2026-02-30',
        '2026-13-01',
        '20 Oct',
        '2026-10-2',
        '2026-10-20T10:00',
      ]) {
        expect(
          PaywallLeaving.fromQuery({'ends': ?junk}),
          isNull,
          reason: '$junk',
        );
      }
    });

    test('junk in the rest flag is no rest, junk in the facts is no facts', () {
      final back = PaywallLeaving.fromQuery({
        'ends': '2026-10-20',
        'rest': 'yes',
        'rang': '-4',
      })!;
      expect(back.atRest, isFalse);
      expect(back.facts, isNull);
    });
  });

  group('once per end date', () {
    test('the key is the date', () {
      expect(leavingSeenKeyFor(DateTime(2026, 10, 20, 14, 30)), '2026-10-20');
    });

    test('shown for that date only', () {
      expect(leavingWasShown(null, DateTime(2026, 10, 20)), isFalse);
      expect(leavingWasShown('2026-10-20', DateTime(2026, 10, 20)), isTrue);
      expect(leavingWasShown('2026-10-20', DateTime(2026, 11, 20)), isFalse);
      expect(leavingWasShown('', DateTime(2026, 10, 20)), isFalse);
    });
  });
}
