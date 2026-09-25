import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/settings/domain/entities/appearance_settings.dart';
import 'package:critalarm/features/settings/domain/usecases/get_appearance_settings_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/set_haptics_enabled_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/set_reduce_motion_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// App-wide reduce motion and haptics choices. Starts at the defaults (follow
/// the OS, haptics on) until the saved values load, and stays there if
/// loading fails.
class AppearanceCubit extends Cubit<AppearanceSettings> {
  AppearanceCubit(
    this._getSettings,
    this._setReduceMotion,
    this._setHapticsEnabled,
  ) : super(const AppearanceSettings());

  final GetAppearanceSettingsUsecase _getSettings;
  final SetReduceMotionUsecase _setReduceMotion;
  final SetHapticsEnabledUsecase _setHapticsEnabled;

  Future<void> load() async {
    final result = await _getSettings(const NoParams());
    result.fold(emit, (_) {});
  }

  /// Keeps [AppHaptics] in step the moment the choice changes, not a frame
  /// later, so the tap that turns haptics on is already felt.
  @override
  void emit(AppearanceSettings state) {
    AppHaptics.userEnabled = state.hapticsEnabled;
    super.emit(state);
  }

  Future<void> setReduceMotion({required bool enabled}) async {
    emit(state.copyWith(reduceMotion: enabled));
    await _setReduceMotion(enabled);
  }

  Future<void> setHapticsEnabled({required bool enabled}) async {
    emit(state.copyWith(hapticsEnabled: enabled));
    await _setHapticsEnabled(enabled);
  }
}
