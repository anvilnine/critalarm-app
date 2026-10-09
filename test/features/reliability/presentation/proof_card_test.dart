import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_entry.dart';
import 'package:critalarm/features/reliability/presentation/proof_card.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/load_translations.dart';

// Friday 9 October 2026, so this week began on Monday 5 October.
final _now = DateTime(2026, 10, 9, 14);

List<ProofWeek> _weeks(List<ProofMark> marks) {
  final current = proofWeekStart(_now);
  return [
    for (var i = 0; i < marks.length; i++)
      ProofWeek(
        monday: DateTime(
          current.year,
          current.month,
          current.day - 7 * (marks.length - 1 - i),
        ),
        mark: marks[i],
      ),
  ];
}

void main() {
  setUpAll(loadTestTranslations);

  const n = ProofMark.none;
  const r = ProofMark.rang;
  const f = ProofMark.failed;

  group('proofCardViewFor', () {
    test('0 of 8: nothing rang, and the value is the muted one', () {
      final view = proofCardViewFor(_weeks([n, n, n, n, n, n, n, n]), _now);
      expect(view.count, 0);
      expect(view.isEmpty, isTrue);
      expect(view.dots, hasLength(8));
      expect(view.dots.every((dot) => dot.mark == ProofMark.none), isTrue);
    });

    test('2 of 8 with this week filled', () {
      final view = proofCardViewFor(_weeks([n, n, n, n, n, n, r, r]), _now);
      expect(view.count, 2);
      expect(view.isEmpty, isFalse);
      expect(view.dots.last.mark, ProofMark.rang);
      expect(view.dots.last.isThisWeek, isTrue);
      expect(view.dots.where((dot) => dot.isThisWeek), hasLength(1));
    });

    test('7 of 8 with one failed: the failed week is not counted', () {
      final view = proofCardViewFor(_weeks([r, r, r, r, r, f, r, r]), _now);
      expect(view.count, 7);
      expect(view.dots[5].mark, ProofMark.failed);
      expect(
        view.dots.where((dot) => dot.mark == ProofMark.failed),
        hasLength(1),
      );
    });

    test('the spoken text names the week and what happened', () {
      final view = proofCardViewFor(_weeks([r, n, f, n, n, n, n, r]), _now);
      expect(view.dots[0].label, 'Week of 17 Aug, a test rang');
      expect(view.dots[1].label, 'Week of 24 Aug, no test');
      expect(view.dots[2].label, 'Week of 31 Aug, a test failed');
      expect(view.dots.last.label, 'Week of 5 Oct, a test rang, this week');
    });

    test('fewer than eight weeks are drawn as they come', () {
      final view = proofCardViewFor(_weeks([n, r, r]), _now);
      expect(view.dots, hasLength(3));
      expect(view.count, 2);
      expect(view.dots.last.isThisWeek, isTrue);
    });

    test('no weeks at all draws no dots and counts none', () {
      final view = proofCardViewFor(const [], _now);
      expect(view.dots, isEmpty);
      expect(view.count, 0);
    });
  });

  group('proofDotFillAt', () {
    test('nothing has filled at the start but the first dot is under way', () {
      expect(proofDotFillAt(0, Duration.zero), 0);
      expect(
        proofDotFillAt(0, const Duration(milliseconds: 95)),
        closeTo(0.5, 0.01),
      );
      expect(proofDotFillAt(7, Duration.zero), 0);
    });

    test('dots start 30 ms apart, left to right', () {
      const at = Duration(milliseconds: 100);
      for (var i = 0; i < 7; i++) {
        expect(
          proofDotFillAt(i, at),
          greaterThanOrEqualTo(proofDotFillAt(i + 1, at)),
        );
      }
      expect(proofDotFillAt(1, const Duration(milliseconds: 30)), 0);
      expect(
        proofDotFillAt(1, const Duration(milliseconds: 31)),
        greaterThan(0),
      );
    });

    test('every dot is full when the 400 ms are over', () {
      for (var i = 0; i < 8; i++) {
        expect(proofDotFillAt(i, AppDurations.slow), 1);
      }
    });
  });
}
