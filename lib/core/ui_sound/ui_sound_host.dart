import 'dart:async';

import 'package:flutter/services.dart';

/// Plays short interface sounds, one at a time unless told otherwise.
abstract interface class UiSoundPlayer {
  /// Plays the bundled [asset] once. A sound still playing is cut off and
  /// replaced: nothing is ever queued.
  ///
  /// With [voices] above one, copies of the same [asset] already playing are
  /// left to finish, up to that many at once with the new one. The oldest
  /// goes first. A different sound is still cut off.
  void play(String asset, {int voices = 1});

  /// Stops whatever is playing. Safe to call when nothing is.
  void stop();
}

/// The native player for interface sounds, on its own channel.
///
/// It is not the sound picker's preview and it is not the alarm. Android
/// plays on the media stream and iOS on the ambient audio category, so a
/// sound follows the media volume and the silent switch, and neither side
/// reads or sets the alarm volume. The native side only opens files under
/// [assetFolder], so this channel cannot be asked for an alarm sound.
///
/// Every call is safe off a real device: with no handler on the channel the
/// platform answers [MissingPluginException] and nothing plays.
final class UiSoundHost implements UiSoundPlayer {
  UiSoundHost([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'app.critalarm/ui_sound';

  /// The only folder the native side will play from.
  static const assetFolder = 'assets/ui_sounds/';

  final MethodChannel _channel;

  @override
  void play(String asset, {int voices = 1}) =>
      unawaited(_invoke('play', {'asset': asset, 'voices': voices}));

  @override
  void stop() => unawaited(_invoke('stop'));

  Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<Object?>(method, arguments);
    } on MissingPluginException {
      // No native player on this platform. Stay silent.
    } on PlatformException {
      // A sound that will not play is never worth an error on screen.
    }
  }
}
