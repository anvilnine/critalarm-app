import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_thanks.dart';
import 'package:critalarm/core/telemetry/paywall_layout_analytics.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/demo_paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_reporter.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingGate extends NoopTelemetryGate {
  final events = <List<Object?>>[];

  @override
  Future<void> logEvent(
    String name, [
    Map<String, Object?>? parameters,
  ]) async => events.add([name, parameters]);
}

PaywallBuyState _ready(PaywallProduct product) => restingState(
  PaywallBuyState(product: product),
  options: demoPlanOptions(product),
);

void main() {
  late _RecordingGate gate;

  PaywallLayoutReporter reporter(PaywallProduct product, String source) =>
      PaywallLayoutReporter(
        PaywallLayoutAnalytics(
          gate,
          layout: PaywallLayoutId.sheet,
          isHosted: product == PaywallProduct.hosted,
        ),
        source: source,
      );

  setUp(() => gate = _RecordingGate());

  test('a Hosted layout sends the shipped paywall events', () {
    final ready = _ready(PaywallProduct.hosted);
    const tags = {
      'layout': 'sheet',
      'intro': 'none',
      'thanks': 'none',
      'product': 'hosted',
    };
    reporter(PaywallProduct.hosted, 'history')
      ..viewed()
      ..started(PaywallBuyAction.purchase, ready)
      ..finished(
        PaywallBuyAction.purchase,
        ready.copyWith(status: PaywallBuyStatus.done),
      )
      ..finished(PaywallBuyAction.purchase, ready)
      ..finished(
        PaywallBuyAction.purchase,
        afterStore(ready, PaywallStoreResult.problem),
      )
      ..finished(
        PaywallBuyAction.purchase,
        afterStore(ready, PaywallStoreResult.pending),
      )
      ..finished(
        PaywallBuyAction.restore,
        afterConfirmStep(
          ready,
          PaywallConfirmStep.nothingToRestore,
          pausedKey: LocaleKeys.paywall_kit_paused,
        ),
      )
      ..closed();

    expect(gate.events, [
      [
        'paywall_viewed',
        {'source': 'history', ...tags},
      ],
      [
        'paywall_purchase_started',
        {'plan': 'yearly', ...tags},
      ],
      [
        'paywall_purchase_completed',
        {'plan': 'yearly', ...tags},
      ],
      [
        'paywall_purchase_failed',
        {'plan': 'yearly', 'reason': 'cancelled', ...tags},
      ],
      [
        'paywall_purchase_failed',
        {'plan': 'yearly', 'reason': 'failed', ...tags},
      ],
      [
        'paywall_purchase_failed',
        {'plan': 'yearly', 'reason': 'failed', ...tags},
      ],
      [
        'paywall_restore_finished',
        {'result': 'none', ...tags},
      ],
      [
        'paywall_closed',
        {'source': 'history', ...tags},
      ],
    ]);
  });

  test('a Pro layout sends the Pro sheet events and names no plan', () {
    final ready = _ready(PaywallProduct.pro);
    const tags = {
      'layout': 'sheet',
      'intro': 'none',
      'thanks': 'none',
      'product': 'pro',
    };
    final paused = afterConfirmStep(
      ready,
      PaywallConfirmStep.paused,
      pausedKey: LocaleKeys.paywall_kit_paused,
    );
    reporter(PaywallProduct.pro, 'reliability')
      ..viewed()
      ..started(PaywallBuyAction.purchase, ready)
      ..finished(
        PaywallBuyAction.purchase,
        ready.copyWith(status: PaywallBuyStatus.done),
      )
      ..finished(PaywallBuyAction.purchase, paused)
      // The Pro sheet says nothing for a cancel or a store problem.
      ..finished(PaywallBuyAction.purchase, ready)
      ..finished(
        PaywallBuyAction.purchase,
        afterStore(ready, PaywallStoreResult.problem),
      )
      ..started(PaywallBuyAction.restore, ready)
      ..finished(PaywallBuyAction.restore, paused)
      ..closed();

    expect(gate.events, [
      [
        'pro_pack_sheet_opened',
        {'source': 'reliability', ...tags},
      ],
      ['pro_pack_purchase_started', tags],
      [
        'pro_pack_purchase_finished',
        {'result': 'held', ...tags},
      ],
      [
        'pro_pack_purchase_finished',
        {'result': 'checking', ...tags},
      ],
      [
        'pro_pack_restore_finished',
        {'result': 'checking', ...tags},
      ],
      [
        'pro_pack_closed',
        {'source': 'reliability', ...tags},
      ],
    ]);
  });

  test('no event carries a price, a store product or a variant', () {
    for (final product in PaywallProduct.values) {
      final ready = _ready(product);
      reporter(product, 'direct')
        ..viewed()
        ..started(PaywallBuyAction.purchase, ready)
        ..finished(
          PaywallBuyAction.purchase,
          ready.copyWith(status: PaywallBuyStatus.done),
        )
        ..thanksShown('purchase')
        ..thanksLeft('purchase', how: 'button', skipped: true)
        ..closed();
    }
    const allowed = {
      'source',
      'plan',
      'reason',
      'result',
      'layout',
      'intro',
      'thanks',
      'kind',
      'how',
      'skipped',
      'product',
    };
    for (final event in gate.events) {
      final parameters = event[1]! as Map<String, Object?>;
      expect(allowed.containsAll(parameters.keys), isTrue);
      expect(parameters.values.join(' '), isNot(contains(r'$')));
      expect(parameters.values, isNot(contains('demo')));
    }
  });

  test('the step after a purchase says it showed and how it was left', () {
    for (final product in PaywallProduct.values) {
      gate.events.clear();
      final tags = {
        'layout': 'sheet',
        'intro': 'none',
        'thanks': 'confetti',
        'product': product.key,
      };
      PaywallLayoutReporter(
          PaywallLayoutAnalytics(
            gate,
            layout: PaywallLayoutId.sheet,
            isHosted: product == PaywallProduct.hosted,
            thanks: PaywallThanksId.confetti,
          ),
          source: 'history',
        )
        ..thanksShown('purchase')
        ..thanksLeft('purchase', how: 'button', skipped: false)
        ..thanksShown('restore')
        ..thanksLeft('restore', how: 'away', skipped: true);

      // The same two names for both products. Whether a tap cut the show
      // short goes as a number: analytics takes no true or false.
      expect(gate.events, [
        [
          'paywall_thanks_shown',
          {'kind': 'purchase', ...tags},
        ],
        [
          'paywall_thanks_left',
          {'kind': 'purchase', 'how': 'button', 'skipped': 0, ...tags},
        ],
        [
          'paywall_thanks_shown',
          {'kind': 'restore', ...tags},
        ],
        [
          'paywall_thanks_left',
          {'kind': 'restore', 'how': 'away', 'skipped': 1, ...tags},
        ],
      ]);
    }
  });

  test('the buy cubit reports a purchase from start to rest', () async {
    final cubit = DemoPaywallBuyCubit(
      PaywallProduct.hosted,
      stepTime: Duration.zero,
    )..reporter = reporter(PaywallProduct.hosted, 'direct');
    await cubit.load();
    await cubit.buy();
    await cubit.restore();
    await cubit.close();

    expect(
      [for (final event in gate.events) event.first],
      [
        'paywall_purchase_started',
        'paywall_purchase_completed',
        'paywall_closed',
      ],
    );
  });

  test('a paywall closed while the store confirms still reports it', () async {
    final cubit = DemoPaywallBuyCubit(
      PaywallProduct.hosted,
      stepTime: const Duration(milliseconds: 20),
    )..reporter = reporter(PaywallProduct.hosted, 'direct');
    await cubit.load();
    final buying = cubit.buy();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(cubit.state.status, PaywallBuyStatus.checking);
    await cubit.close();
    await buying;

    expect(
      [for (final event in gate.events) event.first],
      [
        'paywall_purchase_started',
        'paywall_purchase_completed',
        'paywall_closed',
      ],
    );
  });

  test('a cubit with no reporter behaves as before', () async {
    final cubit = DemoPaywallBuyCubit(
      PaywallProduct.pro,
      stepTime: Duration.zero,
    );
    await cubit.load();
    await cubit.buy();
    expect(cubit.state.status, PaywallBuyStatus.done);
    await cubit.close();
    expect(gate.events, isEmpty);
  });
}
