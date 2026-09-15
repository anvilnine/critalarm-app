import 'package:critalarm/core/models/device_registration.dart';

final class DeviceIdentity {
  const DeviceIdentity({
    required this.deviceId,
    this.deviceToken,
    this.accountId,
    this.tier = 'free',
    this.caps = const AccountCaps(),
  });
  final String deviceId;
  final String? deviceToken;
  final String? accountId;
  final String tier;
  final AccountCaps caps;
}
