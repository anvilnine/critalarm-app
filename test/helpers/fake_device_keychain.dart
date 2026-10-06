import 'dart:convert';

import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// One call that crossed the identity channel.
final class KeychainCall {
  const KeychainCall({
    required this.method,
    required this.service,
    required this.synchronizable,
    this.value,
  });
  final String method;
  final String service;

  /// Exactly what Dart asked for: true, false, or "any".
  final Object? synchronizable;
  final String? value;

  @override
  String toString() => '$method $service sync=$synchronizable';
}

/// Stands in for the iOS Keychain.
///
/// Items are held under the service *and* the `kSecAttrSynchronizable` value
/// they were written with, because that attribute is part of the real
/// Keychain's lookup. A read asking for "any" finds either copy, which is the
/// only way the old single item stays reachable after the split.
final class FakeDeviceKeychain {
  static const channel = MethodChannel('app.critalarm/device_identity');

  static const String accountService =
      KeychainDeviceIdentityStore.accountService;
  static const String deviceService =
      KeychainDeviceIdentityStore.deviceService;

  final Map<String, String> items = {};
  final List<KeychainCall> calls = [];

  /// Makes every write answer the way a locked Keychain does.
  bool failWrite = false;

  void install() => TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger
      .setMockMethodCallHandler(channel, _handle);

  void remove() => TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null);

  List<KeychainCall> get writes =>
      calls.where((call) => call.method == 'write').toList();

  List<KeychainCall> get deletes =>
      calls.where((call) => call.method == 'delete').toList();

  static String _key(String service, Object? synchronizable) =>
      '$service|$synchronizable';

  Map<String, dynamic>? item(String service, Object? synchronizable) {
    final raw = items[_key(service, synchronizable)];
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  Map<String, dynamic>? get account => item(accountService, true);
  Map<String, dynamic>? get device => item(deviceService, false);

  /// The one synced item an install written before the split is holding.
  void seedCombined({
    required String deviceId,
    String? deviceToken,
    String? accountId,
    String tier = 'free',
    String? accountJoinToken,
  }) => items[_key(deviceService, true)] = jsonEncode({
    'device_id': deviceId,
    'device_token': deviceToken,
    'account_id': accountId,
    'account_tier': tier,
    'caps': <String, dynamic>{},
    'account_join_token': ?accountJoinToken,
  });

  void seedAccount({required String accountId, String? joinToken}) =>
      items[_key(accountService, true)] = jsonEncode({
        'account_id': accountId,
        'account_join_token': joinToken,
      });

  void seedDevice({
    required String deviceId,
    String? deviceToken,
    String? accountId,
    String tier = 'free',
  }) => items[_key(deviceService, false)] = jsonEncode({
    'device_id': deviceId,
    'device_token': deviceToken,
    'account_id': accountId,
    'account_tier': tier,
    'caps': <String, dynamic>{},
  });

  Future<Object?> _handle(MethodCall call) async {
    final args = (call.arguments as Map).cast<String, Object?>();
    final service = args['service']! as String;
    final sync = args['synchronizable'];
    calls.add(
      KeychainCall(
        method: call.method,
        service: service,
        synchronizable: sync,
        value: args['value'] as String?,
      ),
    );
    switch (call.method) {
      case 'read':
        if (sync == KeychainDeviceIdentityStore.anySync) {
          return items[_key(service, true)] ?? items[_key(service, false)];
        }
        return items[_key(service, sync)];
      case 'write':
        if (failWrite) throw PlatformException(code: 'keychain_write');
        items[_key(service, sync)] = args['value']! as String;
        return null;
      case 'delete':
        items.remove(_key(service, sync));
        return null;
    }
    throw MissingPluginException(call.method);
  }
}
