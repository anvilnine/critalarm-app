import 'dart:async';

import 'package:flutter/services.dart';

/// Plays one short interface sound at a time.
abstract interface class UiSoundPlayer {
  /// Plays the bundled [asset] once. A sound still playing is cut off and
  /// replaced: nothing is ever queued.
  void play(String asset);

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
  void play(String asset) => unawaited(_invoke('play', {'asset': asset}));

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
