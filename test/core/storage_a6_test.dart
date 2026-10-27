import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/storage/shared_prefs_api_session_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_device_keychain.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeDeviceKeychain keychain;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    keychain = FakeDeviceKeychain()..install();
  });
  tearDown(() => keychain.remove());

  for (final mode in ServerMode.values) {
    test('ApiSession round-trips all four fields: ${mode.name}', () async {
      final store = SharedPrefsApiSessionStore(
        await SharedPreferences.getInstance(),
      );
      final session = ApiSession(
        baseUri: Uri.parse('https://canonical.example/base'),
        relayUri: Uri.parse('https://relay.example'),
        mode: mode,
        managementCredential: mode == ServerMode.selfhosted
            ? 'ad_secret'
            : 'dv_secret',
      );
      await store.write(session);
      final read = (await store.read())!;
      expect(read.baseUri, session.baseUri);
      expect(read.relayUri, session.relayUri);
      expect(read.mode, mode);
      expect(read.managementCredential, session.managementCredential);
    });
  }

  test('a session with the separator in a field is not saved, and the one '
      'saved before stays readable', () async {
    SharedPreferences.setMockInitialValues({
      'api_session':
          'https://canonical.example|https://relay.example|selfhosted|ad_old',
    });
    final prefs = await SharedPreferences.getInstance();
    final store = SharedPrefsApiSessionStore(prefs);

    await expectLater(
      store.write(
        ApiSession(
          baseUri: Uri.parse('https://canonical.example'),
          relayUri: Uri.parse('https://relay.example'),
          mode: ServerMode.selfhosted,
          managementCredential: 'ad_new|more',
        ),
      ),
      throwsArgumentError,
    );

    expect((await store.read())!.managementCredential, 'ad_old');
  });

  test('the relay that issued the device token is kept beside it, on '
      'Android and in the iOS Keychain', () async {
    final relay = Uri.parse('https://relay.example');
    final prefs = await SharedPreferences.getInstance();
    for (final store in [
      DeviceIdentityStore(prefs),
      KeychainDeviceIdentityStore(prefs),
    ]) {
      expect((await store.read())?.deviceToken, isNull);
      await store.readOrCreate();
      await store.saveRegistration(
        deviceToken: 'dv_1',
        accountId: 'acc_1',
        tier: 'free',
        relay: relay,
      );
      expect((await store.read())!.tokenRelay, '$relay');
      // A later save that names no relay keeps the issuer.
      await store.saveRegistration(
        deviceToken: 'dv_1',
        accountId: 'acc_1',
        tier: 'hosted',
      );
      expect((await store.readOrCreate()).tokenRelay, '$relay');
      await store.clear();
      expect((await store.read())?.tokenRelay, isNull);
    }
    // A new store over the same Keychain reads what the last one wrote.
    final first = KeychainDeviceIdentityStore(prefs);
    await first.readOrCreate();
    await first.saveRegistration(
      deviceToken: 'dv_2',
      accountId: 'acc_2',
      tier: 'free',
      relay: relay,
    );
    expect(keychain.device!['device_token_relay'], '$relay');
    expect(
      (await KeychainDeviceIdentityStore(prefs).readOrCreate()).tokenRelay,
      '$relay',
    );
  });

  test('the server a device token is the credential for is kept beside it, '
      'and a new token starts with none', () async {
    final server = Uri.parse('https://api.example');
    final prefs = await SharedPreferences.getInstance();
    for (final store in [
      DeviceIdentityStore(prefs),
      KeychainDeviceIdentityStore(prefs),
    ]) {
      // Nothing to write an origin for yet.
      await store.saveTokenOrigin(server: server);
      expect((await store.read())?.tokenServer, isNull);
      await store.readOrCreate();
      await store.saveRegistration(
        deviceToken: 'dv_1',
        accountId: 'acc_1',
        tier: 'free',
      );
      await store.saveTokenOrigin(server: server);
      expect((await store.readOrCreate()).tokenServer, '$server');
      expect((await store.readOrCreate()).tokenRelay, isNull);
      // The same token again keeps its server.
      await store.saveRegistration(
        deviceToken: 'dv_1',
        accountId: 'acc_1',
        tier: 'hosted',
      );
      expect((await store.readOrCreate()).tokenServer, '$server');
      await store.saveRegistration(
        deviceToken: 'dv_2',
        accountId: 'acc_1',
        tier: 'hosted',
      );
      expect((await store.readOrCreate()).tokenServer, isNull);
      await store.clear();
    }
  });

  test('an identity put back from a snapshot is the one that was there, '
      'on Android and in the iOS Keychain', () async {
    final prefs = await SharedPreferences.getInstance();

    // Android, from an identity.
    final android = DeviceIdentityStore(prefs);
    await android.readOrCreate();
    await android.saveRegistration(
      deviceToken: 'dv_old',
      accountId: 'acc_old',
      tier: 'free',
      relay: Uri.parse('https://relay.example'),
    );
    final held = {for (final key in prefs.getKeys()) key: prefs.get(key)};
    final snapshot = await android.snapshot();
    await android.saveRegistration(
      deviceToken: 'dv_new',
      accountId: 'acc_new',
      tier: 'hosted',
      accountJoinToken: 'aj_new',
      relay: Uri.parse('https://other.example'),
    );
    await android.restore(snapshot);
    expect({for (final key in prefs.getKeys()) key: prefs.get(key)}, held);

    // Android, from nothing.
    await android.clear();
    final empty = await android.snapshot();
    await android.readOrCreate();
    await android.saveRegistration(
      deviceToken: 'dv_new',
      accountId: 'acc_new',
      tier: 'free',
    );
    await android.restore(empty);
    expect(prefs.getKeys(), isEmpty);

    // iPhone, from nothing: the items a registration wrote are gone again.
    final iphone = KeychainDeviceIdentityStore(prefs);
    final nothing = await iphone.snapshot();
    await iphone.readOrCreate();
    await iphone.saveRegistration(
      deviceToken: 'dv_new',
      accountId: 'acc_new',
      tier: 'free',
      accountJoinToken: 'aj_new',
    );
    expect(keychain.device, isNotNull);
    expect(keychain.account, isNotNull);
    await iphone.restore(nothing);
    expect(keychain.items, isEmpty);
    expect((await iphone.read())?.deviceToken, isNull);

    // iPhone, from an identity.
    await iphone.readOrCreate();
    await iphone.saveRegistration(
      deviceToken: 'dv_old',
      accountId: 'acc_old',
      tier: 'free',
      accountJoinToken: 'aj_old',
    );
    final items = Map.of(keychain.items);
    final kept = await iphone.snapshot();
    await iphone.saveRegistration(
      deviceToken: 'dv_new',
      accountId: 'acc_new',
      tier: 'hosted',
      accountJoinToken: 'aj_new',
    );
    await iphone.restore(kept);
    expect(keychain.items, items);
    expect((await iphone.readOrCreate()).deviceToken, 'dv_old');
  });

  test('putting an identity back tells whoever reads the identity, on '
      'Android and in the iOS Keychain', () async {
    final prefs = await SharedPreferences.getInstance();
    for (final store in [
      DeviceIdentityStore(prefs),
      KeychainDeviceIdentityStore(prefs),
    ]) {
      final snapshot = await store.snapshot();
      await store.readOrCreate();
      await store.saveRegistration(
        deviceToken: 'dv_new',
        accountId: 'acc_new',
        tier: 'hosted',
      );
      var rings = 0;
      void count() => rings++;
      store.changes.addListener(count);
      await store.restore(snapshot);
      store.changes.removeListener(count);
      expect(rings, greaterThan(0), reason: '${store.runtimeType}');
      await store.clear();
    }
  });

  test('a phone that holds nothing reads as nothing and mints no id', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(await DeviceIdentityStore(prefs).read(), isNull);
    expect(prefs.getKeys(), isEmpty);
  });

  test(
    'iOS identity round-trips through Keychain after preferences are lost',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = KeychainDeviceIdentityStore(prefs);
      final original = await store.readOrCreate();
      await store.saveRegistration(
        deviceToken: 'dv_kept',
        accountId: 'acc_kept',
        tier: 'hosted',
      );
      SharedPreferences.setMockInitialValues({});
      final restored = await KeychainDeviceIdentityStore(
        await SharedPreferences.getInstance(),
      ).readOrCreate();
      expect(restored.deviceId, original.deviceId);
      expect(restored.deviceToken, 'dv_kept');
      expect(restored.accountId, 'acc_kept');
      expect(restored.tier, 'hosted');
      expect(prefs.getKeys(), isEmpty);
    },
  );

  test(
    'iOS migration preserves existing device id, token, account and tier',
    () async {
      SharedPreferences.setMockInitialValues({
        'device_id': 'dev_existing',
        'device_token': 'dv_existing',
        'account_id': 'acc_existing',
        'account_tier': 'relay',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = KeychainDeviceIdentityStore(prefs);
      final migrated = await store.readOrCreate();
      expect(migrated.deviceId, 'dev_existing');
      expect(migrated.deviceToken, 'dv_existing');
      expect(migrated.accountId, 'acc_existing');
      expect(migrated.tier, 'relay');
      expect(prefs.getKeys(), isEmpty);
      expect((await store.readOrCreate()).deviceId, 'dev_existing');
    },
  );

  test('failed Keychain migration leaves legacy identity intact', () async {
    SharedPreferences.setMockInitialValues({
      'device_id': 'dev_existing',
      'device_token': 'dv_existing',
    });
    final prefs = await SharedPreferences.getInstance();
    keychain.failWrite = true;
    await expectLater(
      KeychainDeviceIdentityStore(prefs).readOrCreate(),
      throwsA(isA<PlatformException>()),
    );
    expect(prefs.getString('device_id'), 'dev_existing');
    expect(prefs.getString('device_token'), 'dv_existing');
  });
}
