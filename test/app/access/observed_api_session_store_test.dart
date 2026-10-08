import 'package:critalarm/app/access/observed_api_session_store.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemorySessions implements ApiSessionStore {
  ApiSession? saved;

  @override
  Future<ApiSession?> read() async => saved;

  @override
  Future<void> write(ApiSession session) async => saved = session;

  @override
  Future<void> clear() async => saved = null;
}

ApiSession _session(ServerMode mode) => ApiSession(
  baseUri: Uri.parse('https://example.test'),
  relayUri: Uri.parse('https://relay.example.test'),
  mode: mode,
  managementCredential: 'dv_test',
);

void main() {
  late _MemorySessions inner;
  late ObservedApiSessionStore store;
  late List<ServerMode?> heard;

  setUp(() {
    inner = _MemorySessions();
    store = ObservedApiSessionStore(inner);
    heard = [];
    store.mode.addListener(() => heard.add(store.mode.value));
  });

  test('the mode is unknown until something is read or written', () {
    expect(store.mode.value, isNull);
  });

  test('a read hands back what the store holds and learns its mode', () async {
    inner.saved = _session(ServerMode.selfhosted);
    final session = await store.read();
    expect(session, same(inner.saved));
    expect(store.mode.value, ServerMode.selfhosted);
    expect(heard, [ServerMode.selfhosted]);
  });

  test('a write saves the session and announces its mode', () async {
    final session = _session(ServerMode.hosted);
    await store.write(session);
    expect(inner.saved, same(session));
    expect(heard, [ServerMode.hosted]);
  });

  test('the same mode twice is announced once', () async {
    await store.write(_session(ServerMode.hosted));
    await store.write(_session(ServerMode.hosted));
    await store.read();
    expect(heard, [ServerMode.hosted]);
  });

  test('a clear empties the store and the mode', () async {
    await store.write(_session(ServerMode.relay));
    await store.clear();
    expect(inner.saved, isNull);
    expect(heard, [ServerMode.relay, null]);
  });
}
