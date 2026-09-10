import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/settings/domain/entities/app_theme_mode.dart';
import 'package:critalarm/features/settings/domain/repositories/theme_preference_repository.dart';

class SetThemeModeUsecase implements UseCase<AppThemeMode, Unit> {
  const SetThemeModeUsecase(this._repository);

  final ThemePreferenceRepository _repository;

  @override
  Future<AppResult<Unit>> call(AppThemeMode input) =>
      _repository.setThemeMode(input);
}
