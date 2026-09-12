import 'package:critalarm/core/models/device_identity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

final class DeviceIdentityStore {
  DeviceIdentityStore(this._prefs);
  final SharedPreferences _prefs;
  static const _id = 'device_id';
  static const _token = 'device_token';
  static const _account = 'account_id';
  static const _tier = 'account_tier';

  Future<DeviceIdentity> readOrCreate() async {
    final existing = _prefs.getString(_id);
    final id = existing ?? 'dev_${const Uuid().v4()}';
    if (existing == null) await _prefs.setString(_id, id);
    return DeviceIdentity(
      deviceId: id,
      deviceToken: _prefs.getString(_token),
      accountId: _prefs.getString(_account),
      tier: _prefs.getString(_tier) ?? 'free',
    );
  }

  Future<void> saveRegistration({
    required String deviceToken,
    required String accountId,
    required String tier,
  }) async {
    await _prefs.setString(_token, deviceToken);
    await _prefs.setString(_account, accountId);
    await _prefs.setString(_tier, tier);
  }
}
