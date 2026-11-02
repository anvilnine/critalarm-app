import 'package:critalarm/features/incidents/domain/ack_confetti_rule.dart';
import 'package:critalarm/features/incidents/domain/setup_test_kind.dart';
import 'package:critalarm/features/onboarding/domain/offer/onboarding_offer_rule.dart';
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
    const answers = <OfferOutlook?>[...OfferOutlook.values, null];

    // W4: a setup test that did not reach the phone, or rang muted, is not
    // celebrated.
    test('a setup test not proved throws nothing, whatever the offer', () {
      for (final offer in answers) {
        expect(
          ackConfettiMayFly(
            exits: AckedExits.continueSetup,
            offer: offer,
            reduceMotion: false,
            setupProved: false,
          ),
          isFalse,
          reason: '$offer',
        );
      }
      expect(
        ackConfettiMayFly(
          exits: AckedExits.incident,
          offer: null,
          reduceMotion: false,
          setupProved: false,
        ),
        isTrue,
      );
    });

    test('every exit but the setup test ignores the offer answer', () {
      for (final exits in others) {
        for (final offer in answers) {
          expect(
            ackConfettiMayFly(
              exits: exits,
              offer: offer,
              reduceMotion: false,
            ),
            isTrue,
            reason: '$exits with the offer answer $offer',
          );
        }
      }
    });

    test('the setup test throws when no offer follows', () {
      expect(
        ackConfettiMayFly(
          exits: AckedExits.continueSetup,
          offer: OfferOutlook.none,
          reduceMotion: false,
        ),
        isTrue,
      );
    });

    test('the setup test stays calm when the offer follows and sells', () {
      expect(
        ackConfettiMayFly(
          exits: AckedExits.continueSetup,
          offer: OfferOutlook.coming,
          reduceMotion: false,
        ),
        isFalse,
      );
    });

    test('the setup test throws while the store has not answered', () {
      // A session is never left with no celebration. The offer still shows
      // afterwards only if the product turns out to be buyable.
      expect(
        ackConfettiMayFly(
          exits: AckedExits.continueSetup,
          offer: OfferOutlook.unsure,
          reduceMotion: false,
        ),
        isTrue,
      );
    });

    test('the setup test waits while the gate has not answered', () {
      expect(
        ackConfettiMayFly(
          exits: AckedExits.continueSetup,
          offer: null,
          reduceMotion: false,
        ),
        isFalse,
      );
    });

    test('reduced motion throws nothing for any exit or answer', () {
      for (final exits in AckedExits.values) {
        for (final offer in answers) {
          expect(
            ackConfettiMayFly(
              exits: exits,
              offer: offer,
              reduceMotion: true,
            ),
            isFalse,
            reason: '$exits with the offer answer $offer',
          );
        }
      }
    });
  });
}
