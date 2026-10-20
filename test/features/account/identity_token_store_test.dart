import 'package:critalarm/features/account/data/services/identity_token_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for the iOS Keychain behind `app.critalarm/device_identity`.
final class _Keychain {
  static const channel = MethodChannel('app.critalarm/device_identity');

  String? value;
  final List<MethodCall> calls = [];
  bool failRead = false;
  bool failWrite = false;
  bool failDelete = false;

  void install() => TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        final args = (call.arguments as Map).cast<String, Object?>();
        expect(args['service'], KeychainIdentityTokenStore.service);
        expect(args['synchronizable'], isFalse);
        switch (call.method) {
          case 'read':
            if (failRead) throw PlatformException(code: 'keychain_read');
            return value;
          case 'write':
            if (failWrite) throw PlatformException(code: 'keychain_write');
            expect(args['this_device_only'], isTrue);
            value = args['value'] as String?;
            return null;
          case 'delete':
            if (failDelete) throw PlatformException(code: 'keychain_delete');
            value = null;
            return null;
        }
        throw MissingPluginException(call.method);
      });

  void remove() => TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null);

  List<String> get methods => [for (final call in calls) call.method];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Keychain keychain;

  setUp(() {
    keychain = _Keychain()..install();
  });

  tearDown(() => keychain.remove());

  Future<SharedPreferences> prefsWith([Map<String, Object> values = const {}]) {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  group('KeychainIdentityTokenStore', () {
    test('a new sign-in goes to the Keychain only', () async {
      final prefs = await prefsWith();
      final store = KeychainIdentityTokenStore(prefs);
      await store.write('sess_new');
      expect(keychain.value, 'sess_new');
      expect(prefs.getString(identitySessionTokenKey), isNull);
      expect(await store.read(), 'sess_new');
    });

    test(
      'an older install moves its token once, then forgets the old key',
      () async {
        final prefs = await prefsWith({identitySessionTokenKey: 'sess_old'});
        final store = KeychainIdentityTokenStore(prefs);
        expect(await store.read(), 'sess_old');
        expect(keychain.value, 'sess_old');
        expect(prefs.getString(identitySessionTokenKey), isNull);

        keychain.calls.clear();
        expect(await store.read(), 'sess_old');
        expect(keychain.methods, ['read']);
      },
    );

    test(
      'a Keychain that cannot be written keeps the old copy for next time',
      () async {
        keychain.failWrite = true;
        final prefs = await prefsWith({identitySessionTokenKey: 'sess_old'});
        final store = KeychainIdentityTokenStore(prefs);
        expect(await store.read(), 'sess_old');
        expect(prefs.getString(identitySessionTokenKey), 'sess_old');

        keychain.failWrite = false;
        expect(await store.read(), 'sess_old');
        expect(keychain.value, 'sess_old');
        expect(prefs.getString(identitySessionTokenKey), isNull);
      },
    );

    test(
      'a move cut off before the old key went finishes on the next read',
      () async {
        keychain.value = 'sess_kept';
        final prefs = await prefsWith({identitySessionTokenKey: 'sess_kept'});
        final store = KeychainIdentityTokenStore(prefs);
        expect(await store.read(), 'sess_kept');
        expect(prefs.getString(identitySessionTokenKey), isNull);
      },
    );

    test('a Keychain that cannot be read falls back to the old copy', () async {
      keychain.failRead = true;
      final prefs = await prefsWith({identitySessionTokenKey: 'sess_old'});
      final store = KeychainIdentityTokenStore(prefs);
      expect(await store.read(), 'sess_old');
      // Nothing is thrown away on a read that did not answer.
      expect(prefs.getString(identitySessionTokenKey), 'sess_old');
    });

    test('nothing anywhere reads as signed out', () async {
      final store = KeychainIdentityTokenStore(await prefsWith());
      expect(await store.read(), isNull);
      expect(keychain.methods, ['read']);
    });

    test('signing out clears both places', () async {
      keychain.value = 'sess_a';
      final prefs = await prefsWith({identitySessionTokenKey: 'sess_a'});
      final store = KeychainIdentityTokenStore(prefs);
      await store.clear();
      expect(keychain.value, isNull);
      expect(prefs.getString(identitySessionTokenKey), isNull);
    });

    test('a Keychain delete that fails does not stop the sign-out', () async {
      keychain
        ..value = 'sess_a'
        ..failDelete = true;
      final prefs = await prefsWith({identitySessionTokenKey: 'sess_a'});
      await KeychainIdentityTokenStore(prefs).clear();
      expect(prefs.getString(identitySessionTokenKey), isNull);
    });
  });

  group('PrefsIdentityTokenStore', () {
    test('keeps the token under the key it always had', () async {
      final prefs = await prefsWith();
      final store = PrefsIdentityTokenStore(prefs);
      await store.write('sess_a');
      expect(prefs.getString(identitySessionTokenKey), 'sess_a');
      expect(await store.read(), 'sess_a');
      await store.clear();
      expect(await store.read(), isNull);
      expect(keychain.calls, isEmpty);
    });
  });
}
