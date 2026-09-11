import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/repositories/connection_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences implementation of [ConnectionRepository].
class SharedPrefsConnectionRepository implements ConnectionRepository {
  const SharedPrefsConnectionRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _keyServerUrl = 'server_url';
  static const _keyAdminToken = 'admin_token';

  @override
  Future<AppResult<ServerConnection>> getConnection() async {
    try {
      final url = _prefs.getString(_keyServerUrl);
      final token = _prefs.getString(_keyAdminToken);
      if (url == null || url.isEmpty || token == null || token.isEmpty) {
        return const Failure.notFound(
          message: 'No saved connection',
        ).toFailure();
      }
      return ServerConnection(serverUrl: url, adminToken: token).toSuccess();
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }

  @override
  Future<AppResult<Unit>> saveConnection(ServerConnection connection) async {
    try {
      await _prefs.setString(_keyServerUrl, connection.serverUrl);
      await _prefs.setString(_keyAdminToken, connection.adminToken);
      return unit.toSuccess();
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }

  @override
  Future<AppResult<Unit>> clearConnection() async {
    try {
      await _prefs.remove(_keyServerUrl);
      await _prefs.remove(_keyAdminToken);
      return unit.toSuccess();
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }
}
