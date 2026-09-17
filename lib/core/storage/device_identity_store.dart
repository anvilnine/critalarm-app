import 'dart:convert';

import 'package:critalarm/core/models/device_identity.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdentityStore {
  DeviceIdentityStore(SharedPreferences prefs) : _prefs = prefs;

  factory DeviceIdentityStore.forPlatform(SharedPreferences prefs) =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
      ? KeychainDeviceIdentityStore(prefs)
      : DeviceIdentityStore(prefs);

  final SharedPreferences _prefs;
  static const legacyKeys = [
    'device_id',
    'device_token',
    'account_id',
    'account_tier',
    'account_caps',
  ];

  DeviceIdentity? _readLegacy() {
    final id = _prefs.getString('device_id');
    if (id == null) return null;
    return DeviceIdentity(
      deviceId: id,
      deviceToken: _prefs.getString('device_token'),
      accountId: _prefs.getString('account_id'),
      tier: _prefs.getString('account_tier') ?? 'free',
      caps: AccountCaps.fromJson(
        jsonDecode(_prefs.getString('account_caps') ?? '{}')
            as Map<String, dynamic>,
      ),
    );
  }

  Future<DeviceIdentity> readOrCreate() async {
    final existing = _readLegacy();
    if (existing != null) return existing;
    final identity = DeviceIdentity(deviceId: 'dev_${const Uuid().v4()}');
    await _prefs.setString('device_id', identity.deviceId);
    return identity;
  }

  /// Throws away this phone's credential and gives it a brand new device id.
  ///
  /// Signing out has to do both. api.md §3.7: dropping `dv_` while keeping the
  /// old device id is a permanent 401, because the app only POSTs a
  /// registration when it has no token, and registering a device id the server
  /// already knows needs the token that was just thrown away.
  Future<DeviceIdentity> resetIdentity() async {
    for (final key in legacyKeys) {
      await _prefs.remove(key);
    }
    final identity = DeviceIdentity(deviceId: 'dev_${const Uuid().v4()}');
    await _prefs.setString('device_id', identity.deviceId);
    return identity;
  }

  Future<void> saveRegistration({
    required String deviceToken,
    required String accountId,
    required String tier,
    AccountCaps caps = const AccountCaps(),
  }) async {
    if (deviceToken.trim().isEmpty) throw StateError('Empty device token');
    await _prefs.setString('device_token', deviceToken);
    await _prefs.setString('account_id', accountId);
    await _prefs.setString('account_tier', tier);
    await _prefs.setString('account_caps', jsonEncode(caps.toJson()));
  }
}

/// A single Keychain item keeps the id and its credential together.
final class KeychainDeviceIdentityStore extends DeviceIdentityStore {
  KeychainDeviceIdentityStore(
    super.prefs, {
    this.channel = const MethodChannel('app.critalarm/device_identity'),
  });
  final MethodChannel channel;

  Future<void> _write(DeviceIdentity identity) => channel.invokeMethod<void>(
    'write',
    jsonEncode({
      'device_id': identity.deviceId,
      'device_token': identity.deviceToken,
      'account_id': identity.accountId,
      'account_tier': identity.tier,
      'caps': identity.caps.toJson(),
    }),
  );

  @override
  Future<DeviceIdentity> readOrCreate() async {
    final raw = await channel.invokeMethod<String>('read');
    final DeviceIdentity identity;
    if (raw != null) {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      identity = DeviceIdentity(
        deviceId: data['device_id'] as String,
        deviceToken: data['device_token'] as String?,
        accountId: data['account_id'] as String?,
        tier: data['account_tier'] as String,
        caps: AccountCaps.fromJson(data['caps'] as Map<String, dynamic>? ?? {}),
      );
    } else {
      identity =
          _readLegacy() ?? DeviceIdentity(deviceId: 'dev_${const Uuid().v4()}');
      await _write(identity);
    }
    // Only remove the old copy after the Keychain write succeeds. If cleanup
    // was interrupted, the Keychain copy wins on the next launch.
    for (final key in DeviceIdentityStore.legacyKeys) {
      await _prefs.remove(key);
    }
    return identity;
  }

  @override
  Future<DeviceIdentity> resetIdentity() async {
    final identity = DeviceIdentity(deviceId: 'dev_${const Uuid().v4()}');
    await _write(identity);
    for (final key in DeviceIdentityStore.legacyKeys) {
      await _prefs.remove(key);
    }
    return identity;
  }

  @override
  Future<void> saveRegistration({
    required String deviceToken,
    required String accountId,
    required String tier,
    AccountCaps caps = const AccountCaps(),
  }) async {
    if (deviceToken.trim().isEmpty) throw StateError('Empty device token');
    final identity = await readOrCreate();
    await _write(
      DeviceIdentity(
        deviceId: identity.deviceId,
        deviceToken: deviceToken,
        accountId: accountId,
        tier: tier,
        caps: caps,
      ),
    );
  }
}
