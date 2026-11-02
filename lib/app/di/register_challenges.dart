import 'package:critalarm/app/challenge_flag_sync.dart';
import 'package:critalarm/app/widget_sync.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/account/account_tag.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/features/challenges/data/shared_prefs_challenge_choices.dart';
import 'package:critalarm/features/challenges/domain/challenge_choices.dart';
import 'package:critalarm/features/challenges/domain/challenge_gate.dart';
import 'package:critalarm/features/challenges/presentation/challenge.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The wake-up challenge choices.
void registerChallengeChoices(GetIt getIt) {
  // Wake-up challenges: each topic's choice, kept on this phone only; the
  // gate the alarm screen asks before "At my desk" closes an incident;
  // and the one flag per topic native code reads for its Done button.
  // None of it is asked before "I'm up", which stops the ring with one
  // tap on every plan.
  getIt.registerLazySingleton<ChallengeChoices>(
    () => SharedPrefsChallengeChoices(getIt<SharedPreferences>()),
  );
}

/// The challenge gate and the flag sync.
void registerChallengeGate(GetIt getIt) {
  getIt
    ..registerLazySingleton(
      () => ChallengeGate(
        choices: getIt<ChallengeChoices>(),
        decide: () =>
            getIt<FeatureAccess>().decide(AppFeature.wakeUpChallenges),
        canRun: (kind, incident) =>
            challengeOf(kind)?.canRunFor(incident) ?? false,
        planRead: getIt<FeatureAccess>().ready,
      ),
    )
    // The flag is set only on a sure answer, so this waits for the plan and
    // the saved server to be read, and a plan that cannot be read leaves
    // what is written alone. Without the plan no flag is ever set.
    ..registerLazySingleton(
      () => ChallengeFlagSync(
        decide: () => getIt<FeatureAccess>().decideOnceReady(
          AppFeature.wakeUpChallenges,
        ),
        changes: [
          getIt<FeatureAccess>().changes.where(
            (feature) => feature == AppFeature.wakeUpChallenges,
          ),
          getIt<ChallengeChoices>().changes,
        ],
        // A kind this build has no challenge for asks for nothing.
        readChoices: () => {
          for (final MapEntry(:key, :value)
              in getIt<ChallengeChoices>().choices.entries)
            if (challengeOf(value) != null) key,
        },
        readWritten: () => getIt<ChallengeChoices>().flaggedTopics,
        write: (topic, {required isOwed}) =>
            getIt<ChallengeChoices>().writeFlag(topic, isOwed: isOwed),
        // The iOS Live Activity reads its own copy, made with the sound
        // choices. Android reads the flag where it is written.
        publish: () async =>
            !getIt<PlatformCapabilities>().isIos ||
            await getIt<SoundHost>().publishSoundAssignments(),
        // A widget showing an acknowledged incident draws its Done button
        // from the flag, so it is drawn again when a flag changes. The
        // snapshot rewrite is the refresh the widgets already have.
        redraw: () => getIt<WidgetSync>().rewrite(),
        // The flags are kept with the tag of the account they were written
        // for, and flags for another account go before any is trusted.
        keepOnlyOurs: () async => getIt<ChallengeChoices>().keepFlagsOnlyFor(
          accountTagFor(
            (await getIt<DeviceIdentityStore>().readOrCreate()).accountId,
          ),
        ),
      ),
    );
}
