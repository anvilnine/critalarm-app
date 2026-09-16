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

  /// Key the platform stamps on a tap so the two ways it can reach Dart, live
  /// over the channel and pulled with [takePendingRoute], are recognised as
  /// the same tap.
  static const tapIdKey = 'tap_id';

  final MethodChannel _channel;
  final _tokens = StreamController<String>.broadcast();
  final _routes = StreamController<String>.broadcast();
  final _acks = StreamController<String>.broadcast();
  final _pushes = StreamController<void>.broadcast();

  /// The last tap the platform handed over. Both paths hold a tap until Dart
  /// takes it, so the same one can arrive twice; the second copy is dropped.
  String? _lastTapId;

  /// APNs tokens handed out after launch. The first one arrives through
  /// [apnsToken]; this carries the rotations.
  Stream<String> get tokenRefreshes => _tokens.stream;

  /// Routes from a notification the user tapped while the app was running.
  Stream<String> get deepLinks => _routes.stream;

  /// Incident ids the ACK action queued natively. Dart flushes the queue when
  /// one lands, so the send goes out without waiting for the next launch.
  Stream<String> get queuedAcks => _acks.stream;

  /// A push that arrived while the app was in front and the user has not
  /// touched. It carries nothing: what changed is on the server, and the
  /// shared incident list is what asks for it.
  Stream<void> get foregroundPushes => _pushes.stream;

  /// The current APNs token, or null before APNs has handed one out.
  Future<String?> apnsToken() => _invoke<String>('getApnsToken');

  /// Whatever the platform is still holding, taken once.
  ///
  /// Called twice: at startup, where a cold launch from a tapped notification
  /// gives the app its first screen, and again on every resume, where it is
  /// how a tap that woke the app is navigated before anything reloads. Any
  /// ack the ACK action queued is reported on [queuedAcks] so the send goes
  /// out with the rest.
  ///
  /// Null when the platform has nothing, and null when what it has is the tap
  /// that already came over the channel.
  Future<String?> takePendingRoute() async {
    final pending = await _invoke<Map<Object?, Object?>>('takePending');
    if (pending == null) return null;

    final ack = pending['ack'];
    if (ack is String && ack.isNotEmpty) _acks.add(ack);

    final tap = pending['tap'];
    if (tap is! Map) return null;
    final data = {
      for (final entry in tap.entries)
        if (entry.value != null) '${entry.key}': '${entry.value}',
    };
    if (_isRepeatTap(data)) return null;
    return PushDeepLink.fromNotificationData(data);
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
        final data = _stringMap(call);
        if (_isRepeatTap(data)) return;
        final route = PushDeepLink.fromNotificationData(data);
        if (route != null) _routes.add(route);
      case 'onAckQueued':
        final id = call.arguments as String?;
        if (id != null && id.isNotEmpty) _acks.add(id);
      case 'onPushReceived':
        _pushes.add(null);
    }
  }

  /// True when this is the tap Dart already handled. The platform keeps a tap
  /// until it is taken and also sends it live, so one tap can arrive twice;
  /// only the first copy opens a screen.
  bool _isRepeatTap(Map<String, String> data) {
    final id = data[tapIdKey];
    if (id == null) return false;
    if (id == _lastTapId) return true;
    _lastTapId = id;
    return false;
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
    await _pushes.close();
  }
}
