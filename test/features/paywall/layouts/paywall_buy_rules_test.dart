import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/demo_paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_rules.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_shop.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter_test/flutter_test.dart';

// Made-up amounts. No plan costs these.
const double _m = 10; // l10n-ok: demo data
const double _y = 80; // l10n-ok: demo data
const _yearly = HostedPlanQuote(
  priceString: 'Y-PRICE',
  price: _y,
  pricePerMonthString: 'Y-PER-MONTH',
);
const _monthly = HostedPlanQuote(priceString: 'M-PRICE', price: _m);

const _hosted = PaywallBuyState(product: PaywallProduct.hosted);
const _pro = PaywallBuyState(product: PaywallProduct.pro);

void main() {
  group('Hosted options', () {
    test('yearly is first, then monthly', () {
      final options = hostedPlanOptions(yearly: _yearly, monthly: _monthly);
      expect(options.map((o) => o.id), [
        PaywallPlanOption.yearlyId,
        PaywallPlanOption.monthlyId,
      ]);
      expect(options.first.isYearly, isTrue);
      expect(options.last.isYearly, isFalse);
    });

    test('yearly is the default pick', () {
      final options = hostedPlanOptions(yearly: _yearly, monthly: _monthly);
      expect(defaultPlanOptionId(options), PaywallPlanOption.yearlyId);
      expect(defaultPlanOptionId(const []), isNull);
    });

    test('the price is the store string, untouched', () {
      final options = hostedPlanOptions(yearly: _yearly, monthly: _monthly);
      expect(options.first.price, 'Y-PRICE');
      expect(options.last.price, 'M-PRICE');
    });

    test('yearly carries the per month figure, the saving and the renewal '
        'line, and monthly only the renewal line', () {
      final [yearly, monthly] = hostedPlanOptions(
        yearly: _yearly,
        monthly: _monthly,
      );
      expect(yearly.perPeriodLine, 'Y-PER-MONTH / month');
      expect(yearly.savingLabel, 'Save 33%');
      expect(yearly.renewalLine, '12 months, renews yearly');
      expect(yearly.title, 'Yearly');
      expect(monthly.perPeriodLine, isNull);
      expect(monthly.savingLabel, isNull);
      expect(monthly.renewalLine, '1 month, renews monthly');
      expect(monthly.title, 'Monthly');
    });

    test('a plan the store did not send is left out, never made up', () {
      final onlyMonthly = hostedPlanOptions(yearly: null, monthly: _monthly);
      expect(onlyMonthly.map((o) => o.id), [PaywallPlanOption.monthlyId]);
      expect(defaultPlanOptionId(onlyMonthly), PaywallPlanOption.monthlyId);

      final onlyYearly = hostedPlanOptions(yearly: _yearly, monthly: null);
      expect(onlyYearly.single.savingLabel, isNull);
      expect(hostedPlanOptions(yearly: null, monthly: null), isEmpty);
    });

    test('no per month line when the store gives no such figure', () {
      const bare = HostedPlanQuote(priceString: 'Y-PRICE', price: _y);
      const empty = HostedPlanQuote(
        priceString: 'Y-PRICE',
        price: _y,
        pricePerMonthString: '',
      );
      for (final yearly in [bare, empty]) {
        final options = hostedPlanOptions(yearly: yearly, monthly: _monthly);
        expect(options.first.perPeriodLine, isNull);
      }
    });
  });

  group('the saving label', () {
    test('is the whole percent yearly saves against twelve months', () {
      expect(yearlySavingLabel(monthlyPrice: _m, yearlyPrice: _y), 'Save 33%');
      expect(
        yearlySavingLabel(monthlyPrice: _m, yearlyPrice: _m * 6),
        'Save 50%',
      );
    });

    test('is missing when a price is missing', () {
      expect(yearlySavingLabel(monthlyPrice: null, yearlyPrice: _y), isNull);
      expect(yearlySavingLabel(monthlyPrice: _m, yearlyPrice: null), isNull);
    });

    test('is missing when yearly is not cheaper', () {
      expect(
        yearlySavingLabel(monthlyPrice: _m, yearlyPrice: _m * 12),
        isNull,
      );
      expect(
        yearlySavingLabel(monthlyPrice: _m, yearlyPrice: _m * 13),
        isNull,
      );
      expect(yearlySavingLabel(monthlyPrice: 0, yearlyPrice: _y), isNull);
    });
  });

  group('Pro options', () {
    const a = ProPackOffer(handle: 'a', title: 'Store title A', price: 'P1');
    const b = ProPackOffer(handle: 'b', title: 'Store title B', price: 'P2');

    test('are the store title and price as they come, in store order', () {
      final options = proPlanOptions(const [a, b]);
      expect(options.map((o) => (o.id, o.title, o.price)), [
        ('a', 'Store title A', 'P1'),
        ('b', 'Store title B', 'P2'),
      ]);
      expect(defaultPlanOptionId(options), 'a');
    });

    test('add no word of their own about how Pro is paid', () {
      for (final option in proPlanOptions(const [a, b])) {
        expect(option.perPeriodLine, isNull);
        expect(option.savingLabel, isNull);
        expect(option.renewalLine, isNull);
      }
    });
  });

  group('a build that skips the store', () {
    test('has two Hosted options, yearly first', () {
      final options = demoPlanOptions(PaywallProduct.hosted);
      expect(options.map((o) => o.id), [
        PaywallPlanOption.yearlyId,
        PaywallPlanOption.monthlyId,
      ]);
      expect(options.every((o) => o.price.isNotEmpty), isTrue);
      expect(options.first.savingLabel, isNotNull);
      expect(options.first.perPeriodLine, isNotNull);
    });

    test('has one Pro option', () {
      final options = demoPlanOptions(PaywallProduct.pro);
      expect(options, hasLength(1));
      expect(options.single.title, isNotEmpty);
      expect(options.single.price, isNotEmpty);
    });
  });

  group('the resting state', () {
    final options = hostedPlanOptions(yearly: _yearly, monthly: _monthly);

    test('with options is ready with the default picked', () {
      final state = restingState(_hosted, options: options);
      expect(state.status, PaywallBuyStatus.ready);
      expect(state.selectedId, PaywallPlanOption.yearlyId);
      expect(state.canBuy, isTrue);
      expect(state.canRestore, isTrue);
    });

    test('with none is not on sale, and Restore is still there', () {
      final state = restingState(_pro, options: const []);
      expect(state.status, PaywallBuyStatus.notOnSale);
      expect(state.selectedId, isNull);
      expect(state.canBuy, isFalse);
      expect(state.canRestore, isTrue);
    });

    test('keeps a pick the buyer made', () {
      final picked = restingState(
        _hosted,
        options: options,
      ).copyWith(selectedId: PaywallPlanOption.monthlyId);
      expect(restingState(picked).selectedId, PaywallPlanOption.monthlyId);
    });

    test('drops a pick whose option is gone', () {
      final picked = restingState(
        _hosted,
        options: options,
      ).copyWith(selectedId: PaywallPlanOption.monthlyId);
      final next = restingState(picked, options: [options.first]);
      expect(next.selectedId, PaywallPlanOption.yearlyId);
    });
  });

  group('after the store', () {
    final ready = restingState(
      _hosted,
      options: hostedPlanOptions(yearly: _yearly, monthly: _monthly),
    );
    final buying = ready.copyWith(status: PaywallBuyStatus.purchasing);

    test('backing out is not a failure and says nothing', () {
      final state = afterStore(buying, PaywallStoreResult.cancelled);
      expect(state.status, PaywallBuyStatus.ready);
      expect(state.messageKey, isNull);
    });

    test('a problem is failed with a plain line, and can be tried again', () {
      final state = afterStore(buying, PaywallStoreResult.problem);
      expect(state.status, PaywallBuyStatus.failed);
      expect(state.messageKey, LocaleKeys.paywall_kit_failed);
      expect(state.canBuy, isTrue);
      expect(state.canRestore, isTrue);
      expect(state.selectedId, PaywallPlanOption.yearlyId);
    });

    test('a problem with nothing on sale stays not on sale', () {
      final restoring = restingState(
        _pro,
        options: const [],
      ).copyWith(status: PaywallBuyStatus.purchasing);
      final state = afterStore(restoring, PaywallStoreResult.problem);
      expect(state.status, PaywallBuyStatus.notOnSale);
      expect(state.messageKey, LocaleKeys.paywall_kit_failed);
    });

    test('a finished store only starts the confirming', () {
      final state = afterStore(buying, PaywallStoreResult.done);
      expect(state.status, PaywallBuyStatus.checking);
      expect(state.isPaused, isFalse);
      expect(state.isBusy, isTrue);
      expect(state.messageKey, isNull);
    });

    test('every Pro store result has its match', () {
      expect(
        ProPackStoreResult.values.map(storeResultOfProPack),
        PaywallStoreResult.values,
      );
    });
  });

  group('after one confirm answer', () {
    PaywallConfirmStep step(
      PaywallConfirmAnswer answer, {
      required bool afterPurchase,
      bool hasTriesLeft = true,
    }) => afterConfirm(
      answer,
      afterPurchase: afterPurchase,
      hasTriesLeft: hasTriesLeft,
    );

    test('held is done, whatever came before', () {
      for (final afterPurchase in [true, false]) {
        for (final hasTriesLeft in [true, false]) {
          expect(
            step(
              PaywallConfirmAnswer.held,
              afterPurchase: afterPurchase,
              hasTriesLeft: hasTriesLeft,
            ),
            PaywallConfirmStep.done,
          );
        }
      }
    });

    test('after a restore, a store that holds nothing is the answer', () {
      expect(
        step(PaywallConfirmAnswer.notHeld, afterPurchase: false),
        PaywallConfirmStep.nothingToRestore,
      );
    });

    test('after a purchase, "not held" only means ask again', () {
      expect(
        step(PaywallConfirmAnswer.notHeld, afterPurchase: true),
        PaywallConfirmStep.askAgain,
      );
    });

    test('an answer that says nothing is asked again', () {
      for (final afterPurchase in [true, false]) {
        expect(
          step(PaywallConfirmAnswer.unknown, afterPurchase: afterPurchase),
          PaywallConfirmStep.askAgain,
        );
      }
    });

    test('when the tries run out the check pauses, it never fails', () {
      expect(
        step(
          PaywallConfirmAnswer.unknown,
          afterPurchase: true,
          hasTriesLeft: false,
        ),
        PaywallConfirmStep.paused,
      );
      expect(
        step(
          PaywallConfirmAnswer.notHeld,
          afterPurchase: true,
          hasTriesLeft: false,
        ),
        PaywallConfirmStep.paused,
      );
      expect(
        step(
          PaywallConfirmAnswer.unknown,
          afterPurchase: false,
          hasTriesLeft: false,
        ),
        PaywallConfirmStep.paused,
      );
    });

    test('the refresh table maps one to one', () {
      expect(
        confirmAnswerOfProPack(ProPackRefreshOutcome.held),
        PaywallConfirmAnswer.held,
      );
      expect(
        confirmAnswerOfProPack(ProPackRefreshOutcome.notHeld),
        PaywallConfirmAnswer.notHeld,
      );
      expect(
        confirmAnswerOfProPack(ProPackRefreshOutcome.unknown),
        PaywallConfirmAnswer.unknown,
      );
    });

    test('confirmed false with no pack listed never ends a purchase', () {
      final answer = confirmAnswerOfProPack(
        proPackRefreshOutcome(confirmed: false, listed: false),
      );
      expect(
        step(answer, afterPurchase: true),
        PaywallConfirmStep.askAgain,
      );
      expect(
        step(answer, afterPurchase: true, hasTriesLeft: false),
        PaywallConfirmStep.paused,
      );
    });
  });

  group('the state a confirm step leaves', () {
    final checking = restingState(
      _pro,
      options: demoPlanOptions(PaywallProduct.pro),
    ).copyWith(status: PaywallBuyStatus.checking);

    PaywallBuyState after(PaywallConfirmStep step) =>
        afterConfirmStep(checking, step, pausedKey: 'paused.key');

    test('done', () {
      final state = after(PaywallConfirmStep.done);
      expect(state.status, PaywallBuyStatus.done);
      expect(state.canBuy, isFalse);
      expect(state.canRestore, isFalse);
    });

    test('nothing to restore rests on the options with one line', () {
      final state = after(PaywallConfirmStep.nothingToRestore);
      expect(state.status, PaywallBuyStatus.ready);
      expect(state.messageKey, LocaleKeys.paywall_kit_nothing_to_restore);
    });

    test('paused is still checking, with its line, and can ask again', () {
      final state = after(PaywallConfirmStep.paused);
      expect(state.status, PaywallBuyStatus.checking);
      expect(state.isPaused, isTrue);
      expect(state.isBusy, isFalse);
      expect(state.messageKey, 'paused.key');
      expect(state.canRestore, isTrue);
      expect(state.canBuy, isFalse);
    });

    test('ask again keeps checking and says nothing', () {
      final state = after(PaywallConfirmStep.askAgain);
      expect(state.status, PaywallBuyStatus.checking);
      expect(state.isPaused, isFalse);
      expect(state.messageKey, isNull);
    });
  });
}
