import 'package:critalarm/core/models/account_access.dart';
import 'package:critalarm/core/models/device_identity.dart';
import 'package:critalarm/core/paywall/dev_pro_switch.dart';
import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:critalarm/core/paywall/pro_override.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/features/paywall/presentation/cubits/paywall_cubit.dart';
import 'package:critalarm/features/paywall/presentation/cubits/paywall_state.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<DevProSwitch> makeSwitch([Map<String, Object> seed = const {}]) async {
    SharedPreferences.setMockInitialValues(seed);
    return DevProSwitch(await SharedPreferences.getInstance());
  }

  const freeIdentity = DeviceIdentity(
    deviceId: 'dev_test',
    accountId: 'acc_test',
  );
  const hostedIdentity = DeviceIdentity(
    deviceId: 'dev_test',
    accountId: 'acc_test',
    tier: 'hosted',
  );

  group('a build that skips the paywall', () {
    test('reads as paid while the switch is on', () async {
      final proSwitch = await makeSwitch();
      final override = DevProOverride()..watch(proSwitch);

      await proSwitch.setPro(isPro: true);

      const access = AccountAccess(freeIdentity);
      expect(
        AccountAccess(freeIdentity, proOverride: override).isPaid,
        isTrue,
        reason: 'the switch is on, so the app should look paid',
      );
      expect(access.isRegisteredPaid, isFalse);
    });

    test('falls back to the registered tier while the switch is off', () async {
      final proSwitch = await makeSwitch();
      final override = DevProOverride()..watch(proSwitch);

      expect(
        AccountAccess(freeIdentity, proOverride: override).isPaid,
        isFalse,
      );
      expect(
        AccountAccess(hostedIdentity, proOverride: override).isPaid,
        isTrue,
      );
    });

    test('an unregistered device still has no plan limits', () async {
      final proSwitch = await makeSwitch();
      final override = DevProOverride()..watch(proSwitch);
      await proSwitch.setPro(isPro: true);

      const nobody = AccountAccess(null);
      expect(AccountAccess(null, proOverride: override).isPaid, isTrue);
      expect(AccountAccess(null, proOverride: override).caps, isNull);
      expect(nobody.isKnown, isFalse);
    });
  });

  group('a build that does not skip the paywall', () {
    test('ignores the switch even when the saved choice says Pro', () async {
      final proSwitch = await makeSwitch({'dev.pro_mode': true});
      expect(proSwitch.value, isTrue);

      final override = const NoProOverride()..watch(proSwitch);

      expect(override.listenable, isNull);
      expect(override.isForcingPro, isFalse);
      expect(
        AccountAccess(freeIdentity, proOverride: override).isPaid,
        isFalse,
      );
      expect(
        AccountAccess(hostedIdentity, proOverride: override).isPaid,
        isTrue,
        reason: 'registration is still the only thing that grants access',
      );
    });

    test('is what this test run was compiled with', () async {
      expect(
        buildSkipsPaywall,
        isFalse,
        reason: 'flutter test passes no SKIP_PAYWALL dart-define',
      );

      final proSwitch = await makeSwitch({'dev.pro_mode': true});
      appProOverride.watch(proSwitch);

      expect(appProOverride, isA<NoProOverride>());
      expect(appProOverride.listenable, isNull);
      expect(appProOverride.isForcingPro, isFalse);
      expect(const AccountAccess(freeIdentity).isPaid, isFalse);
    });
  });

  group('consumers follow the switch without being rebuilt', () {
    test('SettingsCubit re-emits access on the same instance', () async {
      final proSwitch = await makeSwitch();
      final override = DevProOverride()..watch(proSwitch);
      final identityStore = DeviceIdentityStore(
        await SharedPreferences.getInstance(),
      );
      await identityStore.readOrCreate();
      await identityStore.saveRegistration(
        deviceToken: 'dv_test',
        accountId: 'acc_test',
        tier: 'free',
      );

      final cubit = SettingsCubit(
        identityStore: identityStore,
        proOverride: override,
      );
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.access.isPaid, isFalse);

      await proSwitch.setPro(isPro: true);

      expect(cubit.state.access.isPaid, isTrue);
      expect(cubit.state.access.isRegisteredPaid, isFalse);
      expect(cubit.state.access.identity?.accountId, equals('acc_test'));

      await proSwitch.setPro(isPro: false);
      expect(cubit.state.access.isPaid, isFalse);
    });

    test('PaywallCubit re-emits isPro on the same instance', () async {
      final proSwitch = await makeSwitch();
      final override = DevProOverride()..watch(proSwitch);
      final identityStore = DeviceIdentityStore(
        await SharedPreferences.getInstance(),
      );
      await identityStore.readOrCreate();
      await identityStore.saveRegistration(
        deviceToken: 'dv_test',
        accountId: 'acc_test',
        tier: 'free',
      );

      final cubit = PaywallCubit(
        identityStore: identityStore,
        proOverride: override,
      );
      addTearDown(cubit.close);

      expect(cubit.state.isPro, isFalse);

      final becamePro = expectLater(
        cubit.stream,
        emitsThrough(predicate<PaywallState>((s) => s.isPro)),
      );
      await proSwitch.setPro(isPro: true);
      await becamePro;
    });
  });
}
