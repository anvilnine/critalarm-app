import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';

/// Usecase to fetch a single incident by ID.
class GetIncidentUsecase implements UseCase<String, Incident> {
  const GetIncidentUsecase(this._repository);

  final IncidentRepository _repository;

  @override
  Future<AppResult<Incident>> call(String id) => _repository.getIncident(id);
}
