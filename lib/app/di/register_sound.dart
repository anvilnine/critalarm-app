import 'package:critalarm/app/sound_lock_sync.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/account/account_tag.dart';
import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/sound/incoming_audio.dart';
import 'package:critalarm/core/sound/own_sound_lock_flag.dart';
import 'package:critalarm/core/sound/own_sound_rule.dart';
import 'package:critalarm/core/sound/share_copy_path.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/core/sound/sound_pack_host.dart';
import 'package:critalarm/core/sound/sound_pack_repository.dart';
import 'package:critalarm/core/sound/sound_peaks_cache.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_onboarding_completed_usecase.dart';
import 'package:critalarm/features/settings/data/services/sound_file_picker.dart';
import 'package:critalarm/features/settings/domain/repositories/sound_file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The native sound hosts, the sound packs, the peaks cache and the file
/// picker.
void registerSoundHosts(GetIt getIt) {
  getIt
    ..registerLazySingleton<SoundHost>(SoundHost.new)
    ..registerLazySingleton<SoundPackHost>(SoundPackHost.new)
    ..registerLazySingleton<SoundPackRepository>(
      () => SoundPackRepository(getIt<SoundPackHost>()),
    )
    ..registerLazySingleton<SoundPeaksCache>(
      () => SoundPeaksCache(getIt<SoundHost>()),
    )
    ..registerLazySingleton<SoundFilePicker>(PlatformSoundFilePicker.new);
}

/// The own sounds lock flag and the sync that writes it.
void registerOwnSoundLock(GetIt getIt) {
  // The one flag native code reads to know own sounds are locked. It
  // follows the own sounds decision: a purchase, a pack that ended, a
  // server that became known. It is written only on a sure answer, so
  // this waits for the plan and the saved server to be read, and a plan
  // that cannot be read leaves the last value alone.
  //
  // The flag is kept with the tag of the account it was written for, and
  // a flag for another account is taken away at the start of every check.
  getIt
    ..registerLazySingleton(
      () => OwnSoundLockFlag(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton(
      () => SoundLockSync(
        isLocked: () async =>
            !await getIt<FeatureAccess>().canOnceReady(AppFeature.ownSounds),
        changes: getIt<FeatureAccess>().changes.where(
          (feature) => feature == AppFeature.ownSounds,
        ),
        keepOnlyOurs: () async => getIt<OwnSoundLockFlag>().keepOnlyFor(
          accountTagFor(
            (await getIt<DeviceIdentityStore>().readOrCreate()).accountId,
          ),
        ),
        readWritten: () => getIt<OwnSoundLockFlag>().written,
        write: ({required locked}) =>
            getIt<OwnSoundLockFlag>().write(locked: locked),
        // The iOS notification extension reads its own copy of the choices.
        // Android reads the flag where it is written, so there is nothing
        // to copy and nothing to retry.
        publish: () async =>
            !getIt<PlatformCapabilities>().isIos ||
            await getIt<SoundHost>().publishSoundAssignments(),
      ),
    );
}

/// The shared file that waits for setup and for the alarm to stop.
void registerIncomingAudio(GetIt getIt) {
  // "Share to Crit Alarm". Holds a shared file until onboarding is done and
  // no alarm is going off.
  getIt.registerLazySingleton(
    () => IncomingAudio(
      // Both platforms copy a share into incoming_audio under the app's
      // cache. Only a file there may be opened, and then deleted.
      isShareCopy: (path) async => isShareCopyPath(
        path,
        folder: p.join(
          (await getApplicationCacheDirectory()).path,
          shareCopyFolderName,
        ),
      ),
      canImportSounds: () async =>
          (await getIt<SoundHost>().capabilities()).canImportSounds,
      readOwnSounds: () => ownSoundsOnceReady(getIt<FeatureAccess>()),
      isOnboardingDone: () async =>
          (await getIt<GetOnboardingCompletedUsecase>()(
            const NoParams(),
          )).getOrNull() ??
          false,
      isRinging: getIt<AlarmHost>().isRinging,
      discard: getIt<SoundFilePicker>().discard,
      platform: defaultTargetPlatform,
    ),
  );
}
