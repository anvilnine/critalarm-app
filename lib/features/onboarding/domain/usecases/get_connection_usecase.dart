import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/repositories/connection_repository.dart';

/// Usecase to fetch the current server connection if configured.
class GetConnectionUsecase implements UseCase<NoParams, ServerConnection> {
  const GetConnectionUsecase(this._repository);

  final ConnectionRepository _repository;

  @override
  Future<AppResult<ServerConnection>> call(NoParams input) =>
      _repository.getConnection();
}
