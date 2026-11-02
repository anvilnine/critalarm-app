import 'package:critalarm/app/di/di_reads.dart';
import 'package:critalarm/core/alarm/quiet_hours_store.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/telemetry/local_reminder_analytics.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/account/domain/repositories/identity_repository.dart';
import 'package:critalarm/features/in_app_notices/domain/pro_ask_rules.dart';
import 'package:critalarm/features/in_app_notices/domain/repositories/in_app_notice_repository.dart';
import 'package:critalarm/features/in_app_notices/domain/setup_gate.dart';
import 'package:critalarm/features/incidents/domain/real_use.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/trigger_test_alarm_usecase.dart';
import 'package:critalarm/features/local_reminders/data/native_local_reminder_scheduler.dart';
import 'package:critalarm/features/local_reminders/data/noop_local_reminder_scheduler.dart';
import 'package:critalarm/features/local_reminders/data/revenuecat_plan_status_source.dart';
import 'package:critalarm/features/local_reminders/data/shared_prefs_local_reminder_store.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_copy.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_inputs_reader.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_plan_pass.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_plan_trigger.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_scheduler.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_server_support.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_settler.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_store.dart';
import 'package:critalarm/features/local_reminders/domain/plan_status_source.dart';
import 'package:critalarm/features/local_reminders/presentation/cubits/confirm_ring_cubit.dart';
import 'package:critalarm/features/local_reminders/presentation/cubits/local_reminder_lab_cubit.dart';
import 'package:critalarm/features/local_reminders/presentation/cubits/local_reminder_settings_cubit.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/setup_test_ring.dart';
import 'package:critalarm/features/paywall/domain/repositories/subscription_repository.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_log.dart';
import 'package:critalarm/features/settings/domain/repositories/privacy_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Local Reminders store, scheduler, inputs reader and plan pass.
void registerLocalReminders(GetIt getIt) {
  getIt
    ..registerLazySingleton<LocalReminderStore>(
      () => SharedPrefsLocalReminderStore(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton(
      () => LocalReminderSettler(
        store: getIt<LocalReminderStore>(),
        notices: getIt<InAppNoticeRepository>(),
      ),
    )
    // Web has no local notifications, so the dashboard gets the no-op.
    ..registerLazySingleton<LocalReminderScheduler>(
      () => kIsWeb
          ? const NoopLocalReminderScheduler()
          : NativeLocalReminderScheduler(),
    )
    ..registerLazySingleton<PlanStatusSource>(
      () => RevenueCatPlanStatusSource(getIt<SubscriptionRepository>()),
    )
    ..registerLazySingleton(
      () => LocalReminderInputsReader(
        store: getIt<LocalReminderStore>(),
        notices: getIt<InAppNoticeRepository>(),
        quietHours: getIt<QuietHoursStore>(),
        scheduler: getIt<LocalReminderScheduler>(),
        planStatus: getIt<PlanStatusSource>(),
        privacy: getIt<PrivacyRepository>(),
        readTopics: () async =>
            (await getIt<GetTopicsUsecase>()(const NoParams())).getOrNull(),
        readIncidents: () async => (await getIt<GetIncidentsUsecase>()(
          const GetIncidentsParams(limit: 50),
        )).getOrNull(),
        // A failed poll counts as "has messages": better to miss a reminder
        // than to nag about a topic that may be working.
        topicHasMessages: (topic) async =>
            (await getIt<IncidentRepository>().pollMessages(
              topic,
              poll: 1,
              since: 'all',
            )).fold((messages) => messages.isNotEmpty, (_) => true),
        readServerMode: () => getIt<AccountRepository>().readServerMode(),
        readHoldsHosted: holdsHostedReader(getIt),
        readIsSignedIn: () async =>
            (await getIt<IdentityRepository>().readIdentity()) != null,
        proShouldAsk: () => getIt<ProAskRules>().shouldAsk(),
        isSetupDone: () => getIt<SetupGate>().isDone(),
        countsAsRealUse: (incidentId) => countsAsRealUse(
          incidentId: incidentId,
          setupIncidentIds: getIt<SetupTestRing>().setupIncidentIds,
        ),
        isWeb: kIsWeb,
        isIos: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
      ),
    )
    ..registerLazySingleton(
      () => LocalReminderPlanPass(
        store: getIt<LocalReminderStore>(),
        scheduler: getIt<LocalReminderScheduler>(),
        settler: getIt<LocalReminderSettler>(),
        readInputs: () => getIt<LocalReminderInputsReader>().read(),
        copy: LocalReminderCopy(
          isIos: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
        ),
        isWeb: getIt<PlatformCapabilities>().isWeb,
        // Nothing is planned during onboarding or a Feature
        // Guide. The app plans again when the guide ends.
        isPaused: () async => !await getIt<SetupGate>().isDone(),
      ),
    )
    // Web plans nothing.
    ..registerLazySingleton<LocalReminderPlanTrigger>(
      () => kIsWeb
          ? const NoopLocalReminderPlanTrigger()
          : getIt<LocalReminderPlanPass>(),
    );
}

/// The Local Reminders cubits.
void registerLocalReminderCubits(GetIt getIt) {
  getIt
    ..registerFactory(
      () => LocalReminderSettingsCubit(
        store: getIt<LocalReminderStore>(),
        scheduler: getIt<LocalReminderScheduler>(),
        readServerMode: () => getIt<AccountRepository>().readServerMode(),
        readHoldsHosted: () => getIt<AccountRepository>().readHoldsHosted(),
        trigger: getIt<LocalReminderPlanTrigger>(),
        analytics: getIt<LocalReminderAnalytics>(),
      ),
    )
    ..registerFactory(
      () => ConfirmRingCubit(
        readTopics: () async =>
            (await getIt<GetTopicsUsecase>()(const NoParams())).getOrNull(),
        readIncidents: () async => (await getIt<GetIncidentsUsecase>()(
          const GetIncidentsParams(limit: 50),
        )).getOrNull(),
        triggerTest: getIt<TriggerTestAlarmUsecase>().call,
        store: getIt<LocalReminderStore>(),
        canTestNormalTopics: LocalReminderServerSupport.testsNormalTopics,
        analytics: getIt<LocalReminderAnalytics>(),
        proofLog: getIt<ProofLog>(),
      ),
    )
    ..registerFactory(
      () => LocalReminderLabCubit(
        store: getIt<LocalReminderStore>(),
        notices: getIt<InAppNoticeRepository>(),
        scheduler: getIt<LocalReminderScheduler>(),
        copy: LocalReminderCopy(
          isIos: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
        ),
        trigger: getIt<LocalReminderPlanTrigger>(),
        readServerMode: () => getIt<AccountRepository>().readServerMode(),
      ),
    );
}
