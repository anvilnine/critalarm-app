import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/repositories/connection_repository.dart';

/// Usecase to clear saved server connection details.
class ClearConnectionUsecase implements UseCase<NoParams, Unit> {
  const ClearConnectionUsecase(this._repository);

  final ConnectionRepository _repository;

  @override
  Future<AppResult<Unit>> call(NoParams input) => _repository.clearConnection();
}
