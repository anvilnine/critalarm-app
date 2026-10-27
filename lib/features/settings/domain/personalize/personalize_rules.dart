import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/own_sound_rule.dart';
import 'package:critalarm/core/sound/sound_assignments.dart';
import 'package:flutter/foundation.dart';

// The rules of the Personalize page, with nothing drawn. Pure, so they are
// unit tested and the widgets only draw what they are handed.

/// A locked option that is being tried in the preview. It is not saved.
@immutable
final class PersonalizeTry {
  const PersonalizeTry(this.feature, {this.optionId});

  /// The feature the option belongs to.
  final AppFeature feature;

  /// Which option of that feature, where it has more than one: a sound id,
  /// a look, a challenge. Null when there is nothing to tell apart.
  final String? optionId;

  @override
  bool operator ==(Object other) =>
      other is PersonalizeTry &&
      other.feature == feature &&
      other.optionId == optionId;

  @override
  int get hashCode => Object.hash(feature, optionId);

  @override
  String toString() => 'PersonalizeTry(${feature.name}, $optionId)';
}

/// The bar under the preview.
@immutable
sealed class TryBar {
  const TryBar();
}

/// No bar.
final class TryBarHidden extends TryBar {
  const TryBarHidden();

  @override
  bool operator ==(Object other) => other is TryBarHidden;

  @override
  int get hashCode => (TryBarHidden).hashCode;
}

/// A locked option is being tried: the plan badge, and one button that
/// opens the paywall for [feature].
final class TryBarSell extends TryBar {
  const TryBarSell(this.feature, this.offer);

  final AppFeature feature;
  final Holding offer;

  @override
  bool operator ==(Object other) =>
      other is TryBarSell && other.feature == feature && other.offer == offer;

  @override
  int get hashCode => Object.hash(TryBarSell, feature, offer);
}

/// A purchase of [holding] is being confirmed: one line, nothing to buy.
final class TryBarConfirming extends TryBar {
  const TryBarConfirming(this.holding);

  final Holding holding;

  @override
  bool operator ==(Object other) =>
      other is TryBarConfirming && other.holding == holding;

  @override
  int get hashCode => Object.hash(TryBarConfirming, holding);
}

/// What the bar under the preview shows.
///
/// - Trying a locked option: the bar that sells it.
/// - A purchase being confirmed for any feature on the page: the one line
///   that says so. The options it unlocks are already open.
/// - Otherwise nothing. A plan that could not be read sells nothing, and an
///   option that became open while it was being tried has nothing to sell.
TryBar tryBarFor({
  required PersonalizeTry? tried,
  required Map<AppFeature, FeatureDecision> decisions,
}) {
  final triedDecision = tried == null ? null : decisions[tried.feature];
  if (tried != null && triedDecision is FeatureLocked) {
    return TryBarSell(tried.feature, triedDecision.offer);
  }
  for (final decision in decisions.values) {
    if (decision is FeatureConfirming) {
      return TryBarConfirming(decision.holding);
    }
  }
  return const TryBarHidden();
}

/// Whether a try still stands: only while its feature is locked. Once the
/// plan arrives, or cannot be read, the option is a real choice.
bool tryStillStands(
  PersonalizeTry? tried,
  Map<AppFeature, FeatureDecision> decisions,
) => tried != null && decisions[tried.feature] is FeatureLocked;

/// The chips of the Sound strip, in order: [current] with the tick,
/// "Yours", then [builtIns], then the chip that opens the full picker.
/// "Yours" comes second so its lock shows without scrolling.
@immutable
final class SoundStrip {
  const SoundStrip({
    required this.current,
    required this.builtIns,
    required this.yours,
    required this.ownSoundsLocked,
  });

  /// The sound that really rings: the saved default, or what stands in for
  /// it while own sounds are locked. Null only when its id names no sound
  /// on this phone.
  final AlarmSound? current;

  /// A few built-in sounds, without [current].
  final List<AlarmSound> builtIns;

  /// The own sound "Yours" stands for: the saved default when that is an
  /// own sound, else the newest one. Null when the phone has none.
  final AlarmSound? yours;

  final bool ownSoundsLocked;

  /// Whether the sound that rings now is one the user brought in.
  bool get currentIsOwn => current?.source == AlarmSoundSource.user;
}

/// How many built-in sounds the strip shows beside the current one.
const int soundStripBuiltIns = 3;

/// Builds the Sound strip.
///
/// The tick sits on what really rings, which [OwnSoundRule] decides: with
/// own sounds locked, a saved own sound does not ring, so the tick moves
/// to the sound standing in for it and the saved one shows as the locked
/// "Yours" chip. The saved choice itself is never changed by a lock.
///
/// [builtIn] is the bundled catalogue in its own order, [userSounds] the
/// user's own, oldest first, and [others] anything else that can be the
/// default (a pack sound).
SoundStrip soundStripFor({
  required List<AlarmSound> builtIn,
  required List<AlarmSound> userSounds,
  required String defaultId,
  required bool ownSoundsLocked,
  List<AlarmSound> others = const [],
  int builtInCount = soundStripBuiltIns,
}) {
  AlarmSound? byId(String id) {
    for (final sound in [...builtIn, ...others, ...userSounds]) {
      if (sound.id == id) return sound;
    }
    return null;
  }

  final ringingId = OwnSoundRule.ringingDefaultId(
    saved: SoundAssignments(defaultSoundId: defaultId),
    ownSoundsLocked: ownSoundsLocked,
  );
  final saved = byId(defaultId);
  return SoundStrip(
    current: byId(ringingId),
    builtIns: builtIn
        .where((sound) => sound.id != ringingId)
        .take(builtInCount)
        .toList(growable: false),
    yours: saved != null && saved.source == AlarmSoundSource.user
        ? saved
        : (userSounds.isEmpty ? null : userSounds.last),
    ownSoundsLocked: ownSoundsLocked,
  );
}
