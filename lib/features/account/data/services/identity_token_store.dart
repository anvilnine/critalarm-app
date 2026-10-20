import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the sign-in session token our server issued is kept.
///
/// The token stands for the person's account on our server, so it is the
/// one value here that must not ride along in a backup. On Android the
/// preferences already stay out of every backup and transfer
/// (`data_extraction_rules.xml`). On iOS the preferences go into iCloud and
/// computer backups, so the token lives in the Keychain instead.
abstract interface class IdentityTokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// The preferences key the token was kept under, and still is off iOS.
const identitySessionTokenKey = 'identity_session_token';

final class PrefsIdentityTokenStore implements IdentityTokenStore {
  const PrefsIdentityTokenStore(this.prefs);

  final SharedPreferences prefs;

  @override
  Future<String?> read() async => prefs.getString(identitySessionTokenKey);

  @override
  Future<void> write(String token) =>
      prefs.setString(identitySessionTokenKey, token);

  @override
  Future<void> clear() => prefs.remove(identitySessionTokenKey);
}

/// iOS: an unsynced Keychain item that is ThisDeviceOnly, through the same
/// channel as the device identity (`DeviceIdentityKeychain` in
/// `AppDelegate.swift`). It is in no backup, in no iCloud Keychain and in no
/// phone to phone transfer, so a restored or moved phone signs in again.
///
/// Nothing outside the app reads it. The extension and the widgets fetch
/// with the `dv_` token in `NseCredentials`, never with this one.
///
/// An install from before the move holds the token in the preferences. The
/// first read moves it: Keychain write first, and the old key is removed
/// only once that write succeeded. A Keychain that cannot be written keeps
/// the old copy, and the next read tries again.
final class KeychainIdentityTokenStore implements IdentityTokenStore {
  const KeychainIdentityTokenStore(
    this.prefs, {
    this.channel = const MethodChannel('app.critalarm/device_identity'),
  });

  final SharedPreferences prefs;
  final MethodChannel channel;

  /// Not synced, and ThisDeviceOnly.
  static const service = 'app.critalarm.identity_session';

  Map<String, Object?> get _item => {
    'service': service,
    'synchronizable': false,
  };

  @override
  Future<String?> read() async {
    final String? stored;
    try {
      stored = await channel.invokeMethod<String>('read', _item);
    } on PlatformException {
      // The Keychain did not answer. The old copy is all there is to go on.
      return prefs.getString(identitySessionTokenKey);
    }
    final legacy = prefs.getString(identitySessionTokenKey);
    if (stored != null) {
      // A move that was cut off before the old key went.
      if (legacy != null) await prefs.remove(identitySessionTokenKey);
      return stored;
    }
    if (legacy == null) return null;
    try {
      await _write(legacy);
    } on PlatformException {
      return legacy;
    }
    await prefs.remove(identitySessionTokenKey);
    return legacy;
  }

  @override
  Future<void> write(String token) async {
    await _write(token);
    await prefs.remove(identitySessionTokenKey);
  }

  @override
  Future<void> clear() async {
    await prefs.remove(identitySessionTokenKey);
    try {
      await channel.invokeMethod<void>('delete', _item);
    } on PlatformException {
      // Signing out goes on. With the provider gone, readSession answers
      // null whatever is left here, and the next sign-in writes over it.
    }
  }

  Future<void> _write(String token) => channel.invokeMethod<void>('write', {
    ..._item,
    'this_device_only': true,
    'value': token,
  });
}
