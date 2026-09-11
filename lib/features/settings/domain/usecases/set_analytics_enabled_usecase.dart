import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/settings/domain/repositories/privacy_repository.dart';

/// Usecase to update the anonymous analytics opt-in preference.
class SetAnalyticsEnabledUsecase implements UseCase<bool, Unit> {
  const SetAnalyticsEnabledUsecase(this._repository);

  final PrivacyRepository _repository;

  @override
  Future<AppResult<Unit>> call(bool input) =>
      _repository.setAnalyticsEnabled(enabled: input);
}
