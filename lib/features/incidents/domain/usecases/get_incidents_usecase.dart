import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';

/// Parameters for querying incidents from the server.
class GetIncidentsParams {
  const GetIncidentsParams({
    this.limit,
    this.state,
    this.topic,
  });

  final int? limit;
  final String? state;
  final String? topic;
}

/// Usecase to fetch incidents from the repository.
class GetIncidentsUsecase
    implements UseCase<GetIncidentsParams, List<Incident>> {
  const GetIncidentsUsecase(this._repository);

  final IncidentRepository _repository;

  @override
  Future<AppResult<List<Incident>>> call([
    GetIncidentsParams params = const GetIncidentsParams(),
  ]) =>
      _repository.getIncidents(
        limit: params.limit,
        state: params.state,
        topic: params.topic,
      );
}
