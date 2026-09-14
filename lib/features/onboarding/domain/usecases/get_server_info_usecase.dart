import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_info.dart';
import 'package:critalarm/features/onboarding/domain/repositories/server_repository.dart';

/// Usecase to fetch server information and validate connectivity.
class GetServerInfoUsecase implements UseCase<Uri, ServerInfo> {
  const GetServerInfoUsecase(this._repository);

  final ServerRepository _repository;

  @override
  Future<AppResult<ServerInfo>> call(Uri input) =>
      _repository.getServerInfo(input);
}
