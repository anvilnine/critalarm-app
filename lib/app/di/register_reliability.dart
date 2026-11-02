import 'dart:async';
import 'package:critalarm/app/di/di_reads.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/ack/ack_queue.dart';
import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/alarm/incident_alarm_controller.dart';
import 'package:critalarm/core/api/api_build_mode.dart';
import 'package:critalarm/core/device/device_maker.dart';
import 'package:critalarm/core/device/os_version_reader.dart';
import 'package:critalarm/core/device/platform_os_version_reader.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/push/last_push_reader.dart';
import 'package:critalarm/core/push/push_host.dart';
import 'package:critalarm/core/push/relay_confirmation_store.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/in_app_notices/domain/repositories/in_app_notice_repository.dart';
import 'package:critalarm/features/in_app_notices/domain/setup_gate.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_store.dart';
import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/setup_test_ring.dart';
import 'package:critalarm/features/onboarding/domain/usecases/check_notification_permission_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/device_token_registry.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_onboarding_completed_usecase.dart';
import 'package:critalarm/features/permissions/domain/repositories/device_permissions_repository.dart';
import 'package:critalarm/features/permissions/domain/usecases/open_permission_settings_usecase.dart';
import 'package:critalarm/features/reliability/data/platform_maker_settings_opener.dart';
import 'package:critalarm/features/reliability/data/platform_phone_capture.dart';
import 'package:critalarm/features/reliability/data/platform_scheduled_summary_reader.dart';
import 'package:critalarm/features/reliability/data/shared_prefs_maker_guide_store.dart';
import 'package:critalarm/features/reliability/data/shared_prefs_missed_alarm_store.dart';
import 'package:critalarm/features/reliability/data/shared_prefs_os_version_store.dart';
import 'package:critalarm/features/reliability/data/shared_prefs_proof_log_store.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_guide.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_guide_store.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_settings_opener.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_reader.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_store.dart';
import 'package:critalarm/features/reliability/domain/os_version_store.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_log.dart';
import 'package:critalarm/features/reliability/domain/reliability_fix_runner.dart';
import 'package:critalarm/features/reliability/domain/scheduled_summary_reader.dart';
import 'package:critalarm/features/reliability/domain/sources/last_push_source.dart';
import 'package:critalarm/features/reliability/domain/sources/missed_alarm_source.dart';
import 'package:critalarm/features/reliability/domain/sources/permissions_source.dart';
import 'package:critalarm/features/reliability/domain/sources/phone_maker_source.dart';
import 'package:critalarm/features/reliability/domain/sources/push_token_source.dart';
import 'package:critalarm/features/reliability/domain/sources/system_update_source.dart';
import 'package:critalarm/features/reliability/domain/sources/time_sensitive_source.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_cubit.dart';
import 'package:critalarm/features/reliability/presentation/maker/maker_guide_cubit.dart';
import 'package:critalarm/features/topics/data/reader_missed_alarm_feed.dart';
import 'package:critalarm/features/topics/domain/missed_alarm_feed.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_monitor.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_source.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The phone's own record of the weeks an alarm or a check got through.
void registerProofLog(GetIt getIt) {
  // The phone's own record of the weeks an alarm or a check got through.
  // Three writers observe into it, and the account's data list drops it.
  getIt.registerLazySingleton(
    () => ProofLog(SharedPrefsProofLogStore(getIt<SharedPreferences>())),
  );
}

/// The readers and stores behind the reliability checks.
void registerReliabilityChecks(GetIt getIt) {
  // Reliability checks. Each source answers for its own checks, and the
  // cubit sums them up. A new source is a class and one line in the list
  // below. Nothing draws them yet.
  getIt
    ..registerLazySingleton(
      () => RelayConfirmationStore(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton(() => LastPushStore(getIt<SharedPreferences>()))
    ..registerLazySingleton(
      () => LastPushReader(
        getIt<SharedPreferences>(),
        getIt<LastPushStore>(),
        // On iOS the extension writes its rows to the App Group, and they
        // only reach Dart's list on the next launch. The alarm channel reads
        // the group directly.
        nativeRows: getIt<PlatformCapabilities>().isIos
            ? () async {
                final snapshot = await getIt<AlarmHost>().debugSnapshot();
                final rows = snapshot['push_events'];
                return rows is List ? rows : const [];
              }
            : null,
      ),
    )
    ..registerLazySingleton<OsVersionReader>(
      () => PlatformOsVersionReader(
        DeviceInfoPlugin(),
        platform: defaultTargetPlatform,
        isWeb: kIsWeb,
      ),
    )
    ..registerLazySingleton<OsVersionStore>(
      () => SharedPrefsOsVersionStore(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton<ScheduledSummaryReader>(
      PlatformScheduledSummaryReader.new,
    )
    ..registerLazySingleton(
      () => SystemUpdateSource(
        os: getIt<OsVersionReader>(),
        store: getIt<OsVersionStore>(),
        // The newest test the server accepted, on any topic.
        lastTestAt: () async {
          final store = getIt<LocalReminderStore>();
          await store.reload();
          DateTime? newest;
          for (final at in store.readLastTestAt().values) {
            if (newest == null || at.isAfter(newest)) newest = at;
          }
          return newest;
        },
        testRouteName: AppRoute.testRing,
      ),
    )
    ..registerLazySingleton<MakerGuideStore>(
      () => SharedPrefsMakerGuideStore(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton<MakerSettingsOpener>(
      PlatformMakerSettingsOpener.new,
    )
    ..registerFactory(
      () => MakerGuideCubit(
        makerReader: getIt<DeviceMakerReader>(),
        os: getIt<OsVersionReader>(),
        store: getIt<MakerGuideStore>(),
        opener: getIt<MakerSettingsOpener>(),
      ),
    );
}

/// The missed alarm check and its Home entry.
void registerMissedAlarm(GetIt getIt) {
  // The missed alarm check. It reads what the phone and the shared lists
  // already hold: no call to the server, no alert, nothing on the alarm
  // path changed.
  getIt
    ..registerLazySingleton<MissedAlarmStore>(
      () => SharedPrefsMissedAlarmStore(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton(
      () => PlatformPhoneCapture(
        prefs: getIt<SharedPreferences>(),
        readNative: getIt<AlarmHost>().debugSnapshot,
        readAckQueue: getIt<AckQueue>().entries,
        alarmIds: [
          getIt<AlarmHost>().alarmsScheduled,
          getIt<PushHost>().alarmPushes,
        ],
        alarmingIds: () => getIt<IncidentAlarmController>().alarmingIncidentIds,
      ),
    )
    ..registerLazySingleton(
      () => MissedAlarmReader(
        store: getIt<MissedAlarmStore>(),
        readIncidents: () => getIt<IncidentsCubit>().state.incidents,
        // What the shared list already holds. Never a fetch.
        readTopicNames: () async {
          final topics = getIt<TopicsCubit>().state;
          return topics.isReady
              ? {for (final topic in topics.topics) topic.name}
              : null;
        },
        capture: getIt<PlatformPhoneCapture>().take,
        isSetupDone: () async =>
            (await getIt<GetOnboardingCompletedUsecase>()(
              const NoParams(),
            )).getOrNull() ??
            false,
        readServer: () async {
          final conn = (await getIt<GetConnectionUsecase>()(
            const NoParams(),
          )).getOrNull();
          final url = conn?.serverUrl.trim() ?? '';
          return url.isEmpty ? null : url;
        },
        firstLaunchAt: getIt<InAppNoticeRepository>().getFirstSeenAt,
        setupIncidentIds: () => getIt<SetupTestRing>().setupIncidentIds,
        // Android writes a row for every push it is handed (`PushRouter`).
        // An iPhone only writes one when the notification extension runs,
        // so there a stretch with no row proves nothing.
        everyPushIsLogged:
            !getIt<PlatformCapabilities>().isWeb &&
            getIt<PlatformCapabilities>().platform == TargetPlatform.android,
      ),
    )
    // The missed alarm entry for Home's card. It reads the reader and the
    // record of closed entries the notice reads, so closing it from either
    // place closes it in both.
    ..registerLazySingleton<MissedAlarmFeed>(
      () => ReaderMissedAlarmFeed(
        readMissed: getIt<MissedAlarmReader>().read,
        readDismissed: () =>
            getIt<MissedAlarmStore>().readDismissed().keys.toSet(),
        writeDismissed: getIt<MissedAlarmReader>().dismiss,
        readIncidents: () => getIt<IncidentsCubit>().state.incidents,
        isSetupDone: () => getIt<SetupGate>().isDone(),
        // Asked again when an incident runs out, and only then: the list
        // changes far more often than that.
        incidentChanges: _expiredIncidentChanges(getIt<IncidentsCubit>()),
      ),
    );
}

/// The fix runner and the cubit that sums the checks up.
void registerReliabilityCubit(GetIt getIt) {
  getIt
    ..registerLazySingleton(
      () => ReliabilityFixRunner(
        openSystemSettings: (permission) async {
          await getIt<OpenPermissionSettingsUsecase>()(permission);
        },
        reRegisterPushToken: getIt<DeviceTokenRegistry>().confirmNow,
      ),
    )
    ..registerLazySingleton(
      () => ReliabilityCubit([
        PermissionsSource(
          permissions: getIt<DevicePermissionsRepository>(),
          capabilities: getIt<PlatformCapabilities>(),
          os: getIt<OsVersionReader>(),
          // The phone does not tell "never asked" from "said no" for
          // notifications. The same answer the permissions screen uses.
          notificationsNeverAsked: () async =>
              (await getIt<CheckNotificationPermissionUsecase>()(
                const NoParams(),
              )).getOrNull() ==
              NotificationPermissionStatus.notDetermined,
        ),
        PushTokenSource(
          store: getIt<RelayConfirmationStore>(),
          currentScope: getIt<DeviceTokenRegistry>().currentScope,
          // The registry is not started on the mock server, and a phone with
          // no server has nobody to register with.
          isRelayExpected: () async =>
              !buildUsesMockApi &&
              getIt<PlatformCapabilities>().canRegisterPush &&
              await getIt<ApiSessionStore>().read() != null,
        ),
        LastPushSource(
          reader: getIt<LastPushReader>(),
          capabilities: getIt<PlatformCapabilities>(),
          hasCriticalTopic: () async =>
              (await getIt<GetTopicsUsecase>()(
                const NoParams(),
              )).getOrNull()?.any((topic) => topic.critical) ??
              false,
          testRouteName: AppRoute.testRing,
        ),
        TimeSensitiveSource(
          capabilities: getIt<PlatformCapabilities>(),
          os: getIt<OsVersionReader>(),
          permissions: getIt<DevicePermissionsRepository>(),
          summary: getIt<ScheduledSummaryReader>(),
        ),
        getIt<SystemUpdateSource>(),
        PhoneMakerSource(
          capabilities: getIt<PlatformCapabilities>(),
          makerReader: getIt<DeviceMakerReader>(),
          os: getIt<OsVersionReader>(),
          store: getIt<MakerGuideStore>(),
          guideRouteName: makerGuideRouteName,
        ),
        MissedAlarmSource(
          readMissed: getIt<MissedAlarmReader>().read,
          readDismissedIds: () =>
              getIt<MissedAlarmStore>().readDismissed().keys.toSet(),
          testRouteName: AppRoute.testRing,
        ),
        // The weekly check counts while it is switched on, as "needs a
        // look" at most. It reads what the monitor already holds and never
        // calls the relay: the row's own cubit does that.
        WeeklyCheckSource(
          readCheck: () => getIt<WeeklyCheckMonitor>().check,
          readAccess: weeklyCheckAccessReader(getIt),
          readMissedByClock: () =>
              getIt<WeeklyCheckMonitor>().twoRoundsMissed(),
          testRouteName: AppRoute.testRing,
        ),
      ]),
    );
}

/// Fires when the set of expired incidents in the shared list changes, and
/// at no other time: the list itself changes far more often than that.
Stream<void> _expiredIncidentChanges(IncidentsCubit incidents) {
  String keyOf(IncidentsState state) => [
    for (final incident in state.incidents)
      if (incident.isExpired) incident.id,
  ].join(',');
  var last = keyOf(incidents.state);
  return incidents.stream.map(keyOf).where((key) {
    if (key == last) return false;
    last = key;
    return true;
  });
}
