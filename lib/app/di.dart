import 'dart:async';
import 'package:critalarm/app/di/register_access.dart';
import 'package:critalarm/app/di/register_account.dart';
import 'package:critalarm/app/di/register_alarm.dart';
import 'package:critalarm/app/di/register_app.dart';
import 'package:critalarm/app/di/register_app_icons.dart';
import 'package:critalarm/app/di/register_challenges.dart';
import 'package:critalarm/app/di/register_core.dart';
import 'package:critalarm/app/di/register_feature_guides.dart';
import 'package:critalarm/app/di/register_feedback.dart';
import 'package:critalarm/app/di/register_history.dart';
import 'package:critalarm/app/di/register_in_app_notices.dart';
import 'package:critalarm/app/di/register_incidents.dart';
import 'package:critalarm/app/di/register_language.dart';
import 'package:critalarm/app/di/register_local_reminders.dart';
import 'package:critalarm/app/di/register_onboarding.dart';
import 'package:critalarm/app/di/register_paywall.dart';
import 'package:critalarm/app/di/register_permissions.dart';
import 'package:critalarm/app/di/register_pro_pack.dart';
import 'package:critalarm/app/di/register_reliability.dart';
import 'package:critalarm/app/di/register_search.dart';
import 'package:critalarm/app/di/register_settings.dart';
import 'package:critalarm/app/di/register_sound.dart';
import 'package:critalarm/app/di/register_telemetry.dart';
import 'package:critalarm/app/di/register_topics.dart';
import 'package:critalarm/app/di/register_weekly_check.dart';
import 'package:critalarm/app/held_account_scope.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/alarm/alarm_build_mode.dart';
import 'package:critalarm/core/api/api_build_mode.dart';
import 'package:critalarm/core/device/device_form.dart';
import 'package:critalarm/core/platform/device_word.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/platform/store_kind.dart';
import 'package:critalarm/core/push/push_host.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/core/store/play_apple/play_apple_store_services.dart';
import 'package:critalarm/core/store/services/store_services.dart';
import 'package:critalarm/design_system/edge_effect.dart';
import 'package:critalarm/features/feedback/domain/feedback_links.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_connection_repository.dart';
import 'package:critalarm/features/reliability/data/platform_phone_capture.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

final GetIt getIt = GetIt.instance;

/// Composition root. Registration order is: platform singletons, then
/// repositories, then usecases, then cubits. Keep it in that order as features
/// land so a missing dependency is obvious from where the call sits.
///
/// The registrations live in `lib/app/di/`, one `register<Name>` function per
/// run of registrations of one feature. The calls below are in the order the
/// registrations always had. Where two features interleave, the run stays
/// split in two calls here, so the order is the order of this list.
///
/// The locals this function builds (the preferences, the store, the held
/// scope, the identity store and the platform values) are handed to the
/// functions that read them. None of them is a registration of its own.
Future<void> configureDependencies({
  bool useMockApi = buildUsesMockApi,
  http.Client? httpClient,
  LocalStore? openedStore,
}) async {
  final prefs = await SharedPreferences.getInstance();

  // The phone's own copy of every incident and message (api.md §4.2, where
  // `history_days` became retention). Web has no sqflite, so the dashboard
  // build keeps reading the server live and every store call is skipped.
  //
  // [openedStore] is a store the caller already opened, for a test or a
  // capture that has no documents directory. It is used as it is.
  var localStore = openedStore;
  final identityStore = DeviceIdentityStore.forPlatform(prefs);
  // The server and account the held data (the topic list, the archive)
  // belongs to. Nothing is registered yet, so it reads the saved connection
  // and identity from the preferences directly, which is where the
  // registered repositories keep them.
  final heldScope = HeldAccountScope(
    prefs: prefs,
    devices: identityStore,
    serverUrl: () async => (await SharedPrefsConnectionRepository(
      prefs,
    ).getConnection()).getOrNull()?.serverUrl,
  );
  if (!kIsWeb && localStore == null) {
    try {
      // The scope also stamps the rows already on the phone, once, when a file
      // from before rows were scoped is upgraded.
      localStore = await LocalStore.open(
        scope: heldScope.call,
      );
    } on Object catch (error, stack) {
      // A database that will not open must not stop the app from ringing.
      debugPrint('local_store_open_failed error=$error');
      debugPrintStack(stackTrace: stack);
    }
  }

  registerLanguage(getIt, prefs: prefs);

  // The alarm service runs with no Dart engine, so it reads this flag out of
  // the same preferences file rather than asking the app. Written on every
  // launch so a store build, where the constant is false, always clears it.
  await prefs.setBool('quiet_alarm', buildUsesQuietAlarm);

  await registerTelemetryGate(getIt);
  registerDevAccessSwitches(getIt, prefs: prefs);
  registerDevPaywallLayoutSwitches(getIt, prefs: prefs);

  // The one place that reads `kIsWeb` for feature code. Features ask
  // `PlatformCapabilities` and never read the global themselves.
  final capabilities = PlatformCapabilities(
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
  );

  // The store this build is for, from `--dart-define=STORE=...`, read here
  // and nowhere else, and the set of store services it picks.
  final store = StoreKind.resolve(
    define: const String.fromEnvironment('STORE'),
    platform: defaultTargetPlatform,
  );
  if (!getIt.isRegistered<StoreServices>()) {
    final storeServices = storeServicesFor(
      store,
      capabilities: capabilities,
      pushHost: getIt.get<PushHost>,
    );
    await startStoreBilling(storeServices, identityStore);
    getIt.registerSingleton<StoreServices>(storeServices);
  }
  await registerPriceBook(getIt);

  final deviceForm = await DeviceForm.read();
  // The word the copy uses for this device: phone, iPad, tablet or
  // computer. Read once, like the capabilities, and handed to the
  // translations as they load (main.dart).
  final deviceWord = await readDeviceWord(
    capabilities: capabilities,
    dispatcher: WidgetsBinding.instance.platformDispatcher,
  );
  appEdgeEffect.value = autoEdgeEffect(
    platform: defaultTargetPlatform,
    shaderSupported: await loadEdgeBlurShader(),
    isLowRamDevice: deviceForm.isLowRamDevice,
  );

  registerPlatformSingletons(
    getIt,
    prefs: prefs,
    capabilities: capabilities,
    store: store,
    deviceForm: deviceForm,
    deviceWord: deviceWord,
  );
  registerTopicListPrefs(getIt);
  registerAppHosts(
    getIt,
    identityStore: identityStore,
    capabilities: capabilities,
  );
  registerApiClient(
    getIt,
    heldScope: heldScope,
    useMockApi: useMockApi,
    httpClient: httpClient,
  );
  registerProofLog(getIt);
  registerWeeklyCheck(getIt);
  registerApiRoutes(getIt);
  registerProPackAccess(getIt);
  registerAccess(getIt);
  registerProPackShop(getIt);
  registerThemePreference(getIt);
  registerTopicRepository(getIt);
  registerIncidentRepository(getIt, localStore: localStore);
  registerStorageSettings(getIt, localStore: localStore);
  registerOnboardingRepositories(getIt);
  registerSettingsRepositories(getIt);
  registerSoundHosts(getIt);
  registerPermissionRepositories(getIt);
  registerSubscriptionRepository(getIt);
  registerPermissionUsecases(getIt);
  registerDeviceRegistration(getIt);
  registerAccount(
    getIt,
    localStore: localStore,
    heldScope: heldScope,
    httpClient: httpClient,
  );
  registerNoticeStores(getIt);
  registerLocalReminders(getIt);
  registerNoticeRules(getIt);
  registerDeviceReport(getIt);
  registerAlarmPath(getIt);
  registerAnalyticsEvents(getIt);
  registerAckQueue(getIt);
  registerAlarmDebug(getIt, localStore: localStore);
  registerMessageSync(getIt);
  registerSetupState(getIt);
  registerOnboardingFlow(getIt);
  registerOnboardingConnect(getIt);
  registerSettingsUsecases(getIt);
  registerConnectUsecases(getIt, localStore: localStore);
  registerIncidentUsecases(getIt);
  registerSharedLists(getIt, localStore: localStore, heldScope: heldScope);
  registerWidgetSync(getIt);
  registerAccountData(getIt, localStore: localStore);
  registerOwnSoundLock(getIt);
  registerChallengeChoices(getIt);
  registerAlarmStyle(getIt);
  registerChallengeGate(getIt);
  registerIncomingAudio(getIt);
  registerIncidentCloseUsecases(getIt);
  registerSearchRepositories(getIt);
  registerFeatureGuides(getIt);
  registerSearchUsecases(getIt);
  registerTopicUsecases(getIt);
  registerPaywallUsecases(getIt);
  registerOnboardingCubits(getIt);
  registerAppearanceCubits(getIt);
  registerAppIcons(getIt);
  registerOnboardingStepCubits(getIt);
  registerHome(getIt);
  registerSearchCubit(getIt);
  registerShell(getIt);
  registerReliabilityChecks(getIt);
  registerMissedAlarm(getIt);
  registerReliabilityCubit(getIt);
  registerHistory(getIt, localStore: localStore);
  registerTopicScreens(getIt);
  registerAlarmScreens(getIt);
  registerAccountCubit(getIt);
  registerSettingsCubit(getIt);
  registerLocalReminderCubits(getIt);
  registerSoundCubits(getIt);
  registerPermissionsCubit(getIt);
  registerPaywall(getIt, localStore: localStore);
  registerNotices(getIt);

  linkDevSwitchesToMockRelay(getIt, useMockApi: useMockApi);
}

/// Starts what the missed alarm check needs from launch on. Call it on the
/// line before the push event drain runs: the drain empties the native list
/// this copies.
///
/// It reads and listens. It changes nothing about how an alarm rings.
void startMissedAlarmWatch() {
  getIt<PlatformPhoneCapture>()
    ..start()
    ..holdPendingRows();
  // A topic is stamped the moment the shared list first holds it.
  final topics = getIt<TopicsCubit>();
  void seen(TopicsState state) {
    if (!state.isReady) return;
    unawaited(
      getIt<MissedAlarmReader>().topicsSeen([
        for (final topic in state.topics) topic.name,
      ]),
    );
  }

  seen(topics.state);
  topics.stream.listen(seen);
}

/// The store services for [store]: everything a store decides, in one set.
///
/// Google Play and the App Store share the RevenueCat set. The Galaxy and
/// Huawei builds get it too until their own sets exist, so they run the
/// code the Play build runs today.
StoreServices storeServicesFor(
  StoreKind store, {
  required PlatformCapabilities capabilities,
  required PushHost Function() pushHost,
}) => switch (store) {
  StoreKind.play ||
  StoreKind.apple ||
  StoreKind.galaxy ||
  StoreKind.huawei => PlayAppleStoreServices(
    store: store,
    capabilities: capabilities,
    pushHost: pushHost,
    appStoreId: FeedbackLinks.appStoreId,
  ),
};
