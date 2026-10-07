import 'dart:async';

import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/repositories/connection_repository.dart';

/// Tells whoever asked when a connection is saved or removed.
///
/// A connection is saved from several places: the setup connect step, a
/// connect link, the Crit Alarm Cloud connect that runs behind the user,
/// Server settings and an account switch. All of them go through the one
/// repository, so this is the one place that sees every one of them, at the
/// moment it happens.
///
/// The callbacks are told after the write succeeded and are not waited for.
/// One that throws changes nothing about the save.
final class ObservedConnectionRepository implements ConnectionRepository {
  const ObservedConnectionRepository(
    this._inner, {
    required this.onSaved,
    required this.onCleared,
  });

  final ConnectionRepository _inner;

  /// Called with the saved server address.
  final Future<void> Function(String serverUrl) onSaved;
  final Future<void> Function() onCleared;

  @override
  Future<AppResult<ServerConnection>> getConnection() => _inner.getConnection();

  @override
  Future<AppResult<Unit>> saveConnection(ServerConnection connection) async {
    final result = await _inner.saveConnection(connection);
    if (result.isSuccess()) _tell(() => onSaved(connection.serverUrl));
    return result;
  }

  @override
  Future<AppResult<Unit>> clearConnection() async {
    final result = await _inner.clearConnection();
    if (result.isSuccess()) _tell(onCleared);
    return result;
  }

  void _tell(Future<void> Function() callback) {
    unawaited(
      Future<void>.sync(callback).catchError((Object _) {
        // Nothing waits on this, and the save already stands.
      }),
    );
  }
}
