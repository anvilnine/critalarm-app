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
      expect(yearly.renewalLine, 'renews yearly');
      expect(yearly.title, 'Yearly');
      expect(monthly.perPeriodLine, isNull);
      expect(monthly.savingLabel, isNull);
      expect(monthly.renewalLine, 'renews monthly');
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

    test('a payment the store is holding is a paused check, never a '
        'failure and never a second purchase', () {
      final state = afterStore(buying, PaywallStoreResult.pending);
      expect(state.status, PaywallBuyStatus.checking);
      expect(state.isPaused, isTrue);
      expect(state.isBusy, isFalse);
      expect(state.messageKey, LocaleKeys.purchase_errors_payment_pending);
      expect(state.messageKey, isNot(LocaleKeys.paywall_kit_failed));
      expect(state.canBuy, isFalse);
      expect(state.canRestore, isTrue);
      expect(state.selectedId, PaywallPlanOption.yearlyId);
    });

    test('every Pro store result has its match, and the Pro shop has no '
        'word for a held payment', () {
      expect(ProPackStoreResult.values.map(storeResultOfProPack), [
        PaywallStoreResult.done,
        PaywallStoreResult.cancelled,
        PaywallStoreResult.problem,
      ]);
    });
  });

  group('a Hosted purchase that came back as a failure', () {
    PaywallStoreResult result(String? message) => storeResultOfPurchaseFailure(
      message,
      cancelledText: 'Backed out.',
      pendingText: 'Held.',
    );

    test('the cancel line is a cancel', () {
      expect(result('Backed out.'), PaywallStoreResult.cancelled);
    });

    test('the pending line is a held payment', () {
      expect(result('Held.'), PaywallStoreResult.pending);
    });

    test('any other line, or none, is a problem', () {
      expect(result('Network error.'), PaywallStoreResult.problem);
      expect(result('held.'), PaywallStoreResult.problem);
      expect(result(''), PaywallStoreResult.problem);
      expect(result(null), PaywallStoreResult.problem);
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

  group('what the block draws for a state', () {
    final hostedReady = restingState(
      _hosted,
      options: hostedPlanOptions(yearly: _yearly, monthly: _monthly),
    );
    final proReady = restingState(
      _pro,
      options: proPlanOptions(const [
        ProPackOffer(handle: 'a', title: 'STORE-TITLE', price: 'P-PRICE'),
      ]),
    );
    final proTwo = restingState(
      _pro,
      options: proPlanOptions(const [
        ProPackOffer(handle: 'a', title: 'A', price: 'A-PRICE'),
        ProPackOffer(handle: 'b', title: 'B', price: 'B-PRICE'),
      ]),
    );

    test('Hosted has a card per plan and Pro with one offer has none', () {
      expect(planCardCount(hostedReady), 2);
      expect(planCardCount(proReady), 0);
      expect(planCardCount(proTwo), 2);
    });

    test('one Hosted plan still gets its card, which says when it renews', () {
      final onlyMonthly = restingState(
        _hosted,
        options: hostedPlanOptions(yearly: null, monthly: _monthly),
      );
      expect(planCardCount(onlyMonthly), 1);
      expect(priceOnButton(onlyMonthly), isNull);
    });

    test('while loading Hosted holds room for two plans and Pro for none', () {
      expect(planCardCount(_hosted), 2);
      expect(planCardCount(_pro), 0);
      expect(priceOnButton(_pro), isNull);
    });

    test('the button names the product, and carries the price only where '
        'no card shows it', () {
      expect(buyButtonLabel(hostedReady, name: 'Hosted'), 'Get Hosted');
      expect(buyButtonLabel(proReady, name: 'Pro'), 'Get Pro · P-PRICE');
      expect(buyButtonLabel(proTwo, name: 'Pro'), 'Get Pro');
      expect(buyButtonLabel(_pro, name: 'Pro'), 'Get Pro');
    });

    test('the label is the same after a failed purchase', () {
      final failed = afterStore(proReady, PaywallStoreResult.problem);
      expect(failed.status, PaywallBuyStatus.failed);
      expect(buyButtonLabel(failed, name: 'Pro'), 'Get Pro · P-PRICE');
    });

    test('a held payment reads Check again, for either product', () {
      for (final ready in [hostedReady, proReady]) {
        final held = afterStore(ready, PaywallStoreResult.pending);
        expect(held.messageKey, LocaleKeys.purchase_errors_payment_pending);
        expect(buyButtonLabel(held, name: 'X'), 'Check again');
      }
    });

    test('a check that is still running keeps the product label', () {
      final checking = afterStore(hostedReady, PaywallStoreResult.done);
      expect(checking.isPaused, isFalse);
      expect(buyButtonLabel(checking, name: 'Hosted'), 'Get Hosted');
    });

    test('the second line of a card is the per month figure, or when the '
        'plan renews', () {
      final [yearly, monthly] = hostedPlanOptions(
        yearly: _yearly,
        monthly: _monthly,
      );
      expect(planCardSecondLine(yearly), 'Y-PER-MONTH / month');
      expect(planCardSecondLine(monthly), 'renews monthly');

      final plainYearly = hostedPlanOptions(
        yearly: const HostedPlanQuote(priceString: 'Y-PRICE', price: _y),
        monthly: null,
      ).single;
      expect(planCardSecondLine(plainYearly), 'renews yearly');

      final offer = proPlanOptions(const [
        ProPackOffer(handle: 'a', title: 'A', price: 'A-PRICE'),
      ]).single;
      expect(planCardSecondLine(offer), isNull);
    });

    test('the badge is the saving, on the yearly card only, and only when '
        'the prices show one', () {
      final [yearly, monthly] = hostedPlanOptions(
        yearly: _yearly,
        monthly: _monthly,
      );
      expect(planCardBadge(yearly), 'Save 33%');
      expect(planCardBadge(monthly), isNull);

      final plainYearly = hostedPlanOptions(
        yearly: _yearly,
        monthly: null,
      ).single;
      expect(planCardBadge(plainYearly), isNull);
    });

    test('the picker keeps room for a badge only when a card has one', () {
      expect(planPickerKeepsBadgeRoom(hostedReady), isTrue);

      final noSaving = restingState(
        _hosted,
        options: hostedPlanOptions(yearly: _yearly, monthly: null),
      );
      expect(planPickerKeepsBadgeRoom(noSaving), isFalse);
      // Pro has no card at all with one offer.
      expect(planPickerKeepsBadgeRoom(proReady), isFalse);
    });

    test('while the store is asked, Hosted holds the badge room so the '
        'cards do not move when the prices arrive', () {
      expect(planPickerKeepsBadgeRoom(_hosted), isTrue);
      expect(planPickerKeepsBadgeRoom(_pro), isFalse);
    });
  });

  group('the legal line', () {
    final ready = restingState(
      _hosted,
      options: hostedPlanOptions(yearly: _yearly, monthly: _monthly),
    );

    test('Hosted says the picked price, how often it renews, that it goes '
        'on until cancelled, and where to cancel', () {
      final yearly = legalLine(ready, store: 'STORE');
      expect(yearly, contains('Renews at Y-PRICE a year until you cancel.'));
      expect(yearly, contains('Cancel any time in your STORE.'));

      final monthly = legalLine(
        ready.copyWith(selectedId: PaywallPlanOption.monthlyId),
        store: 'STORE',
      );
      expect(monthly, contains('Renews at M-PRICE a month until you cancel.'));
      expect(monthly, contains('Cancel any time in your STORE.'));
    });

    test('each Hosted sentence starts its own line, so none is cut', () {
      expect(legalLine(ready, store: 'STORE').split('\n'), hasLength(2));
    });

    test('with no plan picked yet it still says it renews and where to '
        'cancel, and names no price', () {
      final line = legalLine(_hosted, store: 'STORE');
      expect(line, contains('Renews until you cancel.'));
      expect(line, contains('Cancel any time in your STORE.'));
    });

    test('Pro says who charges and nothing about renewing', () {
      final line = legalLine(
        restingState(
          _pro,
          options: proPlanOptions(const [
            ProPackOffer(handle: 'a', title: 'A', price: 'A-PRICE'),
          ]),
        ),
        store: 'STORE',
      );
      expect(line, 'Charged to your STORE.');
      expect(line.toLowerCase(), isNot(contains('renew')));
    });
  });
}
