import 'dart:async';

import 'package:critalarm/features/onboarding/domain/offer/onboarding_offer_rule.dart';
import 'package:critalarm/features/onboarding/presentation/model/offer_sale_probe.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/demo_paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// A buy model whose store answers when the test says so.
class _StoreCubit extends DemoPaywallBuyCubit {
  _StoreCubit(super.product, {super.startAs});

  final Completer<void> answer = Completer<void>();
  int loads = 0;

  @override
  Future<void> load() async {
    loads++;
    await answer.future;
    await super.load();
  }
}

class _ThrowingCubit extends DemoPaywallBuyCubit {
  _ThrowingCubit(super.product);

  @override
  Future<void> load() async => throw StateError('store down');
}

void main() {
  late List<PaywallBuyCubit> made;

  OfferSaleProbe probeWith(PaywallBuyCubit Function(PaywallProduct) make) =>
      OfferSaleProbe(
        makeBuyModel: (product) {
          final model = make(product);
          made.add(model);
          return model;
        },
      );

  setUp(() => made = []);

  group('the answer the "It works" screen reads', () {
    test('is unknown before a check starts', () {
      final probe = probeWith(DemoPaywallBuyCubit.new);
      expect(
        probe.answerFor(PaywallProduct.hosted),
        OfferSaleAnswer.unknown,
      );
    });

    test('is unknown while the store has not answered, then on sale', () async {
      final store = _StoreCubit(PaywallProduct.hosted);
      final probe = probeWith((_) => store)..start(PaywallProduct.hosted);
      expect(probe.answerFor(PaywallProduct.hosted), OfferSaleAnswer.unknown);
      store.answer.complete();
      await Future<void>.delayed(Duration.zero);
      expect(probe.answerFor(PaywallProduct.hosted), OfferSaleAnswer.onSale);
    });

    test('is not on sale for a product the store lists nothing for', () async {
      final probe = probeWith(
        (product) => DemoPaywallBuyCubit(
          product,
          startAs: PaywallBuyStatus.notOnSale,
        ),
      )..start(PaywallProduct.hosted);
      await Future<void>.delayed(Duration.zero);
      expect(
        probe.answerFor(PaywallProduct.hosted),
        OfferSaleAnswer.notOnSale,
      );
    });

    test('is not on sale when the store failed', () async {
      final probe = probeWith(_ThrowingCubit.new)..start(PaywallProduct.hosted);
      await Future<void>.delayed(Duration.zero);
      expect(
        probe.answerFor(PaywallProduct.hosted),
        OfferSaleAnswer.notOnSale,
      );
    });

    test('says nothing about a product it did not start for', () async {
      final probe = probeWith(DemoPaywallBuyCubit.new)
        ..start(PaywallProduct.hosted);
      await Future<void>.delayed(Duration.zero);
      expect(probe.answerFor(PaywallProduct.pro), OfferSaleAnswer.unknown);
    });

    test('starting twice for one product asks the store once', () async {
      final probe = probeWith(_StoreCubit.new)
        ..start(PaywallProduct.hosted)
        ..start(PaywallProduct.hosted);
      expect(made, hasLength(1));
      expect((made.single as _StoreCubit).loads, 1);
      probe.discard();
    });

    test('a start for another product closes the first model', () async {
      final probe = probeWith(DemoPaywallBuyCubit.new)
        ..start(PaywallProduct.hosted)
        ..start(PaywallProduct.pro);
      expect(made, hasLength(2));
      expect(made.first.isClosed, isTrue);
      expect(made.last.isClosed, isFalse);
      probe.discard();
    });
  });

  group('the model the offer step takes', () {
    test('a cached on sale answer is handed over with no wait', () async {
      final probe = probeWith(DemoPaywallBuyCubit.new)
        ..start(PaywallProduct.hosted);
      await Future<void>.delayed(Duration.zero);
      final model = await probe.takeOnSale(
        PaywallProduct.hosted,
        wait: Duration.zero,
      );
      expect(model, same(made.single));
      expect(model!.isClosed, isFalse);
      expect(made, hasLength(1), reason: 'the step asked the store no more');
      // The probe let go of it: the caller owns it.
      expect(
        probe.answerFor(PaywallProduct.hosted),
        OfferSaleAnswer.unknown,
      );
    });

    test('a cached no answer skips with the model closed', () async {
      final probe = probeWith(
        (product) => DemoPaywallBuyCubit(
          product,
          startAs: PaywallBuyStatus.notOnSale,
        ),
      )..start(PaywallProduct.hosted);
      await Future<void>.delayed(Duration.zero);
      expect(
        await probe.takeOnSale(PaywallProduct.hosted, wait: Duration.zero),
        isNull,
      );
      expect(made.single.isClosed, isTrue);
    });

    test('an answer that comes while the step waits is used', () async {
      final store = _StoreCubit(PaywallProduct.hosted);
      final probe = probeWith((_) => store)..start(PaywallProduct.hosted);
      final taken = probe.takeOnSale(
        PaywallProduct.hosted,
        wait: const Duration(seconds: 5),
      );
      store.answer.complete();
      expect(await taken, same(store));
    });

    test('a store that does not answer in time skips', () async {
      final store = _StoreCubit(PaywallProduct.hosted);
      final probe = probeWith((_) => store)..start(PaywallProduct.hosted);
      final model = await probe.takeOnSale(
        PaywallProduct.hosted,
        wait: const Duration(milliseconds: 20),
      );
      expect(model, isNull);
      expect(store.isClosed, isTrue);
    });

    test('a store that fails skips at once, not after the wait', () async {
      final probe = probeWith(_ThrowingCubit.new);
      final watch = Stopwatch()..start();
      final model = await probe.takeOnSale(
        PaywallProduct.hosted,
        wait: const Duration(seconds: 5),
      );
      expect(model, isNull);
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test(
      'with no check started it makes the model and asks the store',
      () async {
        final probe = probeWith(DemoPaywallBuyCubit.new);
        final model = await probe.takeOnSale(PaywallProduct.pro);
        expect(model, same(made.single));
        expect(model!.state.status, PaywallBuyStatus.ready);
      },
    );

    test('a model that cannot be made is a store that cannot sell', () async {
      final probe = OfferSaleProbe(
        makeBuyModel: (_) => throw StateError('no model'),
      )..start(PaywallProduct.hosted);
      expect(probe.answerFor(PaywallProduct.hosted), OfferSaleAnswer.unknown);
      expect(await probe.takeOnSale(PaywallProduct.hosted), isNull);
    });

    test('discard closes the model that was never taken', () async {
      final probe = probeWith(DemoPaywallBuyCubit.new)
        ..start(PaywallProduct.hosted)
        ..discard();
      expect(made.single.isClosed, isTrue);
      expect(probe.answerFor(PaywallProduct.hosted), OfferSaleAnswer.unknown);
    });
  });
}
