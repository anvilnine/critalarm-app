import 'dart:async';
import 'package:critalarm/app/account_data.dart';
import 'package:critalarm/app/di/di_reads.dart';
import 'package:critalarm/app/initial_route_resolver.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/alarm/incident_alarm_controller.dart';
import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/stale_account_exception.dart';
import 'package:critalarm/core/device/device_build_mode.dart';
import 'package:critalarm/core/device/device_maker.dart';
import 'package:critalarm/core/device/platform_device_maker_reader.dart';
import 'package:critalarm/core/models/account_access.dart';
import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:critalarm/core/push/push_host.dart';
import 'package:critalarm/core/push/push_token_provider.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/storage/nse_credential_store.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/core/store/services/store_billing.dart';
import 'package:critalarm/core/telemetry/onboarding_funnel.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/core/widgets/widget_host.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/in_app_notices/domain/repositories/in_app_notice_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/acknowledge_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/close_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/trigger_test_alarm_usecase.dart';
import 'package:critalarm/features/local_reminders/domain/incident_kinds.dart';
import 'package:critalarm/features/onboarding/data/repositories/in_memory_server_repository.dart';
import 'package:critalarm/features/onboarding/data/repositories/keychain_mirror_connection_repository.dart';
import 'package:critalarm/features/onboarding/data/repositories/observed_connection_repository.dart';
import 'package:critalarm/features/onboarding/data/repositories/platform_alarm_arrivals.dart';
import 'package:critalarm/features/onboarding/data/repositories/prefs_setup_test_ring.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_connection_repository.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_developer_onboarding_overrides.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_onboarding_flow_repository.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_onboarding_progress_repository.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_setup_use_store.dart';
import 'package:critalarm/features/onboarding/domain/connect/background_connect.dart';
import 'package:critalarm/features/onboarding/domain/connect/connect_intent_store.dart';
import 'package:critalarm/features/onboarding/domain/flow/developer_onboarding.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_engine.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_source.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_funnel_hook.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_step_catalog.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_step_facts.dart';
import 'package:critalarm/features/onboarding/domain/flow/remote_onboarding_flow_source.dart';
import 'package:critalarm/features/onboarding/domain/offer/onboarding_offer_rule.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/alarm_arrivals.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/setup_test_ring.dart';
import 'package:critalarm/features/onboarding/domain/repositories/connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/repositories/onboarding_flow_repository.dart';
import 'package:critalarm/features/onboarding/domain/repositories/onboarding_progress_repository.dart';
import 'package:critalarm/features/onboarding/domain/repositories/server_repository.dart';
import 'package:critalarm/features/onboarding/domain/setup_stats_consent.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use_store.dart';
import 'package:critalarm/features/onboarding/domain/usecases/check_notification_permission_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/clear_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/complete_onboarding_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/connect_to_server_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/end_setup_test_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/establish_api_session_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_onboarding_completed_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/onboarding_draft_usecases.dart';
import 'package:critalarm/features/onboarding/domain/usecases/open_notification_settings_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/read_permission_setup_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/request_notification_permission_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/save_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/set_up_later_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/hook_up_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_state.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_connect_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_welcome_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/real_ring_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/flow/onboarding_step_registry.dart';
import 'package:critalarm/features/onboarding/presentation/model/offer_sale_probe.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_registry.dart';
import 'package:critalarm/features/permissions/domain/repositories/device_permissions_repository.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_access.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_reader.dart';
import 'package:critalarm/features/settings/domain/repositories/privacy_repository.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:critalarm/features/topics/data/api_first_message_source.dart';
import 'package:critalarm/features/topics/data/prefs_first_message_store.dart';
import 'package:critalarm/features/topics/data/prefs_first_topic_handoff.dart';
import 'package:critalarm/features/topics/data/shared_prefs_tool_template_store.dart';
import 'package:critalarm/features/topics/domain/first_message/first_message_store.dart';
import 'package:critalarm/features/topics/domain/first_message/first_message_watcher.dart';
import 'package:critalarm/features/topics/domain/first_topic_handoff.dart';
import 'package:critalarm/features/topics/domain/repositories/tool_template_store.dart';
import 'package:critalarm/features/topics/domain/setup_checklist_store.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/topic_token_usecases.dart';
import 'package:critalarm/features/topics/domain/usecases/update_topic_usecase.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The server, connection and setup progress repositories.
void registerOnboardingRepositories(GetIt getIt) {
  getIt
    ..registerLazySingleton<ServerRepository>(
      () => InMemoryServerRepository(getIt<ApiClient>()),
    )
    // The iOS extension reads the server and the token out of the keychain,
    // so saving a connection has to land there too.
    ..registerLazySingleton<ConnectionRepository>(
      () => ObservedConnectionRepository(
        KeychainMirrorConnectionRepository(
          SharedPrefsConnectionRepository(getIt<SharedPreferences>()),
          getIt<NseCredentialStore>(),
          widgets: getIt<WidgetHost>(),
        ),
        // The missed alarm check counts an incident only from the moment
        // this phone connected to its server, so it hears every save and
        // every removal here, when it happens.
        onSaved: (serverUrl) =>
            getIt<MissedAlarmReader>().connectionSaved(serverUrl),
        onCleared: () => getIt<MissedAlarmReader>().connectionCleared(),
      ),
    )
    ..registerLazySingleton<OnboardingProgressRepository>(
      () => SharedPrefsOnboardingProgressRepository(getIt<SharedPreferences>()),
    );
}

/// Saving a connection, registering the device and opening the API session.
void registerDeviceRegistration(GetIt getIt) {
  getIt
    ..registerLazySingleton(
      () => SaveConnectionUsecase(getIt<ConnectionRepository>()),
    )
    ..registerLazySingleton(
      () => RegisterDeviceUsecase(
        getIt<ApiClient>(),
        getIt<DeviceIdentityStore>(),
        getIt<PushTokenProvider>(),
        identifyAccount: getIt<StoreBilling>().identifyAccount,
        beforePacksRequest: () => getIt<ProPackAccess>().beginRelayRequest(),
        readSessionRelay: () async =>
            (await getIt<ApiSessionStore>().read())?.relayUri,
        readSession: () => getIt<ApiSessionStore>().read(),
        onPacks: (response, {relayUri, request}) =>
            getIt<ProPackAccess>().relayAnswered(
              accountId: response.accountId,
              packs: response.packs,
              tier: response.tier, // access-ok: hands it to the Pro source
              relay: relayUri,
              request: request,
            ),
      ),
    )
    ..registerLazySingleton(
      () => EstablishApiSessionUsecase(
        getIt<ApiSessionStore>(),
        getIt<RegisterDeviceUsecase>(),
        getIt<DeviceIdentityStore>(),
      ),
    );
}

/// What setup keeps: the completed flag, the test ring, the first topic,
/// the tool template, the first message and the stats consent.
void registerSetupState(GetIt getIt) {
  getIt
    ..registerLazySingleton(
      () => GetConnectionUsecase(getIt<ConnectionRepository>()),
    )
    ..registerLazySingleton(
      () =>
          GetOnboardingCompletedUsecase(getIt<OnboardingProgressRepository>()),
    )
    ..registerLazySingleton(
      () => CompleteOnboardingUsecase(
        getIt<OnboardingProgressRepository>(),
        getIt<OnboardingFlowRepository>(),
        // Setup is over, so a connect failure shown during it is not
        // shown again on a setup screen opened later.
        () {
          getIt<BackgroundConnect>().dismissFailure();
          // Setup was finished or left on a build that has the Home
          // checklist, which is what lets Home tell this install from one
          // set up long before it.
          unawaited(getIt<SetupChecklistStore>().markSetUpHere());
          // The missed alarm check counts nothing that opened before this.
          unawaited(getIt<MissedAlarmReader>().setupCompleted());
        },
        getIt<FirstTopicHandoff>(),
        getIt<SetupTestRing>(),
      ),
    )
    // The one exit every "Set this up later" button takes.
    ..registerLazySingleton(
      () => SetUpLaterUsecase(
        getIt<CompleteOnboardingUsecase>(),
        getIt<SetupTestRing>(),
      ),
    )
    // The incident of the test alarm setup sent, kept for the steps after
    // the ring and cleared when setup completes.
    ..registerLazySingleton<SetupTestRing>(
      () => PrefsSetupTestRing(getIt<SharedPreferences>()),
    )
    // Ends a setup test on the server so it cannot ring again later.
    ..registerLazySingleton(
      () => EndSetupTestUsecase(
        getIt<SetupTestRing>(),
        getIt<AcknowledgeIncidentUsecase>(),
        getIt<CloseIncidentUsecase>(),
        // Told apart the way the rest of the app tells a test: the title
        // the test route gives its message.
        (incidentId) async {
          try {
            final incident = await getIt<ApiClient>().getIncident(incidentId);
            return incident.messages.any(
              (message) => message.title != IncidentKinds.testAlarmTitle,
            );
          } on StaleAccountException {
            return null;
          } on ApiException catch (error) {
            // Gone from the server: nothing of the user's is in it.
            return error.statusCode == 404 ? false : null;
          }
        },
      ),
    )
    // How setup hears that an alarm reached this phone.
    ..registerLazySingleton<AlarmArrivals>(
      () => PlatformAlarmArrivals(
        push: getIt<PushHost>(),
        alarm: getIt<AlarmHost>(),
        alarmingIncidentIds: () =>
            getIt<IncidentAlarmController>().alarmingIncidentIds,
      ),
    )
    // The first topic setup made, held for the steps after it. The token stays
    // in memory and is cleared when setup completes.
    ..registerLazySingleton<FirstTopicHandoff>(
      () => PrefsFirstTopicHandoff(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton<ToolTemplateStore>(
      () => SharedPrefsToolTemplateStore(getIt<SharedPreferences>()),
    )
    // What the user said they send alarms from. A preference: setup ending
    // and a sign-out leave it. The replay holder keeps a replay's pick in
    // memory only.
    ..registerLazySingleton<SetupUseStore>(
      () => SharedPrefsSetupUseStore(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton<SetupUseReplay>(SetupUseReplay.new)
    // "A first message arrived", set once, and where each topic's watch
    // for it starts from.
    ..registerLazySingleton<FirstMessageStore>(
      () => PrefsFirstMessageStore(getIt<SharedPreferences>()),
    )
    // One watcher per screen that waits for the first message. The screen
    // starts it, pauses it in the background and disposes it on leaving.
    ..registerFactory(
      () => FirstMessageWatcher(
        store: getIt<FirstMessageStore>(),
        source: ApiFirstMessageSource(api: getIt<ApiClient>()),
      ),
    )
    // The analytics switch on the last setup step. Setup events held back
    // until the user chooses are sent or deleted by the funnel, which hears
    // the answer through the privacy repository.
    ..registerLazySingleton(
      () => SetupStatsConsent(
        privacy: getIt<PrivacyRepository>(),
        telemetry: getIt<TelemetryGate>(),
      ),
    );
}

/// Where a setup flow comes from, the offer gate, the step catalog and the
/// flow engine.
void registerOnboardingFlow(GetIt getIt) {
  getIt
    ..registerLazySingleton<OnboardingFlowRepository>(
      () => SharedPrefsOnboardingFlowRepository(getIt<SharedPreferences>()),
    )
    // What a developer set for setup. A store build gets the one that holds
    // nothing, and ignores whatever the prefs contain.
    ..registerLazySingleton<DeveloperOnboardingOverrides>(
      () => developerOnboardingOverridesFor(getIt<SharedPreferences>()),
    )
    // Where a setup flow comes from, highest priority first. The bundled flow
    // is always there to fall back on. A store build never holds the
    // developer source.
    ..registerLazySingleton<OnboardingFlowSource>(
      () => buildHasOnboardingDeveloperTools
          ? DeveloperOnboardingFlowSource(
              overrides: getIt<DeveloperOnboardingOverrides>(),
              requires: OnboardingStepRegistry.requiresById,
            )
          : const EmptyOnboardingFlowSource(),
      instanceName: developerOnboardingFlowSource,
    )
    // Remote Config: reads what is already activated, never waits.
    ..registerLazySingleton<OnboardingFlowSource>(
      () => getIt.isRegistered<TelemetryGate>()
          ? RemoteOnboardingFlowSource(getIt<TelemetryGate>())
          : const EmptyOnboardingFlowSource(),
      instanceName: remoteOnboardingFlowSource,
    )
    // The offer step's switches come from the same three places as the
    // flow: Developer options, Remote Config, then what ships in the app.
    // A store build holds no developer value.
    ..registerLazySingleton(
      () => OnboardingOfferGate(
        readDeveloperJson: () =>
            getIt<DeveloperOnboardingOverrides>().offerJson,
        readRemoteJson: () => getIt.isRegistered<TelemetryGate>()
            ? getIt<TelemetryGate>().onboardingOfferJson
            : null,
        readServerMode: () => getIt<AccountRepository>().readServerMode(),
        builtLayoutKeys: () => {
          for (final layout in paywallLayoutBuilders.keys) layout.key,
        },
        readAccountId: () async =>
            (await getIt<DeviceIdentityStore>().readOrCreate()).accountId,
        holdsPro: () => getIt<Holdings>().holdsConfirmed(Holding.pro),
        readHoldsHosted: holdsHostedReader(getIt),
        isSetupComplete: () async =>
            (await getIt<GetOnboardingCompletedUsecase>()(
              const NoParams(),
            )).getOrNull() ??
            false,
        readFlowSteps: () => getIt<OnboardingFlowEngine>().runningFlow().steps,
        readCompletedSteps: () =>
            getIt<OnboardingFlowRepository>().read().completed,
        readUse: ({required isReplay}) => setupUseFor(
          isReplay: isReplay,
          store: getIt<SetupUseStore>(),
          replay: getIt<SetupUseReplay>(),
        ),
        // The topic setup made: in memory while the run lasts, else the
        // name the phone kept.
        readTopicName: () =>
            getIt<FirstTopicHandoff>().entry?.topicName ??
            getIt<FirstTopicHandoff>().savedTopicName,
        // The store's answer about the product, asked for when the real
        // alarm step starts and read by "It works" and by the offer step.
        readSale: (product) => getIt<OfferSaleProbe>().answerFor(product),
        startSale: (product) => getIt<OfferSaleProbe>().start(product),
        // Only a build that skips the store has the made-up buy model, the
        // one a replay may play the offer on.
        readUsesDemoStore: () => buildSkipsPaywall,
      ),
    )
    // The one store check of the offer, shared by the gate and the step. It
    // makes the buy model the paywall route makes.
    ..registerLazySingleton(
      () => OfferSaleProbe(
        makeBuyModel: (product) => getIt<PaywallBuyCubit>(param1: product),
      ),
    )
    // The real maker, or in a debug run the one DEVICE_MAKER names, so the
    // battery step can be looked at on an emulator.
    ..registerLazySingleton<DeviceMakerReader>(
      () => kDebugMode && buildDeviceMaker.isNotEmpty
          ? FixedDeviceMakerReader.named(buildDeviceMaker)
          : PlatformDeviceMakerReader(
              DeviceInfoPlugin(),
              platform: defaultTargetPlatform,
              isWeb: kIsWeb,
            ),
    )
    // The Android version is always the real one, whatever the maker says.
    ..registerLazySingleton<AndroidSdkReader>(
      () => PlatformDeviceMakerReader(
        DeviceInfoPlugin(),
        platform: defaultTargetPlatform,
        isWeb: kIsWeb,
      ),
    )
    // One reader for the permission steps and their statuses. The setup
    // flow and the permissions screen both ask it.
    ..registerLazySingleton(
      () => ReadPermissionSetupUsecase(
        platform: defaultTargetPlatform,
        isWeb: kIsWeb,
        checkNotifications: getIt<CheckNotificationPermissionUsecase>(),
        alarm: getIt<AlarmHost>(),
        devicePermissions: getIt<DevicePermissionsRepository>(),
        makerReader: getIt<DeviceMakerReader>(),
        sdkReader: getIt<AndroidSdkReader>(),
      ),
    )
    ..registerLazySingleton<OnboardingStepCatalog>(
      () {
        final on = OnboardingPlatform(
          platform: defaultTargetPlatform,
          isWeb: kIsWeb,
        );
        final registry = OnboardingStepRegistry(
          on: on,
          facts: DeviceOnboardingStepFacts(
            on: on,
            getConnection: getIt<GetConnectionUsecase>(),
            readPermissionSetup: getIt<ReadPermissionSetupUsecase>(),
            notices: getIt<InAppNoticeRepository>(),
            firstMessage: getIt<FirstMessageStore>(),
            offer: getIt<OnboardingOfferGate>(),
          ),
        );
        return buildHasOnboardingDeveloperTools
            ? ForcedUnsatisfiedStepCatalog(
                registry,
                getIt<DeveloperOnboardingOverrides>(),
              )
            : registry;
      },
    )
    ..registerLazySingleton(
      () => OnboardingFlowEngine(
        sources: [
          getIt<OnboardingFlowSource>(
            instanceName: developerOnboardingFlowSource,
          ),
          getIt<OnboardingFlowSource>(
            instanceName: remoteOnboardingFlowSource,
          ),
          const BundledOnboardingFlowSource(),
        ],
        catalog: getIt<OnboardingStepCatalog>(),
        repository: getIt<OnboardingFlowRepository>(),
        completeOnboarding: getIt<CompleteOnboardingUsecase>(),
        getOnboardingCompleted: getIt<GetOnboardingCompletedUsecase>(),
        // The permission steps are done. If a connect was waiting for this
        // phone's push token, this is the moment to try again.
        onStepEvent: (event) {
          unawaited(reportStepToFunnel(getIt<OnboardingFunnel>(), event));
          if (event.kind == OnboardingStepEventKind.finished &&
              event.stepId == OnboardingStepId.permissions &&
              !event.isReplay) {
            unawaited(getIt<BackgroundConnect>().retryNow());
          }
        },
      ),
    );
}

/// The setup drafts, the first route and the background connect.
void registerOnboardingConnect(GetIt getIt) {
  getIt
    ..registerLazySingleton(
      () => ReadOnboardingDraftUsecase(getIt<OnboardingProgressRepository>()),
    )
    ..registerLazySingleton(
      () => SaveOnboardingDraftUsecase(getIt<OnboardingProgressRepository>()),
    )
    ..registerLazySingleton(
      () => ClearOnboardingDraftUsecase(getIt<OnboardingProgressRepository>()),
    )
    ..registerLazySingleton(
      () => InitialRouteResolver(
        getIt<GetOnboardingCompletedUsecase>(),
        getIt<OnboardingFlowEngine>(),
      ),
    )
    ..registerLazySingleton(
      () => ClearConnectionUsecase(
        getIt<ConnectionRepository>(),
        // Disconnecting also drops a connect that had not landed yet. It
        // goes first, so that connect cannot save a server in the gap.
        beforeClear: () => getIt<BackgroundConnect>().cancel(),
      ),
    )
    ..registerLazySingleton(
      () => ConnectIntentStore(getIt<SharedPreferences>()),
    )
    // One for the whole app run: the screen that starts a connect is gone
    // before it lands.
    ..registerLazySingleton(
      () => BackgroundConnect(
        intents: getIt<ConnectIntentStore>(),
        getServerInfo: getIt<GetServerInfoUsecase>(),
        establishSession: getIt<EstablishApiSessionUsecase>(),
        saveConnection: getIt<SaveConnectionUsecase>(),
        // Web registers no push, so its connect waits for no token.
        tokens: kIsWeb ? null : getIt<PushTokenProvider>(),
        // A Cloud connect makes this phone's account, so everything that
        // reads the account or the server loads again: topics, incidents
        // and the no-server card on Home.
        onConnected: () async => appAccountIdentityChanges.bump(),
        // A connect that gave up or was cancelled: the connect step is no
        // longer done, so a relaunch comes back to it.
        onAbandoned: () => getIt<OnboardingFlowEngine>().reopenStep(
          OnboardingStepId.connect,
        ),
        removeConnection: () async {
          await getIt<ConnectionRepository>().clearConnection();
        },
      ),
    );
}

/// Reading a server and connecting to it.
void registerConnectUsecases(GetIt getIt, {required LocalStore? localStore}) {
  getIt
    ..registerLazySingleton(
      () => GetServerInfoUsecase(getIt<ServerRepository>()),
    )
    // The one way a server is connected. The setup connect step and a
    // connect link both call it.
    ..registerLazySingleton(
      () => ConnectToServerUsecase(
        getIt<GetServerInfoUsecase>(),
        getIt<EstablishApiSessionUsecase>(),
        getIt<SaveConnectionUsecase>(),
        // A server picked by hand replaces a Cloud connect still waiting.
        cancelPendingConnect: () => getIt<BackgroundConnect>().cancel(),
        readSavedServerUrl: () async =>
            (await getIt<ConnectionRepository>().getConnection())
                .getOrNull()
                ?.serverUrl,
        // A connect to a different server drops what belongs to the old
        // one: everything an account wipe drops, plus the archive.
        // Settings, sounds, permissions and the rest stay.
        forgetServerData: () async {
          await getIt<AccountData>().forget();
          await localStore?.clearServerData();
        },
      ),
    );
}

/// The permissions and connect cubits of setup.
void registerOnboardingCubits(GetIt getIt) {
  getIt
    ..registerFactoryParam<
      NotificationPermissionsCubit,
      NotificationPermissionStep?,
      ({bool replayForDemo, bool standalone, bool cameBack})?
    >(
      (initialStep, mode) => NotificationPermissionsCubit(
        getIt<RequestNotificationPermissionUsecase>(),
        getIt<OpenNotificationSettingsUsecase>(),
        readSetup: getIt<ReadPermissionSetupUsecase>(),
        alarm: getIt<AlarmHost>(),
        devicePermissions: getIt<DevicePermissionsRepository>(),
        replayForDemo: mode?.replayForDemo ?? false,
        standalone: mode?.standalone ?? false,
        cameBack: mode?.cameBack ?? false,
        initialStep: initialStep ?? NotificationPermissionStep.initial,
      ),
    )
    ..registerFactoryParam<OnboardingConnectCubit, bool?, void>(
      (initialConnected, _) => OnboardingConnectCubit(
        getIt<GetServerInfoUsecase>(),
        getIt<SaveConnectionUsecase>(),
        setUpLater: getIt<SetUpLaterUsecase>(),
        establishSession: getIt<EstablishApiSessionUsecase>(),
        getConnection: getIt<GetConnectionUsecase>(),
        getTopics: getIt<GetTopicsUsecase>(),
        alarmHost: getIt<AlarmHost>(),
        readDraft: getIt<ReadOnboardingDraftUsecase>(),
        saveDraft: getIt<SaveOnboardingDraftUsecase>(),
        backgroundConnect: getIt<BackgroundConnect>(),
        // "Use a different server" on the connect step drops the old one
        // with the very call Settings > Server makes.
        disconnect: () async {
          final settings = getIt<SettingsCubit>();
          try {
            await settings.disconnectServer();
          } finally {
            await settings.close();
          }
        },
        connectToServer: getIt<ConnectToServerUsecase>(),
        initialConnected: initialConnected ?? false,
      ),
    );
}

/// The welcome, real ring and hook up cubits.
void registerOnboardingStepCubits(GetIt getIt) {
  getIt
    ..registerFactory(
      () => OnboardingWelcomeCubit(
        getIt<GetServerInfoUsecase>(),
      ),
    )
    ..registerFactoryParam<RealRingCubit, bool?, void>(
      (isReplay, _) => RealRingCubit(
        triggerTest: getIt<TriggerTestAlarmUsecase>(),
        updateTopic: getIt<UpdateTopicUsecase>(),
        // The app's one topic list. Loaded once if this step is the first
        // to need it, never fetched again here.
        readTopics: () async {
          final topics = getIt<TopicsCubit>();
          await topics.ensureLoaded();
          return topics.state.topics;
        },
        refreshTopics: () async {
          final topics = getIt<TopicsCubit>();
          await topics.refresh();
          return topics.state.topics;
        },
        hasConnection: () async =>
            (await getIt<GetConnectionUsecase>()(
              const NoParams(),
            )).getOrNull() !=
            null,
        connectState: () => getIt<BackgroundConnect>().state,
        connectChanges: getIt<BackgroundConnect>().stream,
        handoff: getIt<FirstTopicHandoff>(),
        ring: getIt<SetupTestRing>(),
        arrivals: getIt<AlarmArrivals>(),
        alarmHost: getIt<AlarmHost>(),
        onTopicUpdated: (topic) => getIt<TopicsCubit>().applyTopic(topic),
        readServerUrl: () async => (await getIt<GetConnectionUsecase>()(
          const NoParams(),
        )).getOrNull()?.serverUrl,
        // The same reads the create-topic screen makes for its plan line: a
        // paid plan and a server of the user's own have no cap to state.
        readCriticalLimit: () async {
          return AccountAccess(
            await getIt<DeviceIdentityStore>().readOrCreate(),
          ).freeCriticalCap(
            isUnlimited: await getIt<FeatureAccess>().usableOnceReady(
              AppFeature.unlimitedCriticalTopics,
            ),
          );
        },
        isReplay: isReplay ?? false,
        on: OnboardingPlatform(platform: defaultTargetPlatform, isWeb: kIsWeb),
      ),
    )
    ..registerFactoryParam<HookUpCubit, bool?, void>(
      (isReplay, _) => HookUpCubit(
        handoff: getIt<FirstTopicHandoff>(),
        templates: getIt<ToolTemplateStore>(),
        createToken: getIt<CreateTopicTokenUsecase>(),
        readTopics: () async {
          final topics = getIt<TopicsCubit>();
          await topics.ensureLoaded();
          return topics.state.topics;
        },
        refreshTopics: () async {
          final topics = getIt<TopicsCubit>();
          await topics.refresh();
          return topics.state.topics;
        },
        readServerUrl: () async => (await getIt<GetConnectionUsecase>()(
          const NoParams(),
        )).getOrNull()?.serverUrl,
        watcher: getIt<FirstMessageWatcher>(),
        consent: getIt<SetupStatsConsent>(),
        revokeToken: getIt<RevokeTopicTokenUsecase>(),
        ring: getIt<SetupTestRing>(),
        isSetupComplete: () async =>
            (await getIt<GetOnboardingCompletedUsecase>()(
              const NoParams(),
            )).getOrNull() ??
            false,
        alarmArrivals: getIt<AlarmArrivals>().incidentIds,
        readIncidentTopic: (incidentId) async =>
            (await getIt<ApiClient>().getIncident(incidentId)).topic,
        alarmHost: getIt<AlarmHost>(),
        isReplay: isReplay ?? false,
        on: OnboardingPlatform(platform: defaultTargetPlatform, isWeb: kIsWeb),
      ),
    );
}
