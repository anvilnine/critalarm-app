import 'dart:async';

import 'package:flutter/services.dart';

/// Tells the iPhone when the app's own incident screen starts and stops
/// ringing, so it can go to full brightness and vibrate on the beat of the
/// sound (`RingScreenEffects.swift`).
///
/// Only the screen's own time is covered. The AlarmKit alert is system UI,
/// and no app sets its brightness or its vibration. The two switches in
/// Settings are read by the native side at every start, so this passes
/// nothing about them.
///
/// Off iOS ([isIos] false) every call does nothing and the channel is never
/// touched. Android does the same job in its alarm code.
final class RingScreenHost {
  RingScreenHost({required this.isIos, MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'app.critalarm/ring_screen';

  /// The native iOS app, never a browser (`PlatformCapabilities.isIos`).
  final bool isIos;

  final MethodChannel _channel;

  /// The screen rings. [topic] picks the pattern that goes with the sound
  /// that rings for it. Calling again, for another incident, replaces the
  /// pattern.
  Future<void> start({required String? topic}) =>
      _invoke('start', {'topic': topic});

  /// The screen stopped ringing, was covered, or went away.
  Future<void> stop() => _invoke('stop');

  Future<void> _invoke(String method, [Object? arguments]) async {
    if (!isIos) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}
