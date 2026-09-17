import 'package:critalarm/core/models/device_registration.dart';

final class DeviceIdentity {
  const DeviceIdentity({
    required this.deviceId,
    this.deviceToken,
    this.accountId,
    this.accountJoinToken,
    this.tier = 'free',
    this.caps = const AccountCaps(),
    this.retiredDeviceId,
    this.retiredDeviceToken,
  });
  final String deviceId;
  final String? deviceToken;
  final String? accountId;

  /// The `aj_` token that attaches another handset to this account
  /// (api.md §4.2). On iOS it lives in the iCloud-synced Keychain item, so a
  /// second device on the same Apple ID finds it with no screen and no user
  /// action.
  final String? accountJoinToken;
  final String tier;
  final AccountCaps caps;

  /// The device row an iPhone and an iPad were both using before the old
  /// single Keychain item was split in two.
  ///
  /// Held with its credential so the row can be released once this handset
  /// has one of its own. Left behind it keeps one of the two push tokens and
  /// rings the wrong phone (api.md §4.2).
  final String? retiredDeviceId;
  final String? retiredDeviceToken;
}
