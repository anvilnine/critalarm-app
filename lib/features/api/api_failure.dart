import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/features/api/models/api_error.dart';
import 'package:flutter/foundation.dart';

/// An API failure carrying code, http and error fields from api.md §1.8.
@immutable
class ApiFailure implements Exception {
  const ApiFailure({
    required this.code,
    required this.http,
    required this.error,
  });

  /// Creates an [ApiFailure] from an [ApiError] model.
  factory ApiFailure.fromApiError(ApiError apiError) => ApiFailure(
    code: apiError.code,
    http: apiError.http,
    error: apiError.error,
  );

  /// Error code as specified in api.md §1.8 (e.g. 40101).
  final int code;

  /// HTTP status code (e.g. 401).
  final int http;

  /// Error message string.
  final String error;

  /// Human-readable error message.
  String get message => error;

  /// Converts this [ApiFailure] to a core [Failure].
  Failure toFailure() {
    if (http == 404) {
      return Failure.notFound(message: error);
    }
    return Failure.unexpected(message: error);
  }

  @override
  String toString() => 'ApiFailure(code: $code, http: $http, error: $error)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApiFailure &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          http == other.http &&
          error == other.error;

  @override
  int get hashCode => Object.hash(code, http, error);
}
