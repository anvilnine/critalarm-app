import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/settings/domain/repositories/appearance_settings_repository.dart';

/// Usecase to save whether the app cuts its animations regardless of the OS.
class SetReduceMotionUsecase implements UseCase<bool, Unit> {
  const SetReduceMotionUsecase(this._repository);

  final AppearanceSettingsRepository _repository;

  @override
  Future<AppResult<Unit>> call(bool input) =>
      _repository.setReduceMotion(enabled: input);
}
