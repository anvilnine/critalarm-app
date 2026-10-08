import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/offer/onboarding_offer_config.dart';
import 'package:critalarm/features/onboarding/domain/offer/onboarding_offer_rule.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/onboarding_flow_fakes.dart';

const _on = OnboardingOfferConfig(
  enabled: true,
  cloudProduct: PaywallProduct.pro,
  selfHostedProduct: PaywallProduct.pro,
  layoutKey: 'plain',
);

const _onJson = '{"enabled": true}';

void main() {
  group('the bundled switches', () {
    test('are off, Pro on both kinds of server, the plain layout', () {
      const bundled = OnboardingOfferConfig.bundled;
      expect(bundled.enabled, isFalse);
      expect(bundled.cloudProduct, PaywallProduct.pro);
      expect(bundled.selfHostedProduct, PaywallProduct.pro);
      expect(bundled.layoutKey, 'plain');
    });

    test('the default flow lists the step between real ring and hook up', () {
      final steps = BundledOnboardingFlows.defaultFlow.steps;
      final at = steps.indexOf(OnboardingStepId.offer);
      expect(steps[at - 1], OnboardingStepId.realRing);
      expect(steps[at + 1], OnboardingStepId.hookUp);
    });
  });

  group('reading a value', () {
    test('every field as written', () {
      expect(
        OnboardingOfferConfig.tryParse(
          '{"enabled": true, "cloud_product": "hosted", '
          '"self_hosted_product": "none", "layout": "sheet"}',
        ),
        const OnboardingOfferConfig(
          enabled: true,
          cloudProduct: PaywallProduct.hosted,
          selfHostedProduct: null,
          layoutKey: 'sheet',
        ),
      );
    });

    test('a field left out takes its bundled default', () {
      expect(OnboardingOfferConfig.tryParse(_onJson), _on);
      expect(
        OnboardingOfferConfig.tryParse('{}'),
        OnboardingOfferConfig.bundled,
      );
      expect(
        OnboardingOfferConfig.tryParse('{"cloud_product": "none"}'),
        const OnboardingOfferConfig(
          enabled: false,
          cloudProduct: null,
          selfHostedProduct: PaywallProduct.pro,
          layoutKey: 'plain',
        ),
      );
    });

    test('fields it does not know are ignored', () {
      expect(
        OnboardingOfferConfig.tryParse('{"enabled": true, "price": 3}'),
        _on,
      );
    });

    test('what it writes reads back the same', () {
      for (final config in [
        OnboardingOfferConfig.bundled,
        _on,
        const OnboardingOfferConfig(
          enabled: true,
          cloudProduct: null,
          selfHostedProduct: null,
          layoutKey: 'false_alarm',
        ),
      ]) {
        expect(OnboardingOfferConfig.tryParse(config.encode()), config);
      }
    });

    test('a missing, empty or broken value reads as nothing', () {
      for (final raw in [
        null,
        '',
        '   ',
        'true',
        '[]',
        '"on"',
        '{"enabled":',
      ]) {
        expect(OnboardingOfferConfig.tryParse(raw), isNull, reason: '$raw');
      }
    });

    test('one bad field sets the whole value aside', () {
      for (final raw in [
        '{"enabled": "true"}',
        '{"enabled": 1}',
        '{"enabled": true, "cloud_product": "gold"}',
        '{"enabled": true, "cloud_product": 3}',
        // Hosted is the cloud plan. A self-hosted server is never sold it.
        '{"enabled": true, "self_hosted_product": "hosted"}',
        '{"enabled": true, "layout": 7}',
        '{"enabled": true, "layout": ""}',
        '{"enabled": true, "layout": "Not A Key"}',
      ]) {
        expect(OnboardingOfferConfig.tryParse(raw), isNull, reason: raw);
      }
    });

    test('a layout key no build has still reads, and is asked about later', () {
      expect(
        OnboardingOfferConfig.tryParse(
          '{"enabled": true, "layout": "next_year"}',
        )?.layoutKey,
        'next_year',
      );
    });
  });

  group('which source wins', () {
    test('the developer value, then the remote one, then the bundled', () {
      final both = chooseOnboardingOffer(
        developerJson: '{"enabled": true, "layout": "sheet"}',
        remoteJson: _onJson,
      );
      expect(both.origin, OnboardingOfferOrigin.developer);
      expect(both.config.layoutKey, 'sheet');

      final remote = chooseOnboardingOffer(
        developerJson: null,
        remoteJson: _onJson,
      );
      expect(remote.origin, OnboardingOfferOrigin.remote);
      expect(remote.config, _on);

      final none = chooseOnboardingOffer(developerJson: null, remoteJson: '');
      expect(none.origin, OnboardingOfferOrigin.bundled);
      expect(none.config, OnboardingOfferConfig.bundled);
    });

    test('a bad value is passed over for the next source', () {
      final chosen = chooseOnboardingOffer(
        developerJson: 'not json',
        remoteJson: '{"enabled": true, "cloud_product": "gold"}',
      );
      expect(chosen.origin, OnboardingOfferOrigin.bundled);
      expect(chosen.config.enabled, isFalse);
    });
  });

  group('the skip rule', () {
    OfferDecision decide({
      OnboardingOfferConfig config = _on,
      bool isSelfHosted = false,
      Set<String> builtLayoutKeys = const {'plain', 'sheet'},
      bool hasAccountId = true,
      bool holdsPro = false,
      bool holdsHosted = false,
      bool isReplay = false,
    }) => decideOnboardingOffer(
      config: config,
      isSelfHosted: isSelfHosted,
      builtLayoutKeys: builtLayoutKeys,
      hasAccountId: hasAccountId,
      holdsPro: holdsPro,
      holdsHosted: holdsHosted,
      isReplay: isReplay,
    );

    OnboardingOfferConfig config({
      bool enabled = true,
      PaywallProduct? cloud = PaywallProduct.pro,
      PaywallProduct? selfHosted = PaywallProduct.pro,
      String layout = 'plain',
    }) => OnboardingOfferConfig(
      enabled: enabled,
      cloudProduct: cloud,
      selfHostedProduct: selfHosted,
      layoutKey: layout,
    );

    test('shows the product for this kind of server in the layout named', () {
      expect(
        decide(
          config: config(cloud: PaywallProduct.hosted, layout: 'sheet'),
        ),
        const OfferDecision.show(
          product: PaywallProduct.hosted,
          layoutKey: 'sheet',
        ),
      );
      expect(
        decide(
          config: config(cloud: PaywallProduct.hosted),
          isSelfHosted: true,
        ),
        const OfferDecision.show(
          product: PaywallProduct.pro,
          layoutKey: 'plain',
        ),
      );
    });

    test('skips when not enabled', () {
      expect(
        decide(config: config(enabled: false)).skipReason,
        OfferSkipReason.notEnabled,
      );
      expect(
        decide(config: OnboardingOfferConfig.bundled).skipReason,
        OfferSkipReason.notEnabled,
      );
    });

    test('skips when the product is none for this kind of server', () {
      expect(
        decide(config: config(cloud: null)).skipReason,
        OfferSkipReason.noProduct,
      );
      expect(
        decide(config: config(selfHosted: null), isSelfHosted: true).skipReason,
        OfferSkipReason.noProduct,
      );
      // None on the other kind of server changes nothing here.
      expect(decide(config: config(selfHosted: null)).isShown, isTrue);
      expect(
        decide(config: config(cloud: null), isSelfHosted: true).isShown,
        isTrue,
      );
    });

    test('skips when the layout is not built in this version', () {
      expect(
        decide(config: config(layout: 'next_year')).skipReason,
        OfferSkipReason.unknownLayout,
      );
      expect(
        decide(builtLayoutKeys: const {}).skipReason,
        OfferSkipReason.unknownLayout,
      );
    });

    test('skips when the user already holds the product', () {
      expect(decide(holdsPro: true).skipReason, OfferSkipReason.alreadyHeld);
      expect(
        decide(
          config: config(cloud: PaywallProduct.hosted),
          holdsHosted: true,
        ).skipReason,
        OfferSkipReason.alreadyHeld,
      );
      // Holding the other product is no reason to skip.
      expect(decide(holdsHosted: true).isShown, isTrue);
      expect(
        decide(
          config: config(cloud: PaywallProduct.hosted),
          holdsPro: true,
        ).isShown,
        isTrue,
      );
    });

    test('skips when no account id is known', () {
      expect(decide(hasAccountId: false).skipReason, OfferSkipReason.noAccount);
    });

    test('skips on a replay, whatever else is true', () {
      expect(decide(isReplay: true).skipReason, OfferSkipReason.replay);
    });

    test('only a developer value lets a replay show the step', () {
      for (final origin in OnboardingOfferOrigin.values) {
        expect(
          offerCountsAsReplay(isReplay: true, origin: origin),
          origin != OnboardingOfferOrigin.developer,
        );
        expect(offerCountsAsReplay(isReplay: false, origin: origin), isFalse);
      }
    });
  });

  group('the gate', () {
    test('with no value anywhere the step is off', () async {
      final decision = await offerGateFor().decide(isReplay: false);
      expect(decision.skipReason, OfferSkipReason.notEnabled);
    });

    test('a remote value turns it on', () async {
      final decision = await offerGateFor(
        remoteJson: _onJson,
      ).decide(isReplay: false);
      expect(
        decision,
        const OfferDecision.show(
          product: PaywallProduct.pro,
          layoutKey: 'plain',
        ),
      );
    });

    test('a bad remote value leaves the step off', () async {
      for (final raw in ['{', '{"enabled": "yes"}', '{"layout": 4}']) {
        final decision = await offerGateFor(
          remoteJson: raw,
        ).decide(isReplay: false);
        expect(decision.skipReason, OfferSkipReason.notEnabled, reason: raw);
      }
    });

    test('a remote layout this build does not have skips the step', () async {
      final decision = await offerGateFor(
        remoteJson: '{"enabled": true, "layout": "sheet"}',
      ).decide(isReplay: false);
      expect(decision.skipReason, OfferSkipReason.unknownLayout);
    });

    test('reads the kind of server, the account and what is held', () async {
      Future<OfferSkipReason?> reason(OnboardingOfferGate gate) async =>
          (await gate.decide(isReplay: false)).skipReason;

      expect(
        await reason(
          offerGateFor(
            remoteJson: '{"enabled": true, "self_hosted_product": "none"}',
            serverMode: ServerMode.selfhosted,
          ),
        ),
        OfferSkipReason.noProduct,
      );
      expect(
        await reason(offerGateFor(remoteJson: _onJson, accountId: null)),
        OfferSkipReason.noAccount,
      );
      expect(
        await reason(offerGateFor(remoteJson: _onJson, accountId: '')),
        OfferSkipReason.noAccount,
      );
      expect(
        await reason(offerGateFor(remoteJson: _onJson, holdsPro: true)),
        OfferSkipReason.alreadyHeld,
      );
    });

    test('a replay skips a remote value and shows a developer one', () async {
      final remote = await offerGateFor(
        remoteJson: _onJson,
      ).decide(isReplay: true);
      expect(remote.skipReason, OfferSkipReason.replay);

      final developer = await offerGateFor(
        developerJson: _onJson,
      ).decide(isReplay: true);
      expect(developer.isShown, isTrue);
    });

    test('a read that throws ends in a skip, never in an error', () async {
      Never fail() => throw StateError('no');
      final sources = OnboardingOfferGate(
        readDeveloperJson: fail,
        readRemoteJson: fail,
        readServerMode: () async => ServerMode.hosted,
        builtLayoutKeys: () => const {'plain'},
        readAccountId: () async => 'acct_1',
        holdsPro: () => false,
        readHoldsHosted: () async => false,
        isSetupComplete: () async => false,
        readFlowSteps: () => const [],
        readCompletedSteps: () => const {},
      );
      expect(
        (await sources.decide(isReplay: false)).skipReason,
        OfferSkipReason.notEnabled,
      );

      final account = OnboardingOfferGate(
        readDeveloperJson: () => null,
        readRemoteJson: () => _onJson,
        readServerMode: () async => fail(),
        builtLayoutKeys: () => const {'plain'},
        readAccountId: () async => fail(),
        holdsPro: () => false,
        readHoldsHosted: () async => false,
        isSetupComplete: () async => fail(),
        readFlowSteps: () => const [],
        readCompletedSteps: () => const {},
      );
      expect(
        (await account.decide(isReplay: false)).skipReason,
        OfferSkipReason.noAccount,
      );
      expect(await account.isAhead(), isFalse);
    });
  });

  group('the offer step is still ahead', () {
    const show = OfferDecision.show(
      product: PaywallProduct.pro,
      layoutKey: 'plain',
    );
    final steps = BundledOnboardingFlows.defaultFlow.steps;

    bool ahead({
      bool isSetupComplete = false,
      List<String>? flowSteps,
      Set<String> completedSteps = const {},
      OfferDecision decision = show,
    }) => offerStepIsAhead(
      isSetupComplete: isSetupComplete,
      flowSteps: flowSteps ?? steps,
      completedSteps: completedSteps,
      decision: decision,
    );

    test('while setup runs, the flow lists it and it would show', () {
      expect(ahead(), isTrue);
    });

    test('not once setup is complete', () {
      expect(ahead(isSetupComplete: true), isFalse);
    });

    test('not in a flow that leaves it out', () {
      expect(ahead(flowSteps: BundledOnboardingFlows.legacy.steps), isFalse);
    });

    test('not once the step is finished', () {
      expect(ahead(completedSteps: {OnboardingStepId.offer}), isFalse);
    });

    test('not when the step would skip itself', () {
      expect(
        ahead(decision: const OfferDecision.skip(OfferSkipReason.notEnabled)),
        isFalse,
      );
    });

    test('the gate puts the four together', () async {
      expect(
        await offerGateFor(remoteJson: _onJson, flowSteps: steps).isAhead(),
        isTrue,
      );
      expect(await offerGateFor(flowSteps: steps).isAhead(), isFalse);
      expect(
        await offerGateFor(
          remoteJson: _onJson,
          flowSteps: steps,
          isSetupComplete: true,
        ).isAhead(),
        isFalse,
      );
    });
  });
}
