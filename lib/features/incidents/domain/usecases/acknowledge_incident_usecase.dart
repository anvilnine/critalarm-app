import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';

/// Usecase to acknowledge an open incident on the server ("I'm up").
class AcknowledgeIncidentUsecase implements UseCase<String, Incident> {
  const AcknowledgeIncidentUsecase(this._repository);

  final IncidentRepository _repository;

  @override
  Future<AppResult<Incident>> call(String id) => _repository.ackIncident(id);
}
