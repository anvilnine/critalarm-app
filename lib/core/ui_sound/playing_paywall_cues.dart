import 'dart:async';

import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/ui_sound/intro_sound_flavour.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/core/ui_sound/ui_sound_host.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;

/// Whether this build has a native player for interface sounds. iOS and
/// Android do. The web build and everything else stay silent.
bool platformPlaysUiSounds(PlatformCapabilities capabilities) =>
    !capabilities.isWeb &&
    (capabilities.platform == TargetPlatform.iOS ||
        capabilities.platform == TargetPlatform.android);

/// The cues a build is wired with: the playing ones where the platform can
/// play, the silent ones everywhere else. [playing] is only built when used.
PaywallCues paywallCuesFor(
  PlatformCapabilities capabilities, {
  required PaywallCues Function() playing,
}) =>
    platformPlaysUiSounds(capabilities) ? playing() : const SilentPaywallCues();

/// The mute rule. A cue plays only with the Interface sounds switch on and
/// no alarm under way. The same answer decides the haptic.
bool paywallCueMayPlay({
  required bool isSwitchOn,
  required bool isAlarmUp,
}) => isSwitchOn && !isAlarmUp;

/// How many haptics one cue may give in a run when the screen plays it by
/// itself. The sound goes on; the hand feels the first three and no more, so
/// a run of receipt lines never turns into a buzz.
const paywallCueTapsPerRun = 3;

/// Two of the same cue closer than this are one run.
const paywallCueRunGap = Duration(milliseconds: 250);

/// Whether the haptic of [cue] may fire when [earlierInRun] of the same cue
/// came just before it.
///
/// A cue with no sound is touch only and follows the finger, one tick for
/// each notch, the way a picker wheel does. It is never held back.
bool paywallCueTapMayFire(PaywallCue cue, {required int earlierInRun}) {
  if (cue.haptic == HapticPattern.none) return false;
  if (cue.asset == null) return true;
  return earlierInRun < paywallCueTapsPerRun;
}

/// Plays the paywall cues: a short interface sound and its haptic, together.
///
/// - The Interface sounds switch off means no sound and no haptic.
/// - While an alarm is under way nothing plays, and a cue already playing is
///   stopped the moment one starts, with the rest of its haptic.
/// - A new cue replaces the one still playing. Nothing queues. A cue marked
///   [PaywallCue.mayRepeat] may overlap itself a little, so five quick ones
///   are all heard.
/// - A cue that is touch only leaves the sound that is playing alone.
final class PlayingPaywallCues extends PaywallCues {
  PlayingPaywallCues({
    required this.player,
    required this.isSwitchOn,
    required this.isAlarmUp,
    Iterable<Stream<Object?>> alarmStarts = const [],
    this.haptic,
    this.cancelHaptic,
    this.introFlavour,
    Duration Function()? clock,
  }) : _clock = clock ?? _stopwatchClock() {
    for (final starts in alarmStarts) {
      _subs.add(
        starts.listen((_) {
          player.stop();
          cancelHaptic?.call();
        }),
      );
    }
  }

  final UiSoundPlayer player;

  /// The Interface sounds switch, read at every cue.
  final bool Function() isSwitchOn;

  /// Whether an alarm is under way on this phone, read at every cue.
  final bool Function() isAlarmUp;

  /// Plays a cue's haptic. Null where there are no haptics.
  final void Function(HapticPattern pattern)? haptic;

  /// Drops what is left of a haptic under way, when an alarm starts.
  final void Function()? cancelHaptic;

  /// Which flavour the intro scores play in, read at every cue. Null plays
  /// the first one.
  final IntroSoundFlavour Function()? introFlavour;

  final Duration Function() _clock;
  final _subs = <StreamSubscription<Object?>>[];

  PaywallCue? _lastCue;
  Duration _lastAt = Duration.zero;
  int _earlierInRun = 0;

  static Duration Function() _stopwatchClock() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }

  @override
  void play(PaywallCue cue) {
    final mayPlay = paywallCueMayPlay(
      isSwitchOn: isSwitchOn(),
      isAlarmUp: isAlarmUp(),
    );
    if (!mayPlay) return;
    final asset = cue.hasFlavours && introFlavour != null
        ? cue.assetIn(introFlavour!())
        : cue.asset;
    // Not awaited and not held back: the player cuts off whatever is still
    // playing, so a second cue never waits for the first.
    if (asset != null) player.play(asset, voices: cue.voices);

    final now = _clock();
    final isSameRun = cue == _lastCue && now - _lastAt < paywallCueRunGap;
    _earlierInRun = isSameRun ? _earlierInRun + 1 : 0;
    _lastCue = cue;
    _lastAt = now;
    if (paywallCueTapMayFire(cue, earlierInRun: _earlierInRun)) {
      haptic?.call(cue.haptic);
    }
  }

  Future<void> dispose() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
  }
}
