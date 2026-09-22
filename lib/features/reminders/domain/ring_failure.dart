import 'package:critalarm/core/failures/failure.dart';

/// Why a test ring did not go out.
enum RingFailure {
  /// 409: `POST /v1/test` only rings a critical topic (api.md 3.3).
  notCritical,

  /// 401: the server does not accept this phone's credential.
  unauthorized,

  /// The request never reached the server.
  offline,

  other;

  /// 409, 401 and offline count as a failed test. The review ask (idea 21)
  /// and the feedback ask (idea 22) hold back after one.
  bool get countsAsFailedTest => this != RingFailure.other;
}

abstract final class RingFailures {
  static const List<String> _offlineHints = [
    'SocketException',
    'ClientException',
    'Failed host lookup',
    'Connection refused',
    'Connection closed',
    'Network is unreachable',
    'TimeoutException',
  ];

  static RingFailure classify(Failure failure) => switch (failure) {
    ApiFailure(statusCode: 409) || ConflictFailure() => RingFailure.notCritical,
    ApiFailure(statusCode: 401) || UnauthorizedFailure() =>
      RingFailure.unauthorized,
    UnexpectedFailure(:final message) when _isOffline(message) =>
      RingFailure.offline,
    _ => RingFailure.other,
  };

  static bool _isOffline(String? message) =>
      message != null && _offlineHints.any(message.contains);
}
