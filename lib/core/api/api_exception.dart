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
