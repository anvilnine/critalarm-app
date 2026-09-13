import 'dart:async';

import 'package:critalarm/core/push/push_deep_link.dart';
import 'package:flutter/services.dart';

/// The native half of the iOS push path, reached over one method channel.
///
/// `AppDelegate.swift` owns the APNs registration, the INCIDENT category, the
/// badge and the ack the notification action queues. Dart owns the relay
/// registration, the route a tap opens and the retry loop for a queued ack.
/// Everything that crosses between the two goes through here.
///
/// Off iOS every call is a no-op: the channel has no handler, so the platform
/// answers [MissingPluginException] and this hands back null.
final class PushHost {
  PushHost([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_handle);
  }

  static const channelName = 'app.critalarm/push';

  final MethodChannel _channel;
  final _tokens = StreamController<String>.broadcast();
  final _routes = StreamController<String>.broadcast();
  final _acks = StreamController<String>.broadcast();

  /// APNs tokens handed out after launch. The first one arrives through
  /// [apnsToken]; this carries the rotations.
  Stream<String> get tokenRefreshes => _tokens.stream;

  /// Routes from a notification the user tapped while the app was running.
  Stream<String> get deepLinks => _routes.stream;

  /// Incident ids the ACK action queued natively. Dart flushes the queue when
  /// one lands, so the send goes out without waiting for the next launch.
  Stream<String> get queuedAcks => _acks.stream;

  /// The current APNs token, or null before APNs has handed one out.
  Future<String?> apnsToken() => _invoke<String>('getApnsToken');

  /// Whatever arrived before Dart was listening, taken once at startup.
  ///
  /// A cold launch from a tapped notification lands here: the route it wants
  /// is the app's first screen. Any ack the ACK action queued is reported on
  /// [queuedAcks] so the send goes out with the rest.
  Future<String?> takePendingRoute() async {
    final pending = await _invoke<Map<Object?, Object?>>('takePending');
    if (pending == null) return null;

    final ack = pending['ack'];
    if (ack is String && ack.isNotEmpty) _acks.add(ack);

    final tap = pending['tap'];
    if (tap is! Map) return null;
    return PushDeepLink.fromNotificationData({
      for (final entry in tap.entries)
        if (entry.value != null) '${entry.key}': '${entry.value}',
    });
  }

  /// Sets the number on the app icon. Zero clears it.
  Future<void> setBadgeCount(int count) =>
      _invoke<void>('setBadgeCount', {'count': count});

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<void> _handle(MethodCall call) async {
    switch (call.method) {
      case 'onApnsToken':
        final token = call.arguments as String?;
        if (token != null && token.isNotEmpty) _tokens.add(token);
      case 'onNotificationTap':
        final route = PushDeepLink.fromNotificationData(_stringMap(call));
        if (route != null) _routes.add(route);
      case 'onAckQueued':
        final id = call.arguments as String?;
        if (id != null && id.isNotEmpty) _acks.add(id);
    }
  }

  static Map<String, String> _stringMap(MethodCall call) {
    final raw = call.arguments;
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        if (entry.value != null) '${entry.key}': '${entry.value}',
    };
  }

  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _tokens.close();
    await _routes.close();
    await _acks.close();
  }
}
