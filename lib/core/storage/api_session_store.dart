import 'package:critalarm/core/api/api_session.dart';

/// Persistent source of the active canonical API session.
abstract interface class ApiSessionStore {
  Future<ApiSession?> read();

  Future<void> write(ApiSession session);

  Future<void> clear();
}
