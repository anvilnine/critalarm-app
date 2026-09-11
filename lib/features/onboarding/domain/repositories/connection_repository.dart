import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';

/// Contract for persisting and retrieving server connection details.
abstract interface class ConnectionRepository {
  /// Retrieves the saved server connection, or a failure if unset.
  Future<AppResult<ServerConnection>> getConnection();

  /// Persists the active server connection.
  Future<AppResult<Unit>> saveConnection(ServerConnection connection);

  /// Clears the saved server connection.
  Future<AppResult<Unit>> clearConnection();
}
