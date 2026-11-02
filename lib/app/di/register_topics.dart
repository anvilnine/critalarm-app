import 'dart:async';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/app/state/held_rows.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/alarm/alarm_signal_store.dart';
import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/sync/message_sync_service.dart';
import 'package:critalarm/features/challenges/domain/challenge_choices.dart';
import 'package:critalarm/features/feature_guides/presentation/cubits/feature_guide_cubit.dart';
import 'package:critalarm/features/in_app_notices/domain/repositories/in_app_notice_repository.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_plan_trigger.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_store.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/setup_test_ring.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use_store.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_cubit.dart';
import 'package:critalarm/features/topics/data/api_first_message_source.dart';
import 'package:critalarm/features/topics/data/prefs_setup_checklist_store.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/data/repositories/shared_prefs_topic_list_prefs_repository.dart';
import 'package:critalarm/features/topics/domain/first_message/first_message_store.dart';
import 'package:critalarm/features/topics/domain/first_message/first_message_watcher.dart';
import 'package:critalarm/features/topics/domain/first_topic_handoff.dart';
import 'package:critalarm/features/topics/domain/home_card/first_message_expected.dart';
import 'package:critalarm/features/topics/domain/missed_alarm_feed.dart';
import 'package:critalarm/features/topics/domain/repositories/tool_template_store.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_list_prefs_repository.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';
import 'package:critalarm/features/topics/domain/setup_checklist.dart';
import 'package:critalarm/features/topics/domain/setup_checklist_store.dart';
import 'package:critalarm/features/topics/domain/usecases/create_topic_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/delete_topic_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/topic_token_usecases.dart';
import 'package:critalarm/features/topics/domain/usecases/update_topic_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/held_topics.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_card_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_setup_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_glances.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_message_rows.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_tokens_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Home topic list view choices.
void registerTopicListPrefs(GetIt getIt) {
  getIt.registerLazySingleton<TopicListPrefsRepository>(
    () => SharedPrefsTopicListPrefsRepository(getIt<SharedPreferences>()),
  );
}

/// The topic repository.
void registerTopicRepository(GetIt getIt) {
  getIt.registerLazySingleton<TopicRepository>(
    () => InMemoryTopicRepository(
      getIt<ApiClient>(),
      sessions: getIt<ApiSessionStore>(),
      identity: getIt<DeviceIdentityStore>(),
      prefs: getIt<SharedPreferences>(),
    ),
  );
}

/// The topic usecases and the token cubit.
void registerTopicUsecases(GetIt getIt) {
  getIt
    ..registerLazySingleton(
      () => GetTopicsUsecase(getIt<TopicRepository>()),
    )
    ..registerLazySingleton(
      () => CreateTopicUsecase(
        getIt<TopicRepository>(),
        // Recording the topic is awaited (it is a plain preference write);
        // the plan pass is fire and forget, so a slow or failed re-plan
        // never blocks or fails topic creation.
        onCreated: (topic) async {
          await getIt<LocalReminderStore>().recordTopicCreatedHere(
            topic.name,
            DateTime.now(),
          );
          // Starts the one-day wait before the backup notice. A no-op after
          // the first topic.
          await getIt<InAppNoticeRepository>().markFirstTopicOwned();
          unawaited(getIt<LocalReminderPlanTrigger>().run());
          // The phone's copy of the list gains it before the next answer.
          getIt<TopicsCubit>().noteCreated(topic);
        },
      ),
    )
    ..registerLazySingleton(
      () => UpdateTopicUsecase(getIt<TopicRepository>()),
    )
    ..registerLazySingleton(
      () => DeleteTopicUsecase(
        getIt<TopicRepository>(),
        getIt<FirstMessageStore>(),
      ),
    )
    ..registerLazySingleton(
      () => GetTopicTokensUsecase(getIt<TopicRepository>()),
    )
    ..registerLazySingleton(
      () => CreateTopicTokenUsecase(getIt<TopicRepository>()),
    )
    ..registerLazySingleton(
      () => RevokeTopicTokenUsecase(getIt<TopicRepository>()),
    )
    ..registerLazySingleton(
      () => RenameTopicTokenUsecase(getIt<TopicRepository>()),
    )
    ..registerFactory(
      () => TopicTokensCubit(
        getIt<GetTopicTokensUsecase>(),
        getIt<CreateTopicTokenUsecase>(),
        getIt<RevokeTopicTokenUsecase>(),
        getIt<RenameTopicTokenUsecase>(),
      ),
    );
}

/// The Home cubits and the setup checklist.
void registerHome(GetIt getIt) {
  getIt
    ..registerFactory(
      () => HomeCubit(
        getIt<IncidentsCubit>(),
        getIt<TopicsCubit>(),
        getIt<IncidentRepository>(),
        getIt<MessageSyncService>(),
        getIt<GetConnectionUsecase>(),
        null,
        const Duration(seconds: 5),
        getIt<TopicListPrefsRepository>(),
        getIt<TopicGlances>(),
        TopicMessageWindow(
          identityStore: getIt<DeviceIdentityStore>(),
          featureAccess: getIt<FeatureAccess>(),
        ),
        getIt<HeldRows>(),
      ),
    )
    // The dark card on Home. It follows the screen's own HomeCubit and
    // HomeSetupCubit, so the screen hands them in:
    // `getIt<HomeCardCubit>(param1: home, param2: setup)`. The checks and the
    // missed alarm entry are shared, so they come from here.
    ..registerFactoryParam<HomeCardCubit, HomeCubit, HomeSetupCubit>(
      (home, setup) => HomeCardCubit(
        home: home,
        reliability: getIt<ReliabilityCubit>(),
        setup: setup,
        missed: getIt<MissedAlarmFeed>(),
        setupUse: getIt<SetupUseStore>(),
        toolTemplates: getIt<ToolTemplateStore>(),
        testRouteName: AppRoute.testRing,
        askPermissionsRouteName: AppRoute.askPermissions,
        // What the phone itself holds, so the waiting card is drawn on the
        // first frame and not after the list loads.
        isSetupOpen: () {
          final prefs = getIt<SharedPreferences>();
          bool isSaved(String key) => (prefs.getString(key) ?? '').isNotEmpty;
          final checklist = getIt<SetupChecklistStore>();
          return firstMessageExpected(
            hasServer:
                isSaved(SharedPrefsConnectionRepository.serverUrlKey) &&
                isSaved(SharedPrefsConnectionRepository.adminTokenKey),
            wasSetUpHere: checklist.wasSetUpHere,
            isChecklistRetired: checklist.isDone,
            isFirstMessageReceived: getIt<FirstMessageStore>().isReceived,
          );
        },
        // The list the app holds: the one setup's last steps loaded, or the
        // copy the phone kept at the last answer after a cold start.
        readHeldTopics: () => heldTopicsFrom(getIt<TopicsCubit>().state),
      ),
    )
    // The setup checklist and the widgets card on Home. Home content: it
    // goes through neither the notice slot nor `SetupGate`.
    ..registerLazySingleton<SetupChecklistStore>(
      () => PrefsSetupChecklistStore(getIt<SharedPreferences>()),
    )
    ..registerFactory(
      () => HomeSetupCubit(
        store: getIt<SetupChecklistStore>(),
        firstMessage: getIt<FirstMessageStore>(),
        source: ApiFirstMessageSource(api: getIt<ApiClient>()),
        // Home can stay open for days, so its watch slows while nothing
        // arrives. The setup step keeps the steady pace of its own.
        newWatcher: () => FirstMessageWatcher(
          store: getIt<FirstMessageStore>(),
          source: ApiFirstMessageSource(api: getIt<ApiClient>()),
          backsOffWhenQuiet: true,
        ),
        readIncidentIds: () => [
          for (final incident in getIt<IncidentsCubit>().state.incidents)
            incident.id,
        ],
        readSetupIncidentIds: () => getIt<SetupTestRing>().setupIncidentIds,
        isGuideOfferAnswered: () =>
            getIt<FeatureGuideCubit>().hasSeenFirstGuide,
        // The same answer the widgets themselves draw their lock from.
        readWidgetsPlan: () async {
          final access = getIt<FeatureAccess>();
          return homeWidgetsPlanFor(
            await access.decideOnceReady(AppFeature.widgets),
            isOwnServer: access.isOwnServer,
          );
        },
        widgetsPlanChanges: getIt<FeatureAccess>().changes.where(
          (feature) => feature == AppFeature.widgets,
        ),
        platform: defaultTargetPlatform,
        isWeb: kIsWeb,
      ),
    );
}

/// The topic glances and the topic and create topic cubits.
void registerTopicScreens(GetIt getIt) {
  // Read by the Topic screen before it has read anything of its own.
  getIt
    ..registerLazySingleton(TopicGlances.new)
    ..registerFactory(
      () => TopicDetailCubit(
        getIt<IncidentsCubit>(),
        getIt<TopicsCubit>(),
        getIt<UpdateTopicUsecase>(),
        getIt<IncidentRepository>(),
        alarm: getIt<AlarmHost>(),
        identityStore: getIt<DeviceIdentityStore>(),
        featureAccess: getIt<FeatureAccess>(),
        glances: getIt<TopicGlances>(),
        signalStore: getIt<AlarmSignalStore>(),
        held: getIt<HeldRows>(),
      ),
    )
    ..registerFactory(
      () =>
          CreateTopicCubit(
              getIt<CreateTopicUsecase>(),
              getIt<GetConnectionUsecase>(),
              getIt<DeviceIdentityStore>(),
              getIt<GetTopicsUsecase>(),
              null,
              getIt<FeatureAccess>(),
            )
            ..alarm = getIt<AlarmHost>()
            ..toolTemplates = getIt<ToolTemplateStore>()
            ..applyPhoneDefaults = getIt<ChallengeChoices>().applyDefaultTo
            ..handoff = getIt<FirstTopicHandoff>(),
    );
}
