import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/sound/bundled_sounds.dart';
import 'package:critalarm/core/sound/sound_assignments.dart';

/// Every sound a person brought in themselves (a picked file, a recording,
/// a cropped clip, a file shared in) has an id that starts with this.
///
/// Android (`AlarmSoundStore.OWN_PREFIX`) and iOS
/// (`SharedSounds.ownSoundPrefix`) hold the same word. Keep the three in
/// step.
const String ownSoundIdPrefix = 'user_';

/// The prefs key of the one flag native code reads to know that own sounds
/// are locked. It sits next to the sound choices, and native reads it as
/// `flutter.alarm_sound_own_locked`. Native never works out a plan.
const String ownSoundsLockedKey = 'alarm_sound_own_locked';

bool isOwnSoundId(String soundId) => soundId.startsWith(ownSoundIdPrefix);

/// Whether [decision] locks own sounds. Only a sure "locked" does: a
/// purchase being confirmed and a plan that could not be read both leave
/// own sounds as they are.
bool ownSoundsLockedBy(FeatureDecision decision) => decision is FeatureLocked;

/// The decision for own sounds, asked once the access layer has read the
/// plan and the saved server. Never throws: a plan that could not be read
/// comes back as [FeatureUnread], which locks nothing.
///
/// For a gate that decides once and does not listen for changes: a route
/// guard, a file shared in, the save itself. Asked before the layer is
/// ready, a plain `decide` can say "locked" to someone who holds Pro.
Future<FeatureDecision> ownSoundsOnceReady(FeatureAccess access) async {
  await access.ready;
  return access.decide(AppFeature.ownSounds);
}

/// Where a route that makes an own sound goes while they are locked, or
/// null to let it open. A deep link or a restored route lands on
/// [soundList], where the sounds show as locked and every way in opens
/// the paywall.
Future<String?> ownSoundsRouteRedirect(
  FeatureAccess access, {
  required String soundList,
}) async =>
    ownSoundsLockedBy(await ownSoundsOnceReady(access)) ? soundList : null;

/// What really rings, given what is saved and whether own sounds are
/// locked.
///
/// The saved choices are never changed by a lock. This is the one place in
/// Dart that says what a locked own sound turns into, and it always ends at
/// a sound that is not an own sound:
///
/// - Open: the saved choice rings, own sounds included.
/// - Locked, and the choice is not an own sound: the saved choice rings.
/// - Locked, and the choice is an own sound: the phone's default rings when
///   that is not an own sound itself, else the bundled classic siren.
///
/// Android (`AlarmSoundStore.resolveChain`) and iOS
/// (`SharedSounds.choicesToPublish`, `SharedSounds.fileName`) apply the same
/// rule from the flag. Native then still checks that the file is there.
abstract final class OwnSoundRule {
  /// The id that rings for [topicName], or for the default when it is null.
  static String ringingSoundId({
    required SoundAssignments saved,
    required bool ownSoundsLocked,
    String? topicName,
  }) {
    final chosen = topicName == null
        ? saved.defaultSoundId
        : saved.soundIdFor(topicName);
    if (!ownSoundsLocked || !isOwnSoundId(chosen)) return chosen;
    return ringingDefaultId(saved: saved, ownSoundsLocked: ownSoundsLocked);
  }

  /// The id that rings for a topic with no choice of its own.
  static String ringingDefaultId({
    required SoundAssignments saved,
    required bool ownSoundsLocked,
  }) {
    final chosen = saved.defaultSoundId;
    if (!ownSoundsLocked || !isOwnSoundId(chosen)) return chosen;
    return BundledSounds.fallbackId;
  }

  /// [saved] as it rings: every topic and the default run through
  /// [ringingSoundId]. A new value, so [saved] stays as it was.
  static SoundAssignments ringing({
    required SoundAssignments saved,
    required bool ownSoundsLocked,
  }) => SoundAssignments(
    defaultSoundId: ringingDefaultId(
      saved: saved,
      ownSoundsLocked: ownSoundsLocked,
    ),
    perTopic: {
      for (final topic in saved.perTopic.keys)
        topic: ringingSoundId(
          saved: saved,
          ownSoundsLocked: ownSoundsLocked,
          topicName: topic,
        ),
    },
  );
}
