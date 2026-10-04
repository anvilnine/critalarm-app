import 'package:critalarm/features/onboarding/domain/connect/connect_intent_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late ConnectIntentStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = ConnectIntentStore(prefs);
  });

  test('reads nothing before anything is saved', () {
    expect(store.read(), isNull);
  });

  test('saves and reads an intent back', () async {
    await store.save(
      const ConnectIntent(
        serverUrl: 'https://api.critalarm.app',
        attempts: 3,
        nextAttemptAtMs: 1234,
      ),
    );

    final read = ConnectIntentStore(prefs).read();
    expect(read, isNotNull);
    expect(read!.serverUrl, 'https://api.critalarm.app');
    expect(read.attempts, 3);
    expect(read.nextAttemptAtMs, 1234);
  });

  test('clear removes the intent', () async {
    await store.save(
      const ConnectIntent(serverUrl: 'https://api.critalarm.app'),
    );
    await store.clear();

    expect(store.read(), isNull);
    expect(prefs.containsKey(ConnectIntentStore.storageKey), isFalse);
  });

  test('the stored value holds the server address and no token', () async {
    await store.save(
      const ConnectIntent(serverUrl: 'https://api.critalarm.app'),
    );

    final raw = prefs.getString(ConnectIntentStore.storageKey)!;
    expect(raw, contains('https://api.critalarm.app'));
    expect(raw.toLowerCase(), isNot(contains('token')));
    expect(
      const ConnectIntent(serverUrl: 'x').toJson().keys,
      unorderedEquals(['server_url', 'attempts', 'next_attempt_at_ms']),
    );
  });

  test(
    'lives under its own key, apart from the setup draft and the server',
    () async {
      await store.save(
        const ConnectIntent(serverUrl: 'https://api.critalarm.app'),
      );

      expect(prefs.getKeys(), {ConnectIntentStore.storageKey});
    },
  );

  test('a value that is not an intent reads as nothing', () async {
    await prefs.setString(ConnectIntentStore.storageKey, 'not json');
    expect(store.read(), isNull);

    await prefs.setString(ConnectIntentStore.storageKey, '{"attempts": 2}');
    expect(store.read(), isNull);
  });
}
