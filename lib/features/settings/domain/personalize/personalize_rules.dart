import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
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

/// The chips of the Sound strip, in order: [current] with the tick, then
/// [builtIns]. "Yours" and the chip that opens the full picker come after
/// and are always there.
@immutable
final class SoundStrip {
  const SoundStrip({
    required this.current,
    required this.builtIns,
    required this.newestOwn,
  });

  /// The default sound as saved: what really rings. Null only when its id
  /// names no sound on this phone.
  final AlarmSound? current;

  /// A few built-in sounds, without [current].
  final List<AlarmSound> builtIns;

  /// The newest sound the user brought in, which "Yours" plays. Null when
  /// there is none.
  final AlarmSound? newestOwn;

  /// Whether the sound that rings now is one the user brought in.
  bool get currentIsOwn => current?.source == AlarmSoundSource.user;
}

/// How many built-in sounds the strip shows beside the current one.
const int soundStripBuiltIns = 3;

/// Builds the Sound strip.
///
/// The strip leads with what is saved and never with what a plan would
/// allow: the page shows what will really ring. [builtIn] is the bundled
/// catalogue in its own order, [userSounds] the user's own, oldest first,
/// and [others] anything else that can be the default (a pack sound).
SoundStrip soundStripFor({
  required List<AlarmSound> builtIn,
  required List<AlarmSound> userSounds,
  required String defaultId,
  List<AlarmSound> others = const [],
  int builtInCount = soundStripBuiltIns,
}) {
  AlarmSound? current;
  for (final sound in [...builtIn, ...others, ...userSounds]) {
    if (sound.id == defaultId) {
      current = sound;
      break;
    }
  }
  return SoundStrip(
    current: current,
    builtIns: builtIn
        .where((sound) => sound.id != defaultId)
        .take(builtInCount)
        .toList(growable: false),
    newestOwn: userSounds.isEmpty ? null : userSounds.last,
  );
}

/// What a tap on "Yours" does once own sounds are usable.
enum YoursTap {
  /// Makes the newest own sound the default and plays it.
  pickNewest,

  /// Opens the full sound picker, where a sound is added or another one
  /// picked.
  openPicker,
}

/// With an own sound to pick that is not ringing already, the tap picks
/// it. With none, or with one already the default, it opens the picker.
YoursTap yoursTapFor(SoundStrip strip) =>
    strip.newestOwn != null && !strip.currentIsOwn
    ? YoursTap.pickNewest
    : YoursTap.openPicker;

/// The text size from which the page gives the preview less room and lets
/// chip labels wrap.
const double personalizeLargeText = 1.3;

/// How tall the preview is on an upright phone: a third of the screen, and
/// a quarter at large text, where the choices need the room.
double personalizePreviewHeight({
  required double viewportHeight,
  required double textScale,
}) =>
    textScale >= personalizeLargeText ? viewportHeight / 4 : viewportHeight / 3;

/// Whether the preview sits beside the choices: a tablet or a phone on its
/// side. [mediumMinWidth] is the design system's breakpoint.
bool personalizeIsWide({
  required double width,
  required double height,
  required double mediumMinWidth,
}) => width >= mediumMinWidth && width > height;
