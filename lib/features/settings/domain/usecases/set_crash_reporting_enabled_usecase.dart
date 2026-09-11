import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/settings/domain/repositories/privacy_repository.dart';

/// Usecase to update the crash reporting opt-in preference.
class SetCrashReportingEnabledUsecase implements UseCase<bool, Unit> {
  const SetCrashReportingEnabledUsecase(this._repository);

  final PrivacyRepository _repository;

  @override
  Future<AppResult<Unit>> call(bool input) =>
      _repository.setCrashReportingEnabled(enabled: input);
}
