import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/features/settings/presentation/settings_hero_view.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SettingsHeroView view({
    ServerMode? mode = ServerMode.hosted,
    bool loaded = true,
    bool holdsHosted = false,
    bool planKnown = true,
    HoldingState? pro = HoldingState.notHeld,
    bool signedIn = false,
    bool canManage = true,
    bool onAccount = false,
  }) => SettingsHeroView.from(
    serverMode: mode,
    loaded: loaded,
    holdsHosted: holdsHosted,
    planKnown: planKnown,
    proState: pro,
    signedIn: signedIn,
    canManage: canManage,
    onAccount: onAccount,
  );

  group('SettingsHeroView', () {
    test('Free offers Cloud and Pro, and says nobody is signed in', () {
      final v = view();
      expect(v.planKey, LocaleKeys.settings_plan_free);
      expect(v.line, SettingsHeroLine.signedOut);
      expect(v.actions, [
        SettingsHeroAction.seeCloud,
        SettingsHeroAction.seePro,
      ]);
      expect(v.ownsPro, isFalse);
    });

    test('signed in reads as signed in', () {
      expect(view(signedIn: true).line, SettingsHeroLine.signedIn);
    });

    test('rule 3: a phone on an account it is not signed in to says which '
        'one, as a third line', () {
      expect(view(onAccount: true).line, SettingsHeroLine.onAccount);
      // Signed in wins, and a server of the person's own has no accounts.
      expect(
        view(onAccount: true, signedIn: true).line,
        SettingsHeroLine.signedIn,
      );
      expect(
        view(onAccount: true, mode: ServerMode.selfhosted).line,
        SettingsHeroLine.ownServer,
      );
      expect(view(onAccount: true, loaded: false).line, SettingsHeroLine.none);
    });

    test('Cloud held offers Manage, not Cloud', () {
      final v = view(holdsHosted: true);
      expect(v.planKey, LocaleKeys.settings_plan_pro);
      expect(v.actions, [
        SettingsHeroAction.manage,
        SettingsHeroAction.seePro,
      ]);
    });

    test('Cloud held without a customer centre offers no Manage', () {
      expect(view(holdsHosted: true, canManage: false).actions, [
        SettingsHeroAction.seePro,
      ]);
    });

    test('Cloud counts before the plan is read, as on the plan card', () {
      expect(
        view(holdsHosted: true, loaded: false).planKey,
        LocaleKeys.settings_plan_pro,
      );
    });

    test('an own server has no plan to buy and no account line', () {
      final v = view(mode: ServerMode.selfhosted, holdsHosted: true);
      expect(v.planKey, LocaleKeys.settings_server_self_hosted);
      expect(v.line, SettingsHeroLine.ownServer);
      expect(v.actions, [SettingsHeroAction.seePro]);
    });

    test('Pro owned shows the badge and drops See Pro', () {
      final v = view(pro: HoldingState.held);
      expect(v.ownsPro, isTrue);
      expect(v.actions, [SettingsHeroAction.seeCloud]);
    });

    test('Pro pending or not asked yet shows no Pro button', () {
      expect(
        view(pro: HoldingState.pending).actions,
        [SettingsHeroAction.seeCloud],
      );
      expect(view(pro: null).actions, [SettingsHeroAction.seeCloud]);
      expect(
        view(pro: HoldingState.unknown).actions,
        contains(
          SettingsHeroAction.seePro,
        ),
      );
    });

    test('the name stays blank until the plan is read', () {
      expect(view(loaded: false).planKey, isNull);
    });

    test('an unknown plan says so once read', () {
      expect(
        view(planKnown: false).planKey,
        LocaleKeys.account_plan_unavailable,
      );
    });

    test('no line until Settings are read, then a sign-in line', () {
      expect(view(loaded: false).line, SettingsHeroLine.none);
      // No server picked yet still says nobody is signed in.
      expect(view(mode: null).line, SettingsHeroLine.signedOut);
      // A relay has plans and accounts, as Cloud does.
      expect(view(mode: ServerMode.relay).line, SettingsHeroLine.signedOut);
    });
  });
}
