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
    'account_join_token',
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
      accountJoinToken: _prefs.getString('account_join_token'),
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
    String? accountJoinToken,
  }) async {
    if (deviceToken.trim().isEmpty) throw StateError('Empty device token');
    await _prefs.setString('device_token', deviceToken);
    await _prefs.setString('account_id', accountId);
    await _prefs.setString('account_tier', tier);
    await _prefs.setString('account_caps', jsonEncode(caps.toJson()));
    // api.md §4.2: a join answers without a token, so an absent one means the
    // stored one still stands. An empty string is never a token.
    final join = _nonEmpty(accountJoinToken);
    if (join != null) await _prefs.setString('account_join_token', join);
  }

  /// Forgets the device row that was retired by the iOS Keychain split.
  ///
  /// Only iOS ever had a shared row to retire, so there is nothing to do here.
  Future<void> clearRetiredDevice() async {}

  static String? _nonEmpty(String? value) =>
      value == null || value.trim().isEmpty ? null : value;
}

/// Two Keychain items, not one (api.md §4.2).
///
/// The account item syncs through iCloud, so every handset on one Apple ID
/// lands on the same account. The device item never syncs, so each handset
/// keeps its own device id and its own credential. One synced item holding all
/// four made an iPad restore the iPhone's device id, which put both handsets
/// on one relay device row where each overwrote the other's push token.
final class KeychainDeviceIdentityStore extends DeviceIdentityStore {
  KeychainDeviceIdentityStore(
    super.prefs, {
    this.channel = const MethodChannel('app.critalarm/device_identity'),
  });
  final MethodChannel channel;

  /// Synced. Holds `account_id` and the `aj_` join token.
  static const accountService = 'app.critalarm.account';

  /// Not synced. Holds this handset's `device_id` and its `dv_` token.
  static const deviceService = 'app.critalarm.device_identity';

  /// Reads both a synced and an unsynced copy of an item.
  ///
  /// `kSecAttrSynchronizable` is part of the Keychain lookup, so an item
  /// written when the flag was true is invisible to a read that asks for
  /// false. Without this the split would orphan every install that already
  /// exists.
  static const anySync = 'any';

  /// What this launch settled on. `saveRegistration` needs the device id that
  /// `readOrCreate` decided on, and a second read would mint a different one
  /// on any path that mints at all.
  DeviceIdentity? _current;

  Future<String?> _read(String service, Object synchronizable) =>
      channel.invokeMethod<String>('read', {
        'service': service,
        'synchronizable': synchronizable,
      });

  Future<void> _delete(String service, Object synchronizable) =>
      channel.invokeMethod<void>('delete', {
        'service': service,
        'synchronizable': synchronizable,
      });

  Future<void> _writeDevice(DeviceIdentity identity) =>
      channel.invokeMethod<void>('write', {
        'service': deviceService,
        'synchronizable': false,
        'value': jsonEncode({
          'device_id': identity.deviceId,
          'device_token': identity.deviceToken,
          'account_id': identity.accountId,
          'account_tier': identity.tier,
          'caps': identity.caps.toJson(),
          if (identity.retiredDeviceId != null)
            'retired_device_id': identity.retiredDeviceId,
          if (identity.retiredDeviceToken != null)
            'retired_device_token': identity.retiredDeviceToken,
        }),
      });

  Future<void> _writeAccount({
    required String accountId,
    String? joinToken,
  }) => channel.invokeMethod<void>('write', {
    'service': accountService,
    'synchronizable': true,
    'value': jsonEncode({
      'account_id': accountId,
      'account_join_token': joinToken,
    }),
  });

  @override
  Future<DeviceIdentity> readOrCreate() async {
    final cached = _current;
    if (cached != null) return cached;
    final account = await _readAccount();
    final local = await _read(deviceService, false);
    final identity = local != null
        ? _fromDeviceItem(
            jsonDecode(local) as Map<String, dynamic>,
            account: account,
          )
        : await _adopt(account);
    // Only remove the old copy after the Keychain write succeeds. If cleanup
    // was interrupted, the Keychain copy wins on the next launch.
    for (final key in DeviceIdentityStore.legacyKeys) {
      await _prefs.remove(key);
    }
    _current = identity;
    return identity;
  }

  /// Works out what this handset should use when it has no item of its own.
  ///
  /// Three shapes arrive here: a first install, where the synced item may
  /// already name an account this handset can join; an install still holding
  /// the old single item; and an install from before the Keychain, which kept
  /// everything in prefs.
  Future<DeviceIdentity> _adopt(_AccountItem? account) async {
    final combined = await _read(deviceService, anySync);
    final carried = combined != null
        ? _fromDeviceItem(jsonDecode(combined) as Map<String, dynamic>)
        : _readLegacy();

    if (carried == null) {
      // Nothing on this handset. A synced item carrying a join token means
      // another device on this Apple ID already made the account, so this one
      // attaches itself to it. Registration sends the token; the synced item
      // is left exactly as it is.
      //
      // The new id is not written yet. A join the server refuses on its device
      // cap issues no token, and a launch that got nowhere should leave both
      // items exactly as it found them.
      return DeviceIdentity(
        deviceId: 'dev_${const Uuid().v4()}',
        accountId: account?.accountId,
        accountJoinToken: account?.joinToken,
      );
    }

    // The old item held the account and this handset together. Split it, and
    // write the replacement before anything is thrown away.
    final accountId = carried.accountId ?? account?.accountId;
    final joinToken =
        DeviceIdentityStore._nonEmpty(carried.accountJoinToken) ??
        account?.joinToken;
    if (account == null && accountId != null) {
      await _writeAccount(accountId: accountId, joinToken: joinToken);
    }

    if (joinToken == null) {
      // No join token anywhere, and api.md §4.2 has no route that gives one to
      // a device holding only `dv_`. So this handset keeps the device row it
      // already has. Nothing is lost, and nothing is released.
      //
      // The old synced item stays where it is, and deleting it here would be a
      // bug. A Keychain delete syncs, so it would vanish from every other
      // handset on this Apple ID, and on an account with no join token that
      // item is the only credential those handsets have. They would come up
      // with nothing to carry, register from scratch, and land on a new empty
      // account with none of the person's topics on it. The cost of keeping it
      // is that those handsets still share one device row, which is exactly
      // where they were before, so nothing gets worse.
      await _writeDevice(carried);
      return carried;
    }

    // A join token is in hand, so this handset takes a fresh device id and
    // attaches itself to the account. The shared row it is leaving is carried
    // along with its credential and released once the new row exists.
    return DeviceIdentity(
      deviceId: 'dev_${const Uuid().v4()}',
      accountId: accountId,
      accountJoinToken: joinToken,
      tier: carried.tier,
      caps: carried.caps,
      retiredDeviceId: carried.deviceId,
      retiredDeviceToken: carried.deviceToken,
    );
  }

  Future<_AccountItem?> _readAccount() async {
    final raw = await _read(accountService, true);
    if (raw == null) return null;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final accountId = DeviceIdentityStore._nonEmpty(
      data['account_id'] as String?,
    );
    if (accountId == null) return null;
    return _AccountItem(
      accountId: accountId,
      joinToken: DeviceIdentityStore._nonEmpty(
        data['account_join_token'] as String?,
      ),
    );
  }

  DeviceIdentity _fromDeviceItem(
    Map<String, dynamic> data, {
    _AccountItem? account,
  }) => DeviceIdentity(
    deviceId: data['device_id'] as String,
    deviceToken: data['device_token'] as String?,
    accountId: data['account_id'] as String? ?? account?.accountId,
    // The old single item never held one, so on the first read after an
    // update this comes from the synced item or from nowhere.
    accountJoinToken:
        data['account_join_token'] as String? ?? account?.joinToken,
    tier: data['account_tier'] as String,
    caps: AccountCaps.fromJson(data['caps'] as Map<String, dynamic>? ?? {}),
    retiredDeviceId: data['retired_device_id'] as String?,
    retiredDeviceToken: data['retired_device_token'] as String?,
  );

  @override
  Future<DeviceIdentity> resetIdentity() async {
    final identity = DeviceIdentity(deviceId: 'dev_${const Uuid().v4()}');
    await _writeDevice(identity);
    // Signing out leaves the account, so the synced item goes with it. Left
    // behind, its join token would put this handset straight back on the
    // account it just left.
    await _delete(accountService, true);
    for (final key in DeviceIdentityStore.legacyKeys) {
      await _prefs.remove(key);
    }
    _current = identity;
    return identity;
  }

  @override
  Future<void> saveRegistration({
    required String deviceToken,
    required String accountId,
    required String tier,
    AccountCaps caps = const AccountCaps(),
    String? accountJoinToken,
  }) async {
    if (deviceToken.trim().isEmpty) throw StateError('Empty device token');
    final identity = await readOrCreate();
    // api.md §4.2: the join token comes back only on the call that created the
    // account, so a join answers without one and the stored one still stands.
    final join =
        DeviceIdentityStore._nonEmpty(accountJoinToken) ??
        identity.accountJoinToken;
    if (join != null &&
        (join != identity.accountJoinToken ||
            accountId != identity.accountId)) {
      await _writeAccount(accountId: accountId, joinToken: join);
    }
    final saved = DeviceIdentity(
      deviceId: identity.deviceId,
      deviceToken: deviceToken,
      accountId: accountId,
      accountJoinToken: join,
      tier: tier,
      caps: caps,
      retiredDeviceId: identity.retiredDeviceId,
      retiredDeviceToken: identity.retiredDeviceToken,
    );
    await _writeDevice(saved);
    // The old single item goes last, once this handset's own item is on disk.
    if (identity.retiredDeviceId != null) {
      await _delete(deviceService, true);
    }
    _current = saved;
  }

  @override
  Future<void> clearRetiredDevice() async {
    final identity = _current;
    if (identity == null || identity.retiredDeviceId == null) return;
    final cleared = DeviceIdentity(
      deviceId: identity.deviceId,
      deviceToken: identity.deviceToken,
      accountId: identity.accountId,
      accountJoinToken: identity.accountJoinToken,
      tier: identity.tier,
      caps: identity.caps,
    );
    await _writeDevice(cleared);
    _current = cleared;
  }
}

/// What the synced Keychain item holds.
final class _AccountItem {
  const _AccountItem({required this.accountId, this.joinToken});
  final String accountId;
  final String? joinToken;
}
