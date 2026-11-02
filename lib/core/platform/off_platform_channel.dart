import 'package:flutter/services.dart';

/// A method channel whose native half this build does not have.
///
/// Every host that talks to a native channel already treats
/// [MissingPluginException] as "not on this platform" and hands back a safe
/// default. This channel throws that exception itself, so the call never
/// leaves Dart. `lib/app/di.dart` gives one to each host whose native half
/// exists on the phones only, when the app runs on a Mac.
///
/// Incoming calls are never delivered, because nothing native can send them.
class OffPlatformChannel extends MethodChannel {
  const OffPlatformChannel(super.name);

  /// How many calls were stopped here, across every instance. Lets a test
  /// prove that a host on this channel sent nothing to the platform.
  static int stoppedCalls = 0;

  MissingPluginException _missing(String method) {
    stoppedCalls++;
    return MissingPluginException(
      'No implementation for $method on channel $name on this platform',
    );
  }

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) =>
      Future.error(_missing(method));

  @override
  Future<List<T>?> invokeListMethod<T>(String method, [dynamic arguments]) =>
      Future.error(_missing(method));

  @override
  Future<Map<K, V>?> invokeMapMethod<K, V>(
    String method, [
    dynamic arguments,
  ]) => Future.error(_missing(method));

  @override
  void setMethodCallHandler(
    Future<dynamic> Function(MethodCall call)? handler,
  ) {}
}

/// The event channel twin of [OffPlatformChannel]. Its stream fails at once
/// with [MissingPluginException], which is what a stream on a channel with no
/// native half does on its first listen.
class OffPlatformEventChannel extends EventChannel {
  const OffPlatformEventChannel(super.name);

  @override
  Stream<dynamic> receiveBroadcastStream([dynamic arguments]) {
    OffPlatformChannel.stoppedCalls++;
    return Stream<dynamic>.error(
      MissingPluginException(
        'No implementation for listen on channel $name on this platform',
      ),
    );
  }
}
