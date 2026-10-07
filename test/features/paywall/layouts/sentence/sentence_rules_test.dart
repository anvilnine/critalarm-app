import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/sentence/sentence_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the endings', () {
    test('every benefit has an ending and a name of its own', () {
      final tails = {
        for (final id in PaywallBenefitId.values) sentenceTailKeyFor(id),
      };
      final names = {
        for (final id in PaywallBenefitId.values) sentenceNameKeyFor(id),
      };
      expect(tails, hasLength(PaywallBenefitId.values.length));
      expect(names, hasLength(PaywallBenefitId.values.length));
      expect(tails.intersection(names), isEmpty);
    });
  });

  group('the roll', () {
    test('at rest the ending is in place and nothing is leaving', () {
      final roll = sentenceRollAt(enter: 1, direction: 0, isChange: true);
      expect(roll.arriving, 0);
      expect(roll.leaving, isNull);
    });

    test('the same ending playing again does not roll', () {
      final roll = sentenceRollAt(enter: 0.3, direction: 0, isChange: false);
      expect(roll.arriving, 0);
      expect(roll.leaving, isNull);
    });

    test('it rolls upwards: the new one from below, the old over the top', () {
      final start = sentenceRollAt(enter: 0, direction: 0, isChange: true);
      expect(start.arriving, 1);
      expect(start.leaving, 0);

      final half = sentenceRollAt(enter: 0.5, direction: 1, isChange: true);
      expect(half.arriving, 0.5);
      expect(half.leaving, -0.5);
    });

    test('a swipe back rolls the other way', () {
      final half = sentenceRollAt(enter: 0.25, direction: -1, isChange: true);
      expect(half.arriving, -0.75);
      expect(half.leaving, 0.25);
    });

    test('the two endings are always one whole box apart', () {
      for (final enter in [0.0, 0.2, 0.6, 0.99]) {
        for (final direction in [-1, 0, 1]) {
          final roll = sentenceRollAt(
            enter: enter,
            direction: direction,
            isChange: true,
          );
          expect((roll.arriving - roll.leaving!).abs(), closeTo(1, 1e-9));
        }
      }
    });
  });
}
