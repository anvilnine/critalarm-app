import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/onboarding/data/repositories/observed_connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/repositories/connection_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _Inner implements ConnectionRepository {
  bool fail = false;
  ServerConnection? saved;

  @override
  Future<AppResult<ServerConnection>> getConnection() async {
    final held = saved;
    return held == null
        ? const Failure.notFound(message: 'none').toFailure()
        : held.toSuccess();
  }

  @override
  Future<AppResult<Unit>> saveConnection(ServerConnection connection) async {
    if (fail) return const Failure.notFound(message: 'disk').toFailure();
    saved = connection;
    return unit.toSuccess();
  }

  @override
  Future<AppResult<Unit>> clearConnection() async {
    if (fail) return const Failure.notFound(message: 'disk').toFailure();
    saved = null;
    return unit.toSuccess();
  }
}

void main() {
  late _Inner inner;
  late List<String> heard;

  ObservedConnectionRepository build({bool throwing = false}) =>
      ObservedConnectionRepository(
        inner,
        onSaved: (url) async {
          if (throwing) throw StateError('listener');
          heard.add('saved $url');
        },
        onCleared: () async {
          if (throwing) throw StateError('listener');
          heard.add('cleared');
        },
      );

  const connection = ServerConnection(
    serverUrl: 'https://alerts.example.com',
    adminToken: 'token',
  );

  setUp(() {
    inner = _Inner();
    heard = [];
  });

  test('a save is told, with the address and never the token', () async {
    final result = await build().saveConnection(connection);
    await Future<void>.delayed(Duration.zero);
    expect(result.isSuccess(), isTrue);
    expect(inner.saved, connection);
    expect(heard, ['saved https://alerts.example.com']);
  });

  test('a removal is told', () async {
    inner.saved = connection;
    await build().clearConnection();
    await Future<void>.delayed(Duration.zero);
    expect(inner.saved, isNull);
    expect(heard, ['cleared']);
  });

  test('a save or a removal that failed is not told', () async {
    inner.fail = true;
    final repo = build();
    expect((await repo.saveConnection(connection)).isSuccess(), isFalse);
    expect((await repo.clearConnection()).isSuccess(), isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(heard, isEmpty);
  });

  test('a listener that throws changes nothing about the save', () async {
    final result = await build(throwing: true).saveConnection(connection);
    await Future<void>.delayed(Duration.zero);
    expect(result.isSuccess(), isTrue);
    expect(inner.saved, connection);
  });

  test('reads go straight through', () async {
    inner.saved = connection;
    expect((await build().getConnection()).getOrNull(), connection);
    expect(heard, isEmpty);
  });
}
