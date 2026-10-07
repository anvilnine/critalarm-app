import 'dart:async';

import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/core/ui_sound/ui_sound_host.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;

/// One sound file per cue. A plan pick has two, so the two plans differ.
///
/// These are interface sounds made for the paywall. None is one of the
/// app's alarm sounds, and they live in their own folder so the sound picker
/// never lists them.
enum PaywallCueSound {
  open('ui_open'),
  gag('ui_gag'),
  print('ui_print'),
  tick('ui_tick'),
  pickYearly('ui_pick_yearly'),
  pickMonthly('ui_pick_monthly'),
  bought('ui_buy'),
  close('ui_close');

  const PaywallCueSound(this.fileName);

  final String fileName;

  /// The Flutter asset the native player is handed.
  String get asset => '${UiSoundHost.assetFolder}$fileName.m4a';
}

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
/// no alarm under way. The same answer decides the light tap.
bool paywallCueMayPlay({
  required bool isSwitchOn,
  required bool isAlarmUp,
}) => isSwitchOn && !isAlarmUp;

/// Plays the paywall cues as short interface sounds.
///
/// - The Interface sounds switch off means no sound and no tap.
/// - While an alarm is under way nothing plays, and a cue already playing is
///   stopped the moment one starts.
/// - A new cue replaces the one still playing. Nothing queues.
/// - Each cue that plays comes with one light tap, where [haptic] is given.
final class PlayingPaywallCues implements PaywallCues {
  PlayingPaywallCues({
    required this.player,
    required this.isSwitchOn,
    required this.isAlarmUp,
    Iterable<Stream<Object?>> alarmStarts = const [],
    this.haptic,
  }) {
    for (final starts in alarmStarts) {
      _subs.add(starts.listen((_) => player.stop()));
    }
  }

  final UiSoundPlayer player;

  /// The Interface sounds switch, read at every cue.
  final bool Function() isSwitchOn;

  /// Whether an alarm is under way on this phone, read at every cue.
  final bool Function() isAlarmUp;

  /// The light tap that goes with a cue. Null where there are no haptics.
  final void Function()? haptic;

  final _subs = <StreamSubscription<Object?>>[];

  void _cue(PaywallCueSound sound) {
    final mayPlay = paywallCueMayPlay(
      isSwitchOn: isSwitchOn(),
      isAlarmUp: isAlarmUp(),
    );
    if (!mayPlay) return;
    // Not awaited and not held back: the player cuts off whatever is still
    // playing, so a second cue never waits for the first.
    player.play(sound.asset);
    haptic?.call();
  }

  @override
  void open() => _cue(PaywallCueSound.open);

  @override
  void gag() => _cue(PaywallCueSound.gag);

  @override
  void print() => _cue(PaywallCueSound.print);

  @override
  void tick() => _cue(PaywallCueSound.tick);

  @override
  void pickPlan({required bool yearly}) =>
      _cue(yearly ? PaywallCueSound.pickYearly : PaywallCueSound.pickMonthly);

  @override
  void bought() => _cue(PaywallCueSound.bought);

  @override
  void close() => _cue(PaywallCueSound.close);

  Future<void> dispose() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
  }
}
