import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/paywall/pro_override.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<DeviceIdentityStore> freeAccount() async {
    SharedPreferences.setMockInitialValues({'device_id': 'dev_1'});
    final identity = DeviceIdentityStore(await SharedPreferences.getInstance());
    await identity.saveRegistration(
      deviceToken: 'dv_1',
      accountId: 'acc_1',
      tier: 'free',
      caps: AccountCaps.free,
    );
    return identity;
  }

  test('the store saying Pro flips the plan row without a reload', () async {
    final plan = PlanChanges();
    final cubit = SettingsCubit(
      identityStore: await freeAccount(),
      proOverride: const NoProOverride(),
      planChanges: plan,
    );
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state.access.isPaid, isFalse);
    expect(cubit.state.hasStorageSection, isFalse);

    plan.setStoreSaysPro(value: true);
    await pumpEventQueue();

    expect(cubit.state.access.isPaid, isTrue);
    expect(cubit.state.hasStorageSection, isTrue);
  });

  test('a bump reads the new tier and caps from the store', () async {
    final plan = PlanChanges();
    final identity = await freeAccount();
    final cubit = SettingsCubit(
      identityStore: identity,
      proOverride: const NoProOverride(),
      planChanges: plan,
    );
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state.access.caps?.criticalTopics, 2);

    await identity.saveRegistration(
      deviceToken: 'dv_1',
      accountId: 'acc_1',
      tier: 'relay',
      caps: const AccountCaps(historyDays: 90),
    );
    plan.bump();
    await pumpEventQueue();

    expect(cubit.state.access.isRegisteredPaid, isTrue);
    expect(cubit.state.access.caps?.criticalTopics, isNull);
  });
}
