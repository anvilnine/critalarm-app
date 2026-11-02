import 'dart:async';
import 'dart:convert';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/core/ack/ack_queue.dart';
import 'package:critalarm/core/alarm/alarm_debug_snapshot.dart';
import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/alarm/incident_alarm_controller.dart';
import 'package:critalarm/core/alarm/quiet_hours_store.dart';
import 'package:critalarm/core/format/clock_format.dart';
import 'package:critalarm/core/net/launch_call_log.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/push/push_event_drain.dart';
import 'package:critalarm/core/sound/own_sound_rule.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/core/sound/sound_import.dart';
import 'package:critalarm/core/sound/sound_pack_repository.dart';
import 'package:critalarm/core/sound/sound_peaks_cache.dart';
import 'package:critalarm/core/sound/sound_recorder.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/core/telemetry/onboarding_funnel.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_plan_trigger.dart';
import 'package:critalarm/features/onboarding/domain/usecases/clear_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/connect_to_server_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/establish_api_session_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/save_connection_usecase.dart';
import 'package:critalarm/features/settings/data/repositories/observed_privacy_repository.dart';
import 'package:critalarm/features/settings/data/repositories/shared_prefs_alarm_sound_repository.dart';
import 'package:critalarm/features/settings/data/repositories/shared_prefs_appearance_settings_repository.dart';
import 'package:critalarm/features/settings/data/repositories/shared_prefs_privacy_repository.dart';
import 'package:critalarm/features/settings/data/repositories/shared_prefs_storage_settings_repository.dart';
import 'package:critalarm/features/settings/data/repositories/shared_prefs_theme_preference_repository.dart';
import 'package:critalarm/features/settings/domain/repositories/alarm_sound_repository.dart';
import 'package:critalarm/features/settings/domain/repositories/appearance_settings_repository.dart';
import 'package:critalarm/features/settings/domain/repositories/privacy_repository.dart';
import 'package:critalarm/features/settings/domain/repositories/sound_file_picker.dart';
import 'package:critalarm/features/settings/domain/repositories/storage_settings_repository.dart';
import 'package:critalarm/features/settings/domain/repositories/theme_preference_repository.dart';
import 'package:critalarm/features/settings/domain/usecases/auto_delete_history_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/delete_user_sound_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/get_appearance_settings_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/get_privacy_settings_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/get_theme_mode_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/import_sound_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/set_analytics_enabled_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/set_crash_reporting_enabled_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/set_haptics_enabled_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/set_reduce_motion_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/set_theme_mode_usecase.dart';
import 'package:critalarm/features/settings/presentation/cubits/alarm_debug_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/appearance_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/personalize_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/priorities_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/recorder_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/sound_crop_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/sound_picker_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The saved theme choice.
void registerThemePreference(GetIt getIt) {
  getIt.registerLazySingleton<ThemePreferenceRepository>(
    () => SharedPrefsThemePreferenceRepository(getIt<SharedPreferences>()),
  );
}

/// The storage settings and the history auto-delete they drive.
void registerStorageSettings(GetIt getIt, {required LocalStore? localStore}) {
  getIt
    ..registerLazySingleton<StorageSettingsRepository>(
      () => SharedPrefsStorageSettingsRepository(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton<AutoDeleteHistoryUsecase>(
      () => AutoDeleteHistoryUsecase(
        localStore,
        () => getIt<StorageSettingsRepository>().read(),
      ),
    );
}

/// The appearance, privacy and alarm sound repositories.
void registerSettingsRepositories(GetIt getIt) {
  getIt
    ..registerLazySingleton<AppearanceSettingsRepository>(
      () => SharedPrefsAppearanceSettingsRepository(getIt<SharedPreferences>()),
    )
    // Every analytics answer is saved through this one repository, so the
    // setup funnel hears the setup switch, Settings > Privacy and the Home
    // consent sheet without each of them knowing about it.
    ..registerLazySingleton<PrivacyRepository>(
      () => ObservedPrivacyRepository(
        SharedPrefsPrivacyRepository(getIt<SharedPreferences>()),
        onAnalyticsChoice: ({required isOn}) =>
            getIt<OnboardingFunnel>().answered(isOn: isOn),
      ),
    )
    ..registerLazySingleton<AlarmSoundRepository>(
      () => SharedPrefsAlarmSoundRepository(getIt<SharedPreferences>()),
    );
}

/// The alarm debug cubit.
void registerAlarmDebug(GetIt getIt, {required LocalStore? localStore}) {
  getIt.registerFactory<AlarmDebugCubit>(
    () => AlarmDebugCubit(
      readNative: getIt<AlarmHost>().debugSnapshot,
      readEnvironment: () => _readAlarmDebugEnvironment(getIt),
      readDartAckQueue: getIt<AckQueue>().entries,
      readPushEvents: getIt<PushEventDrain>().recent,
      readLaunchCalls: () {
        final calls = getIt<LaunchCallLog>();
        return [
          ...calls.recentFailures(),
          for (final entry in calls.lastSuccessByName.entries)
            DebugLaunchCall(name: entry.key, at: entry.value),
        ];
      },
      readStoreStats: () async =>
          localStore == null ? DebugStoreStats.empty : localStore.stats(),
      flushNow: getIt<AckQueue>().flushNow,
      cancelAllRearms: getIt<AlarmHost>().cancelAllRearms,
      clearContentCache: getIt<AlarmHost>().clearContentCache,
      clearAckedSet: getIt<AlarmHost>().clearAckedSet,
      reconcileNow: getIt<IncidentAlarmController>().reconcile,
      recordDebugAction: getIt<PushEventDrain>().recordDebugAction,
    ),
  );
}

/// The settings and sound usecases.
void registerSettingsUsecases(GetIt getIt) {
  getIt
    ..registerLazySingleton(
      () => GetAppearanceSettingsUsecase(
        getIt<AppearanceSettingsRepository>(),
      ),
    )
    ..registerLazySingleton(
      () => SetReduceMotionUsecase(getIt<AppearanceSettingsRepository>()),
    )
    ..registerLazySingleton(
      () => SetHapticsEnabledUsecase(getIt<AppearanceSettingsRepository>()),
    )
    ..registerLazySingleton(
      () => GetPrivacySettingsUsecase(getIt<PrivacyRepository>()),
    )
    ..registerLazySingleton(
      () => SetAnalyticsEnabledUsecase(getIt<PrivacyRepository>()),
    )
    ..registerLazySingleton(
      () => SetCrashReportingEnabledUsecase(getIt<PrivacyRepository>()),
    )
    ..registerLazySingleton(
      () => GetThemeModeUsecase(getIt<ThemePreferenceRepository>()),
    )
    ..registerLazySingleton(
      () => SetThemeModeUsecase(getIt<ThemePreferenceRepository>()),
    )
    ..registerLazySingleton(
      () => ImportSoundUsecase(
        getIt<AlarmSoundRepository>(),
        getIt<SoundHost>(),
        isLocked: () async => ownSoundsLockedBy(
          await ownSoundsOnceReady(getIt<FeatureAccess>()),
        ),
      ),
    )
    ..registerLazySingleton(
      () => DeleteUserSoundUsecase(
        getIt<AlarmSoundRepository>(),
        getIt<SoundHost>(),
      ),
    );
}

/// The theme and appearance cubits.
void registerAppearanceCubits(GetIt getIt) {
  getIt
    ..registerFactory(
      () => ThemeCubit(
        getIt<GetThemeModeUsecase>(),
        getIt<SetThemeModeUsecase>(),
      ),
    )
    ..registerFactory(
      () => AppearanceCubit(
        getIt<GetAppearanceSettingsUsecase>(),
        getIt<SetReduceMotionUsecase>(),
        getIt<SetHapticsEnabledUsecase>(),
      ),
    );
}

/// The settings cubit.
void registerSettingsCubit(GetIt getIt) {
  getIt.registerFactory(
    () => SettingsCubit(
      holdings: getIt<Holdings>(),
      identityStore: getIt<DeviceIdentityStore>(),
      apiSessions: getIt<ApiSessionStore>(),
      getServerInfo: getIt<GetServerInfoUsecase>(),
      establishSession: getIt<EstablishApiSessionUsecase>(),
      connectToServer: getIt<ConnectToServerUsecase>(),
      getTopics: getIt<GetTopicsUsecase>(),
      getConnectionUsecase: getIt<GetConnectionUsecase>(),
      clearConnectionUsecase: getIt<ClearConnectionUsecase>(),
      saveConnectionUsecase: getIt<SaveConnectionUsecase>(),
      getPrivacySettingsUsecase: getIt<GetPrivacySettingsUsecase>(),
      setAnalyticsEnabledUsecase: getIt<SetAnalyticsEnabledUsecase>(),
      setCrashReportingEnabledUsecase: getIt<SetCrashReportingEnabledUsecase>(),
      telemetryGate: getIt.isRegistered<TelemetryGate>()
          ? getIt<TelemetryGate>()
          : null,
      quietHoursStore: getIt<QuietHoursStore>(),
      storageSettings: getIt<StorageSettingsRepository>(),
      // Turning auto-delete on should not wait for the next launch.
      onAutoDeleteChanged: () async =>
          unawaited(getIt<AutoDeleteHistoryUsecase>()()),
      // Fire and forget: a slow or failed re-plan never blocks or fails
      // saving or dropping the server connection.
      onConnectionChanged: () async =>
          unawaited(getIt<LocalReminderPlanTrigger>().run()),
    ),
  );
}

/// The sound crop, recorder, picker, personalize and priorities cubits.
void registerSoundCubits(GetIt getIt) {
  getIt
    ..registerFactory(
      () => SoundCropCubit(
        getIt<SoundHost>(),
        getIt<ImportSoundUsecase>(),
        getIt<SoundFilePicker>(),
      ),
    )
    // One microphone per recorder screen. The cubit disposes it on close.
    ..registerFactory<SoundRecorder>(RecordSoundRecorder.new)
    ..registerFactory(
      () => RecorderCubit(
        getIt<SoundRecorder>(),
        maxDuration: SoundImportLimits.maxClipDuration(defaultTargetPlatform),
        isRinging: getIt<AlarmHost>().isRinging,
        stopPreview: () => getIt<SoundHost>().stopPreview(),
      ),
    )
    ..registerFactory(
      () => SoundPickerCubit(
        getIt<AlarmSoundRepository>(),
        getIt<SoundHost>(),
        getIt<DeleteUserSoundUsecase>(),
        getIt<SoundFilePicker>(),
        getIt<SoundPeaksCache>(),
        nameOf: (id) => 'sound_library.names.$id'.tr(),
        packs: getIt<SoundPackRepository>(),
        readOwnSounds: () =>
            getIt<FeatureAccess>().decide(AppFeature.ownSounds),
        // The first answer waits for the plan to be read, so someone who
        // holds Pro never sees a lock or a paywall at a cold start.
        readOwnSoundsOnceReady: () =>
            ownSoundsOnceReady(getIt<FeatureAccess>()),
        ownSoundsChanges: getIt<FeatureAccess>().changes.where(
          (feature) => feature == AppFeature.ownSounds,
        ),
      ),
    )
    ..registerFactory(
      () => PersonalizeCubit(
        getIt<AlarmSoundRepository>(),
        getIt<SoundHost>(),
        nameOf: (id) => 'sound_library.names.$id'.tr(),
        packs: getIt<SoundPackRepository>(),
      ),
    )
    ..registerFactory(
      () => PrioritiesCubit(
        getIt<AlarmHost>(),
        getIt<SoundHost>(),
        getIt<AlarmSoundRepository>(),
        packs: getIt<SoundPackRepository>(),
        platform: getIt<PlatformCapabilities>().platform,
        isWeb: getIt<PlatformCapabilities>().isWeb,
        nameOf: (id) => 'sound_library.names.$id'.tr(),
        ownSoundsLocked: () => ownSoundsLockedBy(
          getIt<FeatureAccess>().decide(AppFeature.ownSounds),
        ),
      ),
    );
}

Future<DebugEnvironment> _readAlarmDebugEnvironment(GetIt getIt) async {
  final session = await getIt<ApiSessionStore>().read();
  final prefs = getIt<SharedPreferences>();
  final quietHours = getIt<QuietHoursStore>().read();
  int? historyDays;
  final caps = prefs.getString('account_caps');
  if (caps != null) {
    try {
      final decoded = jsonDecode(caps);
      if (decoded is Map && decoded['history_days'] is int) {
        historyDays = decoded['history_days'] as int;
      }
    } on FormatException {
      // A malformed optional account cache should not fail the whole report.
    }
  }
  // The report shows the quiet hours the way the phone shows a time.
  final is24Hour = PlatformDispatcher.instance.alwaysUse24HourFormat;
  String clockText(int minutes) =>
      formatMinuteOfDay(minutes, is24Hour: is24Hour);
  return DebugEnvironment(
    serverMode: session?.mode.wireValue,
    baseUrl: session?.baseUri.toString(),
    tier: prefs.getString('account_tier'),
    historyDays: historyDays,
    quietHoursEnabled: quietHours.isEnabled,
    quietHoursHolding: quietHours.holdsRing(
      now: DateTime.now(),
      priority: 5,
    ),
    quietHoursStart: clockText(quietHours.startMinutes),
    quietHoursEnd: clockText(quietHours.endMinutes),
  );
}
