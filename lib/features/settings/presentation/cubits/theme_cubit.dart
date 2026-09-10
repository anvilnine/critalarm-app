import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/settings/domain/entities/app_theme_mode.dart';
import 'package:critalarm/features/settings/domain/usecases/get_theme_mode_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/set_theme_mode_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// App-wide theme preference. State is the current [AppThemeMode]; defaults to
/// `system` until the stored value loads (and if loading ever fails).
class ThemeCubit extends Cubit<AppThemeMode> {
  ThemeCubit(this._getThemeMode, this._setThemeMode)
    : super(AppThemeMode.system);

  final GetThemeModeUsecase _getThemeMode;
  final SetThemeModeUsecase _setThemeMode;

  Future<void> load() async {
    final result = await _getThemeMode(const NoParams());
    // On failure keep the current default (system) — nothing to emit.
    result.fold(emit, (_) {});
  }

  Future<void> setMode(AppThemeMode mode) async {
    emit(mode);
    await _setThemeMode(mode);
  }
}
