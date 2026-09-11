import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/repositories/connection_repository.dart';

/// Usecase to save server connection details after validation.
class SaveConnectionUsecase implements UseCase<ServerConnection, Unit> {
  const SaveConnectionUsecase(this._repository);

  final ConnectionRepository _repository;

  @override
  Future<AppResult<Unit>> call(ServerConnection connection) =>
      _repository.saveConnection(connection);
}
