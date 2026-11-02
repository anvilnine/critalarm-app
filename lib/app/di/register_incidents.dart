import 'dart:async';
import 'dart:ui';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/alarm/alarm_signal_store.dart';
import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/backup/backup_host.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/features/incidents/data/own_look/file_own_look_store.dart';
import 'package:critalarm/features/incidents/data/own_look/platform_own_photo_picker.dart';
import 'package:critalarm/features/incidents/data/own_look/ui_own_photo_codec.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/data/shared_prefs_alarm_style_choices.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_choices.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_gate.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_look_store.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_photo_import.dart';
import 'package:critalarm/features/incidents/domain/repositories/held_archive.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/acknowledge_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/close_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/trigger_test_alarm_usecase.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/own_alarm_look_keeper.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_cubit.dart';
import 'package:critalarm/features/incidents/presentation/cubits/lock_screen_cubit.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_plan_trigger.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_store.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_engine.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/setup_test_ring.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use_store.dart';
import 'package:critalarm/features/onboarding/domain/usecases/end_setup_test_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_onboarding_completed_usecase.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_log.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The incident repository and the archive it also is.
void registerIncidentRepository(
  GetIt getIt, {
  required LocalStore? localStore,
}) {
  getIt
    ..registerLazySingleton<IncidentRepository>(
      () => InMemoryIncidentRepository(getIt<ApiClient>(), store: localStore),
    )
    // The phone's own alarms and messages, read with no request. The same
    // store the repository above reads and writes.
    ..registerLazySingleton<HeldArchive>(() {
      final repository = getIt<IncidentRepository>();
      if (repository is HeldArchive) return repository as HeldArchive;
      return InMemoryIncidentRepository(getIt<ApiClient>(), store: localStore);
    });
}

/// The test alarm and the incident reads.
void registerIncidentUsecases(GetIt getIt) {
  getIt
    ..registerLazySingleton(
      () => TriggerTestAlarmUsecase(
        getIt<IncidentRepository>(),
        localReminderStore: getIt<LocalReminderStore>(),
        // Fire and forget: a slow or failed re-plan never blocks or fails
        // the test ring.
        onTested: (_) => unawaited(getIt<LocalReminderPlanTrigger>().run()),
      ),
    )
    ..registerLazySingleton(
      () => GetIncidentsUsecase(getIt<IncidentRepository>()),
    )
    ..registerLazySingleton(
      () => GetIncidentUsecase(getIt<IncidentRepository>()),
    );
}

/// The alarm screen looks: choices, gate, own photo and its keeper.
void registerAlarmStyle(GetIt getIt) {
  // Alarm screen looks: the phone's choice and each topic's, kept on this
  // phone only, and the gate the alarm screen asks which one to draw. A
  // look changes how the in-app alarm screen is drawn and nothing else.
  getIt
    ..registerLazySingleton<AlarmStyleChoices>(
      () => SharedPrefsAlarmStyleChoices(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton(
      () => AlarmStyleGate(
        choices: getIt<AlarmStyleChoices>(),
        decide: () =>
            getIt<FeatureAccess>().decide(AppFeature.alarmScreenStyles),
        decideOnceReady: () => getIt<FeatureAccess>().decideOnceReady(
          AppFeature.alarmScreenStyles,
        ),
        // The note of the last sure answer belongs to one account.
        readAccountId: () async =>
            (await getIt<DeviceIdentityStore>().readOrCreate()).accountId,
        planRead: getIt<FeatureAccess>().ready,
        changes: [
          getIt<FeatureAccess>().changes.where(
            (feature) => feature == AppFeature.alarmScreenStyles,
          ),
        ],
        // A field read: the alarm screen asks this while it rings.
        isOwnLookReady: () => getIt<OwnAlarmLookKeeper>().isReady,
      ),
    )
    // The person's own alarm look: one photo in the app's own storage,
    // its record and its accent in the preferences. The keeper decodes
    // the photo at launch and holds it, so an alarm that rings loads
    // nothing. The photo is sent nowhere and is in no backup: the store
    // keeps its folder out on an iPhone, and Android backs up nothing.
    ..registerLazySingleton<OwnLookStore>(
      () => FileOwnLookStore(
        getIt<SharedPreferences>(),
        getApplicationSupportDirectory,
        excludeFromBackup: getIt<BackupHost>().excludeFromBackup,
      ),
    )
    ..registerLazySingleton(
      () => OwnAlarmLookKeeper(
        getIt<OwnLookStore>(),
        // The picture is in memory only while a paid look may ring. With
        // looks locked it is let go, and decoded again when that changes.
        mayHold: () => getIt<AlarmStyleGate>().drawsPaidLooks,
        recheck: [
          getIt<AlarmStyleGate>().checked,
          getIt<FeatureAccess>().changes.where(
            (feature) => feature == AppFeature.alarmScreenStyles,
          ),
        ],
      ),
    )
    ..registerLazySingleton<OwnPhotoPicker>(PlatformOwnPhotoPicker.new)
    ..registerLazySingleton(
      () => ImportOwnPhotoUsecase(
        const UiOwnPhotoCodec(),
        getIt<OwnLookStore>(),
        // The last check that looks are open, as the sound import has for
        // own sounds. Only a sure lock turns a photo away.
        isLocked: () async => !await getIt<FeatureAccess>().canOnceReady(
          AppFeature.alarmScreenStyles,
        ),
      ),
    );
}

/// Acknowledging and closing an incident.
void registerIncidentCloseUsecases(GetIt getIt) {
  getIt
    ..registerLazySingleton(
      () => AcknowledgeIncidentUsecase(getIt<IncidentRepository>()),
    )
    ..registerLazySingleton(
      () => CloseIncidentUsecase(getIt<IncidentRepository>()),
    );
}

/// The alarm screen and lock screen cubits.
void registerAlarmScreens(GetIt getIt) {
  getIt
    ..registerFactory(
      () => CriticalAlarmCubit(
        getIt<GetIncidentUsecase>(),
        getIt<GetIncidentsUsecase>(),
        getIt<AcknowledgeIncidentUsecase>(),
        getIt<CloseIncidentUsecase>(),
        getIt<IncidentsCubit>(),
        getIt<AlarmHost>(),
        // The two defaults, spelled out so the onboarding flag after them can
        // be passed at all. Only a test overrides either.
        const Duration(seconds: 1),
        null,
        getIt<GetOnboardingCompletedUsecase>(),
        () => getIt<OnboardingFlowEngine>().isStepSatisfied(
          OnboardingStepId.firstTopic,
        ),
        () => getIt<SetupTestRing>().incidentIds,
        () => getIt<OnboardingFlowEngine>().runningFlow().contains(
          OnboardingStepId.realRing,
        ),
        getIt<EndSetupTestUsecase>(),
        getIt<SetupTestRing>(),
        getIt<ProofLog>(),
        // Setup never rings a real alarm in a replay, so the saved answer is
        // the one the test alarm was sent for.
        getIt<SetupUseStore>().read,
        // Only the iPhone flashes from the alarm screen. Android flashes
        // from its alarm service, with or without the screen.
        getIt<PlatformCapabilities>().flashNeedsAlarmScreen
            ? getIt<AlarmSignalStore>().read
            : null,
        // The times on the alarm follow the phone's 12 or 24 hour setting.
        () => PlatformDispatcher.instance.alwaysUse24HourFormat,
      ),
    )
    ..registerFactory(
      () => LockScreenCubit(
        getIt<GetIncidentsUsecase>(),
        alarm: getIt<AlarmHost>(),
      ),
    );
}
