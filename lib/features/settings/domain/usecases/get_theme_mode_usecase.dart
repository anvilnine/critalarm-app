import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/settings/domain/entities/app_theme_mode.dart';
import 'package:critalarm/features/settings/domain/repositories/theme_preference_repository.dart';

class GetThemeModeUsecase implements UseCase<NoParams, AppThemeMode> {
  const GetThemeModeUsecase(this._repository);

  final ThemePreferenceRepository _repository;

  @override
  Future<AppResult<AppThemeMode>> call(NoParams input) =>
      _repository.getThemeMode();
}
