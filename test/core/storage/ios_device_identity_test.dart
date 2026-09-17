import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/push/push_token_provider.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_device_keychain.dart';

class _Tokens implements PushTokenProvider {
  @override
  PushTokenKind get kind => PushTokenKind.apns;
  @override
  Future<String> getToken() async => 'apns_token';
  @override
  Stream<String> get tokenRefreshes => const Stream.empty();
}

/// A relay that records what each registration presented and what it asked to
/// have released.
class _Relay extends MockApiClient {
  final List<(DeviceRegistration, String?)> registrations = [];
  final List<(DeviceRegistration, String)> refreshes = [];
  final List<(String, String)> releases = [];

  /// The account each join token attaches a device to, the way the relay
  /// resolves an `aj_`.
  final Map<String, String> joinable = {};

  /// Thrown by a registration that presents a join token.
  ApiException? joinError;

  /// Makes the release of the old shared row fail the way a flaky network
  /// does.
  bool failRelease = false;

  int _minted = 0;

  @override
  Future<DeviceRegistrationResponse> registerDevice(
    DeviceRegistration registration, {
    Uri? relayUri,
    String? accountJoinToken,
  }) async {
    registrations.add((registration, accountJoinToken));
    final refusal = joinError;
    if (accountJoinToken != null && refusal != null) throw refusal;
    _minted++;
    return DeviceRegistrationResponse(
      accountId: accountJoinToken == null
          ? 'acc_$_minted'
          : joinable[accountJoinToken] ?? 'acc_joined',
      deviceToken: 'dv_$_minted',
      // api.md §4.2: only the call that created the account gets one.
      accountJoinToken: accountJoinToken == null ? 'aj_$_minted' : null,
      caps: const AccountCaps(),
    );
  }

  @override
  Future<DeviceRegistrationResponse> refreshDevice(
    DeviceRegistration registration,
    String deviceToken, {
    Uri? relayUri,
  }) async {
    refreshes.add((registration, deviceToken));
    return const DeviceRegistrationResponse(
      accountId: 'acc_kept',
      caps: AccountCaps(),
    );
  }

  @override
  Future<void> deleteDevice({
    required String deviceId,
    required String deviceToken,
    Uri? relayUri,
  }) async {
    if (failRelease) {
      throw const ApiException(statusCode: 503, message: 'unavailable');
    }
    releases.add((deviceId, deviceToken));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeDeviceKeychain keychain;
  late _Relay relay;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    keychain = FakeDeviceKeychain()..install();
    relay = _Relay();
  });
  tearDown(() => keychain.remove());

  Future<KeychainDeviceIdentityStore> newStore() async =>
      KeychainDeviceIdentityStore(await SharedPreferences.getInstance());

  Future<void> register(KeychainDeviceIdentityStore store) =>
      RegisterDeviceUsecase(
        relay,
        store,
        _Tokens(),
        platform: () => 'ios',
      )(appVersion: '1.0.0', pushToken: 'apns_token');

  test('a first install writes both items and creates one account', () async {
    await register(await newStore());

    expect(relay.registrations.single.$2, isNull, reason: 'no bearer');
    expect(keychain.account, {
      'account_id': 'acc_1',
      'account_join_token': 'aj_1',
    });
    expect(keychain.device!['device_id'], startsWith('dev_'));
    expect(keychain.device!['device_token'], 'dv_1');
    // The join token belongs on the synced item only. On the device item it
    // would ride iCloud straight back to where it started.
    expect(keychain.device!.containsKey('account_join_token'), isFalse);

    expect(
      keychain.writes
          .map((call) => (call.service, call.synchronizable))
          .toList(),
      [
        (FakeDeviceKeychain.accountService, true),
        (FakeDeviceKeychain.deviceService, false),
      ],
    );
  });

  test('a second device joins and leaves the synced item alone', () async {
    keychain
      ..seedAccount(accountId: 'acc_1', joinToken: 'aj_1')
      ..calls.clear();
    relay.joinable['aj_1'] = 'acc_1';

    final store = await newStore();
    await register(store);

    final sent = relay.registrations.single;
    expect(sent.$2, 'aj_1', reason: 'the join is authorised by the aj_');
    expect(sent.$1.deviceId, startsWith('dev_'));
    expect(keychain.device!['device_id'], sent.$1.deviceId);
    expect(keychain.device!['device_token'], 'dv_1');
    expect(keychain.device!['account_id'], 'acc_1');
    // The account already existed, so nothing rewrites the synced item.
    expect(
      keychain.writes.map((call) => call.service),
      [FakeDeviceKeychain.deviceService],
    );
    expect(keychain.account, {
      'account_id': 'acc_1',
      'account_join_token': 'aj_1',
    });
    expect(keychain.deletes, isEmpty);
  });

  test('a reinstall keeps its device id and refreshes instead', () async {
    keychain
      ..seedAccount(accountId: 'acc_1', joinToken: 'aj_1')
      ..seedDevice(
        deviceId: 'dev_same',
        deviceToken: 'dv_same',
        accountId: 'acc_1',
        tier: 'relay',
      )
      ..calls.clear();

    await register(await newStore());

    expect(relay.registrations, isEmpty);
    expect(relay.refreshes.single.$1.deviceId, 'dev_same');
    expect(relay.refreshes.single.$2, 'dv_same');
    expect(keychain.device!['device_id'], 'dev_same');
    expect(keychain.device!['device_token'], 'dv_same');
    expect(keychain.deletes, isEmpty);
  });

  test('the old single item splits and the shared row is released', () async {
    keychain.seedCombined(
      deviceId: 'dev_shared',
      deviceToken: 'dv_shared',
      accountId: 'acc_1',
      tier: 'relay',
      accountJoinToken: 'aj_1',
    );
    relay.joinable['aj_1'] = 'acc_1';

    await register(await newStore());

    // The read that makes the split possible at all.
    final anyReads = keychain.calls.where(
      (call) =>
          call.method == 'read' &&
          call.synchronizable == KeychainDeviceIdentityStore.anySync,
    );
    expect(anyReads.single.service, FakeDeviceKeychain.deviceService);

    expect(relay.registrations.single.$2, 'aj_1');
    expect(relay.registrations.single.$1.deviceId, isNot('dev_shared'));
    expect(keychain.account, {
      'account_id': 'acc_1',
      'account_join_token': 'aj_1',
    });
    expect(keychain.device!['device_id'], isNot('dev_shared'));
    expect(keychain.device!['device_token'], 'dv_1');

    // The shared row goes, and it goes with the credential that owned it.
    expect(relay.releases.single, ('dev_shared', 'dv_shared'));
    expect(keychain.item(FakeDeviceKeychain.deviceService, true), isNull);

    // Written first, deleted last: the old copy only goes once this handset's
    // own item is on disk.
    final wroteDevice = keychain.calls.indexWhere(
      (call) =>
          call.method == 'write' &&
          call.service == FakeDeviceKeychain.deviceService,
    );
    final deletedOld = keychain.calls.indexWhere(
      (call) =>
          call.method == 'delete' &&
          call.service == FakeDeviceKeychain.deviceService,
    );
    expect(wroteDevice, lessThan(deletedOld));
  });

  test('the old single item with no join token keeps the row it has', () async {
    keychain.seedCombined(
      deviceId: 'dev_shared',
      deviceToken: 'dv_shared',
      accountId: 'acc_1',
      tier: 'relay',
    );

    await register(await newStore());

    // api.md §4.2 has no route that hands an aj_ to a device holding only a
    // dv_, so there is nothing to join with and nothing to release.
    expect(relay.registrations, isEmpty);
    expect(relay.refreshes.single.$1.deviceId, 'dev_shared');
    expect(relay.releases, isEmpty);
    expect(keychain.account, {
      'account_id': 'acc_1',
      'account_join_token': null,
    });
    expect(keychain.device!['device_id'], 'dev_shared');
    expect(keychain.device!['device_token'], 'dv_shared');
    expect(keychain.item(FakeDeviceKeychain.deviceService, true), isNull);
  });

  test('a failed release leaves a working install and is retried', () async {
    keychain.seedCombined(
      deviceId: 'dev_shared',
      deviceToken: 'dv_shared',
      accountId: 'acc_1',
      accountJoinToken: 'aj_1',
    );
    relay
      ..joinable['aj_1'] = 'acc_1'
      ..failRelease = true;

    await register(await newStore());

    expect(relay.releases, isEmpty);
    expect(keychain.account!['account_join_token'], 'aj_1');
    expect(keychain.device!['device_token'], 'dv_1');
    // The pair stays on disk, which is what the next launch retries with.
    expect(keychain.device!['retired_device_id'], 'dev_shared');
    expect(keychain.device!['retired_device_token'], 'dv_shared');

    relay.failRelease = false;
    await register(await newStore());

    expect(relay.releases.single, ('dev_shared', 'dv_shared'));
    expect(keychain.device!.containsKey('retired_device_id'), isFalse);
  });

  test('a join the server does not know ends up on a fresh account', () async {
    keychain.seedAccount(accountId: 'acc_gone', joinToken: 'aj_gone');
    relay.joinError = const ApiException(
      statusCode: 401,
      message: 'unauthorized',
    );

    await register(await newStore());

    expect(relay.registrations.map((sent) => sent.$2), ['aj_gone', null]);
    // The stale synced item is overwritten by the account this handset made.
    expect(keychain.account, {
      'account_id': 'acc_1',
      'account_join_token': 'aj_1',
    });
    expect(keychain.device!['device_token'], 'dv_1');
  });

  test('a join refused on the device cap writes nothing', () async {
    keychain.seedAccount(accountId: 'acc_1', joinToken: 'aj_1');
    keychain.calls.clear();
    relay.joinError = const ApiException(
      statusCode: 429,
      message: 'cap',
      cap: 'devices',
    );

    await expectLater(
      register(await newStore()),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 429)
            .having((error) => error.cap, 'cap', 'devices'),
      ),
    );

    expect(keychain.writes, isEmpty);
    expect(keychain.deletes, isEmpty);
    expect(keychain.account, {
      'account_id': 'acc_1',
      'account_join_token': 'aj_1',
    });
    expect(keychain.device, isNull);
  });

  test('no synced item means this handset starts its own account', () async {
    // What iCloud Keychain turned off looks like: the account item never
    // arrives, so there is nothing to join.
    await register(await newStore());

    expect(relay.registrations.single.$2, isNull);
    expect(keychain.deletes, isEmpty);
    expect(keychain.account!['account_id'], 'acc_1');
    expect(keychain.device!['device_token'], 'dv_1');
  });

  test('signing out drops the synced item as well as the local one', () async {
    keychain
      ..seedAccount(accountId: 'acc_1', joinToken: 'aj_1')
      ..seedDevice(
        deviceId: 'dev_old',
        deviceToken: 'dv_old',
        accountId: 'acc_1',
      )
      ..calls.clear();

    final store = await newStore();
    final reset = await store.resetIdentity();

    expect(reset.deviceId, isNot('dev_old'));
    expect(reset.deviceToken, isNull);
    // Left behind, the join token would put this handset straight back on the
    // account it just left.
    expect(keychain.account, isNull);
    expect(keychain.device!['device_id'], reset.deviceId);
  });
}
