import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/settings/domain/entities/appearance_settings.dart';
import 'package:critalarm/features/settings/domain/repositories/appearance_settings_repository.dart';

/// Usecase to read the saved reduce motion and haptics choices.
class GetAppearanceSettingsUsecase
    implements UseCase<NoParams, AppearanceSettings> {
  const GetAppearanceSettingsUsecase(this._repository);

  final AppearanceSettingsRepository _repository;

  @override
  Future<AppResult<AppearanceSettings>> call(NoParams input) =>
      _repository.getAppearanceSettings();
}
