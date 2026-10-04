import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/repositories/connection_repository.dart';

/// Usecase to clear saved server connection details.
class ClearConnectionUsecase implements UseCase<NoParams, Unit> {
  const ClearConnectionUsecase(this._repository, {this.onCleared});

  final ConnectionRepository _repository;

  /// Runs after the connection is gone. The app uses it to drop a connect
  /// that is still waiting to land, so a server the user just left is not
  /// connected again behind them.
  final Future<void> Function()? onCleared;

  @override
  Future<AppResult<Unit>> call(NoParams input) async {
    final result = await _repository.clearConnection();
    await onCleared?.call();
    return result;
  }
}
