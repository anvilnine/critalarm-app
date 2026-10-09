import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/features/settings/domain/personalize/own_photo_try_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ownPhotoDestinationFor', () {
    OwnPhotoDestination destination(
      FeatureDecision decision, {
      bool isPlanRead = true,
    }) => ownPhotoDestinationFor(decision: decision, isPlanRead: isPlanRead);

    test('an open look is saved', () {
      expect(
        destination(const FeatureDecision.open()),
        OwnPhotoDestination.save,
      );
    });

    test('a look being confirmed is saved: the purchase is on its way', () {
      expect(
        destination(const FeatureDecision.confirming(Holding.pro)),
        OwnPhotoDestination.save,
      );
    });

    test('a locked look is held, not saved', () {
      expect(
        destination(const FeatureDecision.locked(Holding.pro)),
        OwnPhotoDestination.hold,
      );
      expect(
        destination(const FeatureDecision.locked(Holding.hosted)),
        OwnPhotoDestination.hold,
      );
    });

    test('a look that is not offered is held, not saved', () {
      expect(
        destination(const FeatureDecision.notOffered()),
        OwnPhotoDestination.hold,
      );
    });

    test('nothing is saved on a plan that has not been read', () {
      for (final decision in [
        const FeatureDecision.open(),
        const FeatureDecision.locked(Holding.pro),
        const FeatureDecision.confirming(Holding.pro),
        const FeatureDecision.unread(Holding.pro),
      ]) {
        expect(
          destination(decision, isPlanRead: false),
          OwnPhotoDestination.hold,
          reason: '$decision',
        );
      }
    });
  });
}
