import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/offer/onboarding_offer_config.dart';
import 'package:critalarm/features/onboarding/domain/offer/onboarding_offer_rule.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/onboarding_flow_fakes.dart';

const _on = OnboardingOfferConfig(
  enabled: true,
  cloudProduct: OfferCloudChoice.auto,
  selfHostedProduct: PaywallProduct.pro,
  layoutKey: 'reel',
);

const _onJson = '{"enabled": true}';

void main() {
  group('the bundled switches', () {
    test('are off, by the answer on Cloud, Pro on a server, the reel', () {
      const bundled = OnboardingOfferConfig.bundled;
      expect(bundled.enabled, isFalse);
      expect(bundled.cloudProduct, OfferCloudChoice.auto);
      expect(bundled.selfHostedProduct, PaywallProduct.pro);
      expect(bundled.layoutKey, 'reel');
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
          cloudProduct: OfferCloudChoice.hosted,
          selfHostedProduct: null,
          layoutKey: 'sheet',
        ),
      );
    });

    test('every value of cloud_product, old and new', () {
      for (final choice in OfferCloudChoice.values) {
        expect(
          OnboardingOfferConfig.tryParse(
            '{"cloud_product": "${choice.key}"}',
          )?.cloudProduct,
          choice,
        );
      }
      // The three values stored before `auto` existed read as they did.
      expect(
        OnboardingOfferConfig.tryParse(
          '{"cloud_product": "pro"}',
        )?.cloudProduct,
        OfferCloudChoice.pro,
      );
      expect(
        OnboardingOfferConfig.tryParse(
          '{"cloud_product": "hosted"}',
        )?.cloudProduct,
        OfferCloudChoice.hosted,
      );
      expect(
        OnboardingOfferConfig.tryParse(
          '{"cloud_product": "none"}',
        )?.cloudProduct,
        OfferCloudChoice.none,
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
          cloudProduct: OfferCloudChoice.none,
          selfHostedProduct: PaywallProduct.pro,
          layoutKey: 'reel',
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
          cloudProduct: OfferCloudChoice.none,
          selfHostedProduct: null,
          layoutKey: 'false_alarm',
        ),
        for (final choice in OfferCloudChoice.values)
          OnboardingOfferConfig(
            enabled: true,
            cloudProduct: choice,
            selfHostedProduct: PaywallProduct.pro,
            layoutKey: 'reel',
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
        '{"enabled": true, "cloud_product": "Auto"}',
        '{"enabled": true, "cloud_product": ""}',
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
      Set<String> builtLayoutKeys = const {'hero', 'reel', 'sheet'},
      bool hasAccountId = true,
      bool holdsPro = false,
      bool holdsHosted = false,
      bool isReplay = false,
      SetupUse? use,
    }) => decideOnboardingOffer(
      config: config,
      isSelfHosted: isSelfHosted,
      builtLayoutKeys: builtLayoutKeys,
      hasAccountId: hasAccountId,
      holdsPro: holdsPro,
      holdsHosted: holdsHosted,
      isReplay: isReplay,
      use: use,
    );

    OnboardingOfferConfig config({
      bool enabled = true,
      OfferCloudChoice cloud = OfferCloudChoice.pro,
      PaywallProduct? selfHosted = PaywallProduct.pro,
      String layout = 'hero',
    }) => OnboardingOfferConfig(
      enabled: enabled,
      cloudProduct: cloud,
      selfHostedProduct: selfHosted,
      layoutKey: layout,
    );

    test('shows the product for this kind of server in the layout named', () {
      expect(
        decide(
          config: config(cloud: OfferCloudChoice.hosted, layout: 'sheet'),
        ),
        const OfferDecision.show(
          product: PaywallProduct.hosted,
          layoutKey: 'sheet',
        ),
      );
      final ownServer = decide(
        config: config(cloud: OfferCloudChoice.hosted),
        isSelfHosted: true,
      );
      expect(ownServer.product, PaywallProduct.pro);
      expect(ownServer.layoutKey, 'hero');
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
        decide(config: config(cloud: OfferCloudChoice.none)).skipReason,
        OfferSkipReason.noProduct,
      );
      expect(
        decide(config: config(selfHosted: null), isSelfHosted: true).skipReason,
        OfferSkipReason.noProduct,
      );
      // None on the other kind of server changes nothing here.
      expect(decide(config: config(selfHosted: null)).isShown, isTrue);
      expect(
        decide(
          config: config(cloud: OfferCloudChoice.none),
          isSelfHosted: true,
        ).isShown,
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
      expect(
        decide(config: config(), holdsPro: true).skipReason,
        OfferSkipReason.alreadyHeld,
      );
      expect(
        decide(
          config: config(cloud: OfferCloudChoice.hosted),
          holdsHosted: true,
        ).skipReason,
        OfferSkipReason.alreadyHeld,
      );
      // Holding the other product is no reason to skip.
      expect(decide(config: config(), holdsHosted: true).isShown, isTrue);
      expect(
        decide(
          config: config(cloud: OfferCloudChoice.hosted),
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

  group('the answer in the skip rule', () {
    OfferDecision decide(
      SetupUse? use, {
      bool isSelfHosted = false,
      bool holdsPro = false,
      bool holdsHosted = false,
      String? topicName,
    }) => decideOnboardingOffer(
      config: _on,
      isSelfHosted: isSelfHosted,
      builtLayoutKeys: const {'reel'},
      hasAccountId: true,
      holdsPro: holdsPro,
      holdsHosted: holdsHosted,
      isReplay: false,
      use: use,
      topicName: topicName,
    );

    test('auto picks Hosted for most answers and Pro for home', () {
      expect(decide(SetupUse.servers).product, PaywallProduct.hosted);
      expect(decide(SetupUse.homelab).product, PaywallProduct.hosted);
      expect(decide(SetupUse.jobs).product, PaywallProduct.hosted);
      expect(decide(SetupUse.other).product, PaywallProduct.hosted);
      expect(decide(null).product, PaywallProduct.hosted);
      expect(decide(SetupUse.home).product, PaywallProduct.pro);
    });

    test('the lead carries the benefit and the topic name', () {
      final servers = decide(SetupUse.servers, topicName: 'payments-db');
      expect(servers.lead?.benefit, PaywallBenefitId.topics);
      expect(servers.lead?.topicName, 'payments-db');
      expect(decide(SetupUse.servers).lead?.topicName, isNull);
      expect(decide(SetupUse.other).lead, isNull);
      expect(decide(null).lead, isNull);
    });

    test('holding the product the answer picks skips, the other does not', () {
      expect(
        decide(SetupUse.home, holdsPro: true).skipReason,
        OfferSkipReason.alreadyHeld,
      );
      expect(decide(SetupUse.home, holdsHosted: true).isShown, isTrue);
      expect(
        decide(SetupUse.servers, holdsHosted: true).skipReason,
        OfferSkipReason.alreadyHeld,
      );
      // Pro is held and the answer asks for Hosted: Hosted is still sold.
      expect(decide(SetupUse.servers, holdsPro: true).isShown, isTrue);
    });

    test('the reasons keep their order', () {
      OfferDecision all({
        bool enabled = true,
        String layout = 'reel',
        bool hasAccountId = true,
        bool holdsHosted = false,
        OfferCloudChoice cloud = OfferCloudChoice.auto,
      }) => decideOnboardingOffer(
        config: OnboardingOfferConfig(
          enabled: enabled,
          cloudProduct: cloud,
          selfHostedProduct: PaywallProduct.pro,
          layoutKey: layout,
        ),
        isSelfHosted: false,
        builtLayoutKeys: const {'reel'},
        hasAccountId: hasAccountId,
        holdsPro: false,
        holdsHosted: holdsHosted,
        isReplay: false,
        use: SetupUse.servers,
      );
      // No product beats an unknown layout, which beats no account, which
      // beats a held product.
      expect(
        all(
          cloud: OfferCloudChoice.none,
          layout: 'x',
          hasAccountId: false,
          holdsHosted: true,
        ).skipReason,
        OfferSkipReason.noProduct,
      );
      expect(
        all(layout: 'x', hasAccountId: false, holdsHosted: true).skipReason,
        OfferSkipReason.unknownLayout,
      );
      expect(
        all(hasAccountId: false, holdsHosted: true).skipReason,
        OfferSkipReason.noAccount,
      );
      expect(all(holdsHosted: true).skipReason, OfferSkipReason.alreadyHeld);
      expect(all(enabled: false).skipReason, OfferSkipReason.notEnabled);
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
          product: PaywallProduct.hosted,
          layoutKey: 'reel',
        ),
      );
    });

    test('reads the answer and the topic name for the lead', () async {
      final servers = await offerGateFor(
        remoteJson: _onJson,
        use: SetupUse.servers,
        topicName: ' payments-db ',
      ).decide(isReplay: false);
      expect(servers.product, PaywallProduct.hosted);
      expect(servers.lead?.benefit, PaywallBenefitId.topics);
      expect(servers.lead?.topicName, 'payments-db');

      final home = await offerGateFor(
        remoteJson: _onJson,
        use: SetupUse.home,
      ).decide(isReplay: false);
      expect(home.product, PaywallProduct.pro);

      // A name that is empty is no name.
      final blank = await offerGateFor(
        remoteJson: _onJson,
        use: SetupUse.servers,
        topicName: '  ',
      ).decide(isReplay: false);
      expect(blank.lead?.topicName, isNull);
    });

    test('a replay reads the replay answer', () async {
      final seen = <bool>[];
      final gate = OnboardingOfferGate(
        readDeveloperJson: () => _onJson,
        readRemoteJson: () => null,
        readServerMode: () async => ServerMode.hosted,
        builtLayoutKeys: () => const {'reel'},
        readAccountId: () async => 'acct_1',
        holdsPro: () => false,
        readHoldsHosted: () async => false,
        isSetupComplete: () async => false,
        readFlowSteps: () => const [],
        readCompletedSteps: () => const {},
        readUse: ({required isReplay}) {
          seen.add(isReplay);
          return isReplay ? SetupUse.home : SetupUse.servers;
        },
      );
      expect(
        (await gate.decide(isReplay: true)).product,
        PaywallProduct.pro,
      );
      expect(
        (await gate.decide(isReplay: false)).product,
        PaywallProduct.hosted,
      );
      expect(seen, [true, false]);
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
        await reason(offerGateFor(remoteJson: _onJson, holdsHosted: true)),
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
        builtLayoutKeys: () => const {'reel'},
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
        builtLayoutKeys: () => const {'reel'},
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
      product: PaywallProduct.hosted,
      layoutKey: 'reel',
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
