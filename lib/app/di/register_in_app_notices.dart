import 'dart:async';
import 'package:critalarm/app/di/di_reads.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/widget_sync.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/alarm/alarm_focus.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/api/cancel_reason_api.dart';
import 'package:critalarm/core/app_icon/app_icon_guard.dart';
import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/store/services/store_billing.dart';
import 'package:critalarm/core/telemetry/analytics_events.dart';
import 'package:critalarm/core/telemetry/cancel_reason_analytics.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/core/version/app_version.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/account/domain/repositories/identity_repository.dart';
import 'package:critalarm/features/feature_guides/presentation/cubits/feature_guide_cubit.dart';
import 'package:critalarm/features/in_app_notices/data/repositories/shared_prefs_in_app_notice_repository.dart';
import 'package:critalarm/features/in_app_notices/data/shared_prefs_cancel_answer_store.dart';
import 'package:critalarm/features/in_app_notices/domain/cancel_question/cancel_answer_sender.dart';
import 'package:critalarm/features/in_app_notices/domain/cancel_question/cancel_answer_store.dart';
import 'package:critalarm/features/in_app_notices/domain/cancel_question/cancel_question.dart';
import 'package:critalarm/features/in_app_notices/domain/day0_card_rules.dart';
import 'package:critalarm/features/in_app_notices/domain/home_ask_rules.dart';
import 'package:critalarm/features/in_app_notices/domain/pro_ask_rules.dart';
import 'package:critalarm/features/in_app_notices/domain/pro_ending.dart';
import 'package:critalarm/features/in_app_notices/domain/repositories/in_app_notice_repository.dart';
import 'package:critalarm/features/in_app_notices/domain/setup_gate.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/day0_card_cubit.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/in_app_notice_cubit.dart';
import 'package:critalarm/features/incidents/domain/real_use.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_settler.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_store.dart';
import 'package:critalarm/features/local_reminders/domain/plan_status_source.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/setup_test_ring.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_onboarding_completed_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';
import 'package:critalarm/features/settings/domain/repositories/privacy_repository.dart';
import 'package:critalarm/features/topics/domain/first_message/first_message_store.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The notice repository and the cancel question.
void registerNoticeStores(GetIt getIt) {
  getIt
    ..registerLazySingleton<InAppNoticeRepository>(
      () => SharedPrefsInAppNoticeRepository(getIt<SharedPreferences>()),
    )
    // The cancel question keeps its own store, apart from the notice
    // repository, so that repository and its fakes stay as they are.
    ..registerLazySingleton<CancelAnswerStore>(
      () => SharedPrefsCancelAnswerStore(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton(
      () => CancelAnswerSender(
        store: getIt<CancelAnswerStore>(),
        api: getIt<CancelReasonApi>(),
        analytics: getIt.isRegistered<TelemetryGate>()
            ? CancelReasonAnalytics(getIt<TelemetryGate>())
            : null,
        readContext: () async {
          final mode = await getIt<AccountRepository>().readServerMode();
          // Only Crit Alarm Cloud sells the plan, so only it takes an answer.
          final isCloud = mode == ServerMode.hosted; // access-ok: cloud only
          if (!isCloud) return null;
          final identity = await getIt<DeviceIdentityStore>().readOrCreate();
          final accountId = identity.accountId;
          if (accountId == null) return null;
          final package = await PackageInfo.fromPlatform();
          return CancelSendContext(
            accountId: accountId,
            appVersion: package.buildNumber.isEmpty
                ? package.version
                : '${package.version}+${package.buildNumber}',
            platform: defaultPushPlatform(),
          );
        },
      ),
    )
    ..registerLazySingleton(
      () => CancelQuestion(store: getIt<CancelAnswerStore>()),
    );
}

/// The setup gate and the rules that decide which notice may show.
void registerNoticeRules(GetIt getIt) {
  getIt
    ..registerLazySingleton<SetupGate>(
      () => SetupGate(
        isOnboardingDone: () async {
          final done = await getIt<GetOnboardingCompletedUsecase>()(
            const NoParams(),
          );
          return done.getOrNull() ?? false;
        },
        hasSeenFeatureGuide: () => getIt<FeatureGuideCubit>().hasSeenFirstGuide,
        isFeatureGuideActive: () => getIt<FeatureGuideCubit>().state.isActive,
      ),
    )
    ..registerLazySingleton<ProAskRules>(
      () => ProAskRules(
        noticeRepository: getIt<InAppNoticeRepository>(),
        accountRepository: getIt<AccountRepository>(),
        offersOn: () => getIt<LocalReminderStore>().readSwitches().offers,
        isSetupDone: () => getIt<SetupGate>().isDone(),
      ),
    )
    ..registerLazySingleton<HomeAskRules>(
      () => HomeAskRules(
        noticeRepository: getIt<InAppNoticeRepository>(),
        privacyRepository: getIt<PrivacyRepository>(),
        isWeb: getIt<PlatformCapabilities>().isWeb,
        settle: () =>
            getIt<LocalReminderSettler>().settleAsks(now: DateTime.now()),
        isSetupDone: () => getIt<SetupGate>().isDone(),
        // An ack made on another device counts too, and only the shared list
        // carries it. The review popup skips the whole day of one.
        // An alarm setup itself caused is left out: it is not real use.
        newestAckedAt: () => newestRealAckedAt(
          acks: [
            for (final incident in getIt<IncidentsCubit>().state.incidents)
              (id: incident.id, ackedAt: incident.ackedAt),
          ],
          setupIncidentIds: getIt<SetupTestRing>().setupIncidentIds,
        ),
      ),
    )
    ..registerLazySingleton(() => Day0CardAnalytics(getIt<TelemetryGate>()))
    ..registerLazySingleton<Day0CardRules>(
      () => Day0CardRules(
        noticeRepository: getIt<InAppNoticeRepository>(),
        accountRepository: getIt<AccountRepository>(),
        firstMessageStore: getIt<FirstMessageStore>(),
        isWeb: getIt<PlatformCapabilities>().isWeb,
        isSetupDone: () => getIt<SetupGate>().isDone(),
        isRinging: () => getIt<AlarmFocus>().on,
      ),
    )
    ..registerFactory(
      () => Day0CardCubit(
        rules: getIt<Day0CardRules>(),
        noticeRepository: getIt<InAppNoticeRepository>(),
        analytics: getIt<Day0CardAnalytics>(),
      ),
    );
}

/// The Pro ending and the notice cubit.
void registerNotices(GetIt getIt) {
  getIt
    ..registerLazySingleton(
      () => ProEnding(
        notices: getIt<InAppNoticeRepository>(),
        plan: getIt<PlanStatusSource>(),
        readIdentity: () => getIt<DeviceIdentityStore>().readOrCreate(),
        readServerSaysHosted: hostedByServerReader(getIt),
        readServerMode: () => getIt<AccountRepository>().readServerMode(),
        refreshRegistration: () async {
          if (!buildSkipsPaywall) {
            await getIt<StoreBilling>().invalidateCustomerCache();
          }
          await getIt<RegisterDeviceUsecase>()(appVersion: appVersion);
        },
        onPaidChanged: () {
          getIt<WidgetSync>().rewrite();
          unawaited(getIt<AppIconGuard>().check());
        },
      ),
    )
    ..registerFactory<InAppNoticeCubit>(
      () => InAppNoticeCubit(
        getConnectionUsecase: getIt<GetConnectionUsecase>(),
        identityRepository: getIt<IdentityRepository>(),
        accountRepository: getIt<AccountRepository>(),
        noticeRepository: getIt<InAppNoticeRepository>(),
        readTopics: () async =>
            (await getIt<GetTopicsUsecase>()(const NoParams())).getOrNull(),
        proEnding: getIt<ProEnding>(),
        identityChanges: appAccountIdentityChanges,
        isSetupDone: () => getIt<SetupGate>().isDone(),
      ),
    );
}
