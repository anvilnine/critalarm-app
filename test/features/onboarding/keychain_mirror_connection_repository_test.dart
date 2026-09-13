import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/storage/nse_credential_store.dart';
import 'package:critalarm/features/onboarding/data/repositories/keychain_mirror_connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/repositories/connection_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The mirror does not wait on the keychain, so give the channel call a turn
/// of the event loop before looking at what it sent.
Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(NseCredentialStore.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late _MemoryConnections inner;
  late KeychainMirrorConnectionRepository repository;

  const connection = ServerConnection(
    serverUrl: 'https://alerts.example.com',
    adminToken: 'dv_secret',
  );

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    inner = _MemoryConnections();
    repository = KeychainMirrorConnectionRepository(
      inner,
      const NseCredentialStore(),
    );
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('saving lands in prefs and in the extension keychain', () async {
    await repository.saveConnection(connection);
    await settle();

    expect(inner.saved, connection);
    expect(calls.single.method, 'write');
    expect(calls.single.arguments, {
      'server': 'https://alerts.example.com',
      'token': 'dv_secret',
    });
  });

  test('clearing wipes both', () async {
    await repository.saveConnection(connection);
    await repository.clearConnection();
    await settle();

    expect(inner.saved, isNull);
    expect(calls.map((c) => c.method), ['write', 'clear']);
  });

  test('a failed save leaves the keychain alone', () async {
    inner.fail = true;

    await repository.saveConnection(connection);
    await settle();

    expect(calls, isEmpty);
  });

  test('a server URL that will not parse is not mirrored', () async {
    await repository.saveConnection(
      const ServerConnection(serverUrl: '::::', adminToken: 'dv_secret'),
    );
    await settle();

    expect(calls, isEmpty);
  });

  test('reading does not touch the keychain', () async {
    await repository.saveConnection(connection);
    await settle();
    calls.clear();

    final result = await repository.getConnection();

    expect(result.getOrNull()?.adminToken, 'dv_secret');
    expect(calls, isEmpty);
  });

  test('a platform with no handler does not fail the save', () async {
    messenger.setMockMethodCallHandler(channel, null);

    final result = await repository.saveConnection(connection);

    expect(result.isSuccess(), isTrue);
    expect(inner.saved, connection);
  });
}

class _MemoryConnections implements ConnectionRepository {
  ServerConnection? saved;
  bool fail = false;

  @override
  Future<AppResult<ServerConnection>> getConnection() async {
    final current = saved;
    if (current == null) {
      return const Failure.notFound(message: 'none').toFailure();
    }
    return current.toSuccess();
  }

  @override
  Future<AppResult<Unit>> saveConnection(ServerConnection connection) async {
    if (fail) return const Failure.unexpected(message: 'disk').toFailure();
    saved = connection;
    return unit.toSuccess();
  }

  @override
  Future<AppResult<Unit>> clearConnection() async {
    saved = null;
    return unit.toSuccess();
  }
}
