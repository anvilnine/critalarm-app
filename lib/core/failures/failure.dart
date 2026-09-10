import 'package:freezed_annotation/freezed_annotation.dart';

part 'failure.freezed.dart';

/// The only failure type allowed to cross a layer boundary.
/// Add a new variant here instead of throwing across layers.
@freezed
sealed class Failure with _$Failure {
  const factory Failure.unexpected({String? message}) = UnexpectedFailure;
  const factory Failure.notFound({String? message}) = NotFoundFailure;
  const factory Failure.database({String? message}) = DatabaseFailure;

  /// The requested capability isn't available in this build/config — e.g. a
  /// noop provider that has no real backend yet (purchases before the store
  /// integration ships). Callers surface a "not available yet" message.
  const factory Failure.unsupported({String? message}) = UnsupportedFailure;
}
