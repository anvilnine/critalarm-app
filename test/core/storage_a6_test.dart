import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/storage/shared_prefs_api_session_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.critalarm/device_identity');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  String? keychain;
  var failWrite = false;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    keychain = null;
    failWrite = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'read') return keychain;
      if (failWrite) throw PlatformException(code: 'keychain_write');
      keychain = call.arguments as String;
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

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
    failWrite = true;
    await expectLater(
      KeychainDeviceIdentityStore(prefs).readOrCreate(),
      throwsA(isA<PlatformException>()),
    );
    expect(prefs.getString('device_id'), 'dev_existing');
    expect(prefs.getString('device_token'), 'dv_existing');
  });
}
