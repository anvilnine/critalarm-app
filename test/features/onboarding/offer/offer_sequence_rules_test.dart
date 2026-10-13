import 'package:critalarm/core/paywall/paywall_intro.dart';
import 'package:critalarm/features/onboarding/presentation/model/offer_sequence_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('whether the store can sell', () {
    test('ready goes on, timed out or not', () {
      for (final timedOut in [false, true]) {
        expect(
          offerSaleDecision(PaywallBuyStatus.ready, timedOut: timedOut),
          OfferSaleDecision.goOn,
        );
      }
    });

    test('not on sale and a failure skip at once', () {
      for (final status in [
        PaywallBuyStatus.notOnSale,
        PaywallBuyStatus.failed,
      ]) {
        for (final timedOut in [false, true]) {
          expect(
            offerSaleDecision(status, timedOut: timedOut),
            OfferSaleDecision.skip,
            reason: '$status $timedOut',
          );
        }
      }
    });

    test('no answer keeps waiting, then skips when time is up', () {
      expect(
        offerSaleDecision(null, timedOut: false),
        OfferSaleDecision.keepWaiting,
      );
      expect(offerSaleDecision(null, timedOut: true), OfferSaleDecision.skip);
      expect(
        offerSaleDecision(PaywallBuyStatus.loading, timedOut: false),
        OfferSaleDecision.keepWaiting,
      );
      expect(
        offerSaleDecision(PaywallBuyStatus.loading, timedOut: true),
        OfferSaleDecision.skip,
      );
    });

    test('a state that is not a rest after the question never goes on', () {
      for (final status in [
        PaywallBuyStatus.purchasing,
        PaywallBuyStatus.checking,
        PaywallBuyStatus.done,
      ]) {
        expect(
          offerSaleDecision(status, timedOut: false),
          OfferSaleDecision.skip,
          reason: '$status',
        );
      }
    });

    test('the wait is two seconds', () {
      expect(offerSaleWait, const Duration(seconds: 2));
    });

    test('only ready ever goes on', () {
      for (final status in [...PaywallBuyStatus.values, null]) {
        for (final timedOut in [false, true]) {
          expect(
            offerSaleDecision(status, timedOut: timedOut) ==
                OfferSaleDecision.goOn,
            status == PaywallBuyStatus.ready,
            reason: '$status $timedOut',
          );
        }
      }
    });
  });

  group('the false alarm showing', () {
    test('the offer plays the false alarm', () {
      expect(offerIntro, PaywallIntroId.falseAlarm);
    });

    test('a run that can play it uses it up', () {
      expect(
        offerUsesUpFalseAlarm(
          intro: offerIntro,
          isReplay: false,
          reduceMotion: false,
        ),
        isTrue,
      );
    });

    test('a replay writes nothing', () {
      for (final reduceMotion in [false, true]) {
        expect(
          offerUsesUpFalseAlarm(
            intro: offerIntro,
            isReplay: true,
            reduceMotion: reduceMotion,
          ),
          isFalse,
        );
      }
    });

    test('with reduced motion no intro plays, so none is used up', () {
      expect(
        offerUsesUpFalseAlarm(
          intro: offerIntro,
          isReplay: false,
          reduceMotion: true,
        ),
        isFalse,
      );
    });

    test('another intro never touches the flag', () {
      for (final intro in PaywallIntroId.values) {
        if (intro == PaywallIntroId.falseAlarm) continue;
        expect(
          offerUsesUpFalseAlarm(
            intro: intro,
            isReplay: false,
            reduceMotion: false,
          ),
          isFalse,
          reason: intro.key,
        );
      }
    });
  });

  group('a real alarm wins', () {
    test('the layer stays only while the step is here and no alarm rings', () {
      expect(
        offerLayerMayStay(stepIsHere: true, alarmIsUnderWay: false),
        isTrue,
      );
    });

    test('an alarm under way takes the layer off', () {
      expect(
        offerLayerMayStay(stepIsHere: true, alarmIsUnderWay: true),
        isFalse,
      );
    });

    test('the step going away takes the layer off', () {
      expect(
        offerLayerMayStay(stepIsHere: false, alarmIsUnderWay: false),
        isFalse,
      );
      expect(
        offerLayerMayStay(stepIsHere: false, alarmIsUnderWay: true),
        isFalse,
      );
    });

    test('the step going away ends the layer as interrupted', () {
      for (final didBuy in [false, true]) {
        expect(
          offerLayerEnd(didBuy: didBuy, stepIsHere: false),
          OfferLayerEnd.interrupted,
        );
      }
    });

    test('the step still here ends it as bought or closed', () {
      expect(
        offerLayerEnd(didBuy: true, stepIsHere: true),
        OfferLayerEnd.bought,
      );
      expect(
        offerLayerEnd(didBuy: false, stepIsHere: true),
        OfferLayerEnd.closed,
      );
    });
  });

  group('whether the user bought', () {
    test('the thanks button says so', () {
      expect(
        offerDidBuy(layerResult: true, status: PaywallBuyStatus.done),
        isTrue,
      );
    });

    test('a close, or a back gesture, before a purchase says no', () {
      expect(
        offerDidBuy(layerResult: null, status: PaywallBuyStatus.ready),
        isFalse,
      );
      expect(
        offerDidBuy(layerResult: false, status: PaywallBuyStatus.failed),
        isFalse,
      );
    });

    test('a back gesture from the thanks still counts as a purchase', () {
      expect(
        offerDidBuy(layerResult: null, status: PaywallBuyStatus.done),
        isTrue,
      );
    });
  });
}
