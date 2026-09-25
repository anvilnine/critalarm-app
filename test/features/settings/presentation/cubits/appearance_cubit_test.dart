import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/settings/domain/entities/appearance_settings.dart';
import 'package:critalarm/features/settings/domain/repositories/appearance_settings_repository.dart';
import 'package:critalarm/features/settings/domain/usecases/get_appearance_settings_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/set_haptics_enabled_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/set_reduce_motion_usecase.dart';
import 'package:critalarm/features/settings/presentation/cubits/appearance_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryRepository implements AppearanceSettingsRepository {
  AppearanceSettings stored = const AppearanceSettings();
  bool failReads = false;

  @override
  Future<AppResult<AppearanceSettings>> getAppearanceSettings() async {
    if (failReads) {
      return const Failure.unexpected(message: 'boom').toFailure();
    }
    return stored.toSuccess();
  }

  @override
  Future<AppResult<Unit>> setReduceMotion({required bool enabled}) async {
    stored = stored.copyWith(reduceMotion: enabled);
    return unit.toSuccess();
  }

  @override
  Future<AppResult<Unit>> setHapticsEnabled({required bool enabled}) async {
    stored = stored.copyWith(hapticsEnabled: enabled);
    return unit.toSuccess();
  }
}

void main() {
  late _MemoryRepository repository;
  late AppearanceCubit cubit;

  AppearanceCubit build() => AppearanceCubit(
    GetAppearanceSettingsUsecase(repository),
    SetReduceMotionUsecase(repository),
    SetHapticsEnabledUsecase(repository),
  );

  setUp(() {
    repository = _MemoryRepository();
    cubit = build();
  });

  tearDown(() async {
    await cubit.close();
    AppHaptics.userEnabled = true;
  });

  test('starts at the defaults before anything loads', () {
    expect(cubit.state, const AppearanceSettings());
  });

  test('load emits the saved choices', () async {
    repository.stored = const AppearanceSettings(
      reduceMotion: true,
      hapticsEnabled: false,
    );

    await cubit.load();

    expect(
      cubit.state,
      const AppearanceSettings(reduceMotion: true, hapticsEnabled: false),
    );
  });

  test('a failed load keeps the defaults', () async {
    repository.failReads = true;

    await cubit.load();

    expect(cubit.state, const AppearanceSettings());
  });

  test('setReduceMotion updates the state and saves it', () async {
    await cubit.setReduceMotion(enabled: true);

    expect(cubit.state.reduceMotion, isTrue);
    expect(repository.stored.reduceMotion, isTrue);
  });

  test('setHapticsEnabled updates the state and saves it', () async {
    await cubit.setHapticsEnabled(enabled: false);

    expect(cubit.state.hapticsEnabled, isFalse);
    expect(repository.stored.hapticsEnabled, isFalse);
  });

  test('haptics switch off at once, before the save finishes', () {
    // Not awaited: the tick played right after the switch must already see
    // the new value.
    final saving = cubit.setHapticsEnabled(enabled: false);

    expect(AppHaptics.userEnabled, isFalse);
    return saving;
  });

  test('a loaded "haptics off" reaches AppHaptics', () async {
    repository.stored = const AppearanceSettings(hapticsEnabled: false);

    await cubit.load();

    expect(AppHaptics.userEnabled, isFalse);
  });
}
