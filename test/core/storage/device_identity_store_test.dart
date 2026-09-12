import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'generates one dev id and reuses it with registration metadata',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = DeviceIdentityStore(prefs);
      final first = await store.readOrCreate();
      await store.saveRegistration(
        deviceToken: 'dv_1',
        accountId: 'acc_1',
        tier: 'relay',
      );
      final second = await store.readOrCreate();
      expect(first.deviceId, startsWith('dev_'));
      expect(second.deviceId, first.deviceId);
      expect(second.deviceToken, 'dv_1');
      expect(second.accountId, 'acc_1');
      expect(second.tier, 'relay');
    },
  );
}
