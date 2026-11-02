import 'dart:async';
import 'package:critalarm/app/account_data.dart';
import 'package:critalarm/app/challenge_flag_sync.dart';
import 'package:critalarm/app/held_account_scope.dart';
import 'package:critalarm/app/moved_phone_reset.dart';
import 'package:critalarm/app/sound_lock_sync.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/ack/ack_queue.dart';
import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/alarm/live_activity_token_registry.dart';
import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/backup/backup_host.dart';
import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:critalarm/core/sound/own_sound_lock_flag.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/core/store/services/google_sign_in_sheet.dart';
import 'package:critalarm/core/store/services/sign_in_options.dart';
import 'package:critalarm/core/store/services/store_billing.dart';
import 'package:critalarm/core/sync/message_sync_service.dart';
import 'package:critalarm/features/account/data/repositories/api_account_repository.dart';
import 'package:critalarm/features/account/data/repositories/http_identity_repository.dart';
import 'package:critalarm/features/account/data/services/identity_token_store.dart';
import 'package:critalarm/features/account/data/services/provider_sign_in.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/account/domain/repositories/identity_repository.dart';
import 'package:critalarm/features/account/presentation/cubits/account_cubit.dart';
import 'package:critalarm/features/challenges/domain/challenge_choices.dart';
import 'package:critalarm/features/in_app_notices/domain/cancel_question/cancel_answer_sender.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_choices.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_gate.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_look_store.dart';
import 'package:critalarm/features/onboarding/domain/connect/background_connect.dart';
import 'package:critalarm/features/onboarding/domain/repositories/connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/device_token_registry.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_log.dart';
import 'package:critalarm/features/search/domain/repositories/recent_searches_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Provider sign-in, the identity repository and the account repository.
void registerAccount(
  GetIt getIt, {
  required LocalStore? localStore,
  required HeldAccountScope heldScope,
  required http.Client? httpClient,
}) {
  getIt
    ..registerLazySingleton<ProviderSignIn>(
      () => NativeProviderSignIn(
        options: getIt<SignInOptions>(),
        google: getIt<GoogleSignInSheet>(),
      ),
    )
    ..registerLazySingleton<IdentityRepository>(
      () => HttpIdentityRepository(
        httpClient: httpClient ?? http.Client(),
        sessions: getIt<ApiSessionStore>(),
        prefs: getIt<SharedPreferences>(),
        providers: getIt<ProviderSignIn>(),
        // iOS preferences go into iCloud and computer backups, so the
        // session token is a ThisDeviceOnly Keychain item there.
        tokens: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
            ? KeychainIdentityTokenStore(getIt<SharedPreferences>())
            : PrefsIdentityTokenStore(getIt<SharedPreferences>()),
        identityChanges: appAccountIdentityChanges,
      ),
    )
    ..registerLazySingleton<AccountRepository>(
      () => ApiAccountRepository(
        api: getIt<ApiClient>(),
        sessions: getIt<ApiSessionStore>(),
        devices: getIt<DeviceIdentityStore>(),
        register: getIt<RegisterDeviceUsecase>(),
        identities: getIt<IdentityRepository>(),
        connections: getIt<ConnectionRepository>(),
        forgetAccountData: () => getIt<AccountData>().forget(),
        forgetDeletedAccountData: (accountId) async {
          await getIt<AccountData>().forgetDeleted(
            scope: accountId == null
                ? null
                : await heldScope.forAccount(accountId),
          );
        },
        readAccountId: heldScope.accountId,
        // A merge folds the phone's account into another, so the history
        // kept under the old one moves to the new one.
        forgetMergedAccount: (from, into) async {
          final fromScope = await heldScope.forAccount(from);
          final intoScope = await heldScope.forAccount(into);
          if (fromScope == null || intoScope == null) return;
          await localStore?.mergeArchive(from: fromScope, into: intoScope);
        },
        signOutBilling: buildSkipsPaywall
            ? null
            : () async {
                final billing = getIt<StoreBilling>();
                // A store that was never configured (no key in a dev build)
                // never logged in to this account, so there is nothing to
                // log out of.
                if (!billing.isConfigured) return;
                await billing.logOut();
              },
        stopAlarm: getIt<AlarmHost>().stopRinging,
        holdings: getIt<Holdings>(),
      ),
    );
}

/// The list of what belongs to an account, and the reset for a restored
/// install.
void registerAccountData(GetIt getIt, {required LocalStore? localStore}) {
  // The one list of what belongs to an account on this phone. A sign-out,
  // an account delete and a connect to a different server all call it.
  getIt
    ..registerLazySingleton(
      () => AccountData(
        acks: getIt<AckQueue>(),
        messageCursors: getIt<MessageSyncService>(),
        recentSearches: getIt<RecentSearchesRepository>(),
        challenges: getIt<ChallengeChoices>(),
        alarmStyles: getIt<AlarmStyleChoices>(),
        soundLock: getIt<OwnSoundLockFlag>(),
        ownLook: getIt<OwnLookStore>(),
        proofLog: getIt<ProofLog>(),
        cancelAnswers: getIt<CancelAnswerSender>(),
        heldTopics: localStore?.topics,
        archive: localStore,
        cancelAlarmChains: () => getIt<AlarmHost>().cancelAllChains(),
        // Not waited for: each check asks the access layer, and neither a
        // wipe nor a connect waits on a plan.
        afterForget: () async {
          unawaited(getIt<SoundLockSync>().checkAfterWipe());
          unawaited(getIt<ChallengeFlagSync>().checkAfterWipe());
          unawaited(getIt<AlarmStyleGate>().check());
        },
      ),
    )
    // An install restored onto another phone starts as a phone the relay
    // has never seen. Run once at launch, before anything reads the
    // identity. It drops account data through the list above and nothing
    // else, then the identity, then connects again as a new device.
    ..registerLazySingleton(
      () => MovedPhoneReset(
        host: getIt<BackupHost>(),
        forgetAccountData: () => getIt<AccountData>().forget(),
        forgetRestoredSignIn: () =>
            getIt<IdentityRepository>().forgetRestoredSignIn(),
        sessions: getIt<ApiSessionStore>(),
        connections: getIt<ConnectionRepository>(),
        devices: getIt<DeviceIdentityStore>(),
        forgetSentPushToken: () async {
          final prefs = getIt<SharedPreferences>();
          await prefs.remove(DeviceTokenRegistry.lastTokenKey);
          await prefs.remove(DeviceTokenRegistry.lastVersionKey);
          await prefs.remove(DeviceTokenRegistry.lastKindKey);
          // The old phone's Live Activity tokens: the ones the relay took,
          // and any the old phone had not sent yet. iOS keeps the second
          // list itself (`IncidentActivityCoordinator.pendingTokensKey`).
          await prefs.remove(LiveActivityTokenRegistry.acceptedKey);
          await prefs.remove('pending_activity_tokens');
        },
        reconnect: (serverUrl) => getIt<BackgroundConnect>().start(serverUrl),
      ),
    );
}

/// The account cubit.
void registerAccountCubit(GetIt getIt) {
  getIt.registerFactory(
    () => AccountCubit(
      identities: getIt<IdentityRepository>(),
      account: getIt<AccountRepository>(),
    ),
  );
}
