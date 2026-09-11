import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';

/// Usecase to close an acknowledged incident on the server ("At my desk").
class CloseIncidentUsecase implements UseCase<String, Incident> {
  const CloseIncidentUsecase(this._repository);

  final IncidentRepository _repository;

  @override
  Future<AppResult<Incident>> call(String id) => _repository.closeIncident(id);
}
