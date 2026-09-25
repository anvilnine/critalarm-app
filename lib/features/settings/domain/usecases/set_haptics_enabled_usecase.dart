import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/settings/domain/repositories/appearance_settings_repository.dart';

/// Usecase to save whether the app plays haptics for taps and confirmations.
class SetHapticsEnabledUsecase implements UseCase<bool, Unit> {
  const SetHapticsEnabledUsecase(this._repository);

  final AppearanceSettingsRepository _repository;

  @override
  Future<AppResult<Unit>> call(bool input) =>
      _repository.setHapticsEnabled(enabled: input);
}
