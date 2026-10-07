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
    required UiSoundPlayer player,
    required bool Function() isSwitchOn,
    required bool Function() isAlarmUp,
    Iterable<Stream<Object?>> alarmStarts = const [],
    void Function()? haptic,
  }) : _player = player,
       _isSwitchOn = isSwitchOn,
       _isAlarmUp = isAlarmUp,
       _haptic = haptic {
    for (final starts in alarmStarts) {
      _subs.add(starts.listen((_) => _player.stop()));
    }
  }

  final UiSoundPlayer _player;
  final bool Function() _isSwitchOn;
  final bool Function() _isAlarmUp;
  final void Function()? _haptic;
  final _subs = <StreamSubscription<Object?>>[];

  void _cue(PaywallCueSound sound) {
    final mayPlay = paywallCueMayPlay(
      isSwitchOn: _isSwitchOn(),
      isAlarmUp: _isAlarmUp(),
    );
    if (!mayPlay) return;
    // Not awaited and not held back: the player cuts off whatever is still
    // playing, so a second cue never waits for the first.
    _player.play(sound.asset);
    _haptic?.call();
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
