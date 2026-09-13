import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/storage/mirrored_api_session_store.dart';
import 'package:critalarm/core/storage/nse_credential_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final Uri _base = Uri.parse('https://alerts.example.com');
final Uri _relay = Uri.parse('https://relay.critalarm.app');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(NseCredentialStore.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late _MemorySessionStore inner;
  late MirroredApiSessionStore store;

  final session = ApiSession(
    baseUri: _base,
    relayUri: _relay,
    mode: ServerMode.selfhosted,
    managementCredential: 'dv_secret',
  );

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    inner = _MemorySessionStore();
    store = MirroredApiSessionStore(inner, const NseCredentialStore());
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('a write lands in prefs and in the extension keychain', () async {
    await store.write(session);

    expect(inner.saved, isNotNull);
    expect(calls.single.method, 'write');
    expect(calls.single.arguments, {
      'server': 'https://alerts.example.com',
      'token': 'dv_secret',
    });
  });

  test('a clear wipes both', () async {
    await store.write(session);
    await store.clear();

    expect(inner.saved, isNull);
    expect(calls.map((c) => c.method), ['write', 'clear']);
  });

  test('reading does not touch the keychain', () async {
    await store.write(session);
    calls.clear();

    expect((await store.read())?.managementCredential, 'dv_secret');
    expect(calls, isEmpty);
  });

  test('a platform with no handler does not fail the write', () async {
    messenger.setMockMethodCallHandler(channel, null);
    await store.write(session);
    expect(inner.saved, isNotNull);
  });
}

class _MemorySessionStore implements ApiSessionStore {
  ApiSession? saved;

  @override
  Future<ApiSession?> read() async => saved;

  @override
  Future<void> write(ApiSession session) async => saved = session;

  @override
  Future<void> clear() async => saved = null;
}
