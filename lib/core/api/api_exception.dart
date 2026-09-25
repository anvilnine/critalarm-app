/// Exception thrown when an API request fails with an HTTP error status code.
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.message,
    this.code,
    this.cap,
  });

  final int statusCode;
  final String message;
  final int? code;
  final String? cap;

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, message: $message, code: $code, '
      'cap: $cap)';
}

/// Thrown when a call needs a server and none is set up yet, such as the app
/// coming back to the front mid onboarding. An [Exception], not an Error, so
/// the repositories' `on Exception` turn it into a failure instead of a crash.
class NoApiSessionException implements Exception {
  const NoApiSessionException();

  @override
  String toString() => 'No API session configured';
}
