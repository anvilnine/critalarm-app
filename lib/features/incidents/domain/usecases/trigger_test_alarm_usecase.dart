import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';

/// Usecase to trigger a test alarm on a critical topic.
class TriggerTestAlarmUsecase implements UseCase<String, String> {
  const TriggerTestAlarmUsecase(this._repository);

  final IncidentRepository _repository;

  @override
  Future<AppResult<String>> call(String topic) =>
      _repository.triggerTest(topic: topic);
}
