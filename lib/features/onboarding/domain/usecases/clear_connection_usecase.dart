import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/repositories/connection_repository.dart';

/// Usecase to clear saved server connection details.
class ClearConnectionUsecase implements UseCase<NoParams, Unit> {
  const ClearConnectionUsecase(this._repository, {this.beforeClear});

  final ConnectionRepository _repository;

  /// Runs before the connection is removed. The app uses it to drop a
  /// connect that is still waiting to land. It comes first so a connect on
  /// its way cannot save a connection in the gap after the clear.
  final Future<void> Function()? beforeClear;

  @override
  Future<AppResult<Unit>> call(NoParams input) async {
    await beforeClear?.call();
    return _repository.clearConnection();
  }
}
