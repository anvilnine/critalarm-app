import 'package:critalarm/features/incidents/domain/ack_confetti_rule.dart';
import 'package:critalarm/features/incidents/domain/setup_test_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ackConfettiMayFly', () {
    const others = [
      AckedExits.incident,
      AckedExits.firstToolAlarm,
      AckedExits.retest,
      AckedExits.legacyCreateTopicOrFinish,
      AckedExits.legacyFinish,
    ];

    test('every exit but the setup test ignores the offer answer', () {
      for (final exits in others) {
        for (final isOfferAhead in <bool?>[true, false, null]) {
          expect(
            ackConfettiMayFly(
              exits: exits,
              isOfferAhead: isOfferAhead,
              reduceMotion: false,
            ),
            isTrue,
            reason: '$exits with the offer answer $isOfferAhead',
          );
        }
      }
    });

    test(
      'the setup test throws only once the offer is known not to follow',
      () {
        expect(
          ackConfettiMayFly(
            exits: AckedExits.continueSetup,
            isOfferAhead: false,
            reduceMotion: false,
          ),
          isTrue,
        );
      },
    );

    test('the setup test stays calm when the offer follows', () {
      expect(
        ackConfettiMayFly(
          exits: AckedExits.continueSetup,
          isOfferAhead: true,
          reduceMotion: false,
        ),
        isFalse,
      );
    });

    test('the setup test waits while the offer answer is not known', () {
      expect(
        ackConfettiMayFly(
          exits: AckedExits.continueSetup,
          isOfferAhead: null,
          reduceMotion: false,
        ),
        isFalse,
      );
    });

    test('reduced motion throws nothing for any exit or answer', () {
      for (final exits in AckedExits.values) {
        for (final isOfferAhead in <bool?>[true, false, null]) {
          expect(
            ackConfettiMayFly(
              exits: exits,
              isOfferAhead: isOfferAhead,
              reduceMotion: true,
            ),
            isFalse,
            reason: '$exits with the offer answer $isOfferAhead',
          );
        }
      }
    });
  });
}
