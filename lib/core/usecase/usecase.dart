import 'package:critalarm/core/result/result.dart';

/// Base contract for all usecases: one input, one [AppResult] output.
// ignore: one_member_abstracts
abstract interface class UseCase<I, O extends Object> {
  Future<AppResult<O>> call(I input);
}

/// Input for usecases that take no parameters.
class NoParams {
  const NoParams();
}
