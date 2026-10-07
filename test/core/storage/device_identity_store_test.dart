import 'package:critalarm/core/push/relay_confirmation_store.dart';
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

  group('the relay confirmation belongs to the identity', () {
    const scope = RelayConfirmationScope(
      deviceId: 'dev_old',
      relay: 'https://relay.example',
      tokenHash: 'abc',
    );

    Future<(DeviceIdentityStore, RelayConfirmationStore)> build() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final confirmations = RelayConfirmationStore(prefs);
      await confirmations.record(
        DateTime.utc(2026, 10, 7),
        RelayAttemptOutcome.accepted,
        scope,
      );
      return (DeviceIdentityStore(prefs), confirmations);
    }

    test('signing out forgets it', () async {
      final (identity, confirmations) = await build();
      expect(confirmations.confirmedAtFor(scope), isNotNull);

      await identity.resetIdentity();

      expect(confirmations.confirmedAtFor(scope), isNull);
      expect(confirmations.lastOutcomeFor(scope), isNull);
      expect(confirmations.lastAttemptAt, isNull);
    });

    test('disconnecting from a server forgets it', () async {
      final (identity, confirmations) = await build();
      await identity.clear();
      expect(confirmations.confirmedAtFor(scope), isNull);
    });
  });
}
