import 'package:freezed_annotation/freezed_annotation.dart';

part 'api_error.freezed.dart';
part 'api_error.g.dart';

/// Error object returned by server as described in api.md §1.8.
@freezed
abstract class ApiError with _$ApiError {
  const factory ApiError({
    required int code,
    required int http,
    required String error,
  }) = _ApiError;

  factory ApiError.fromJson(Map<String, dynamic> json) =>
      _$ApiErrorFromJson(json);
}
