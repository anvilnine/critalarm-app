final class DeviceIdentity {
  const DeviceIdentity({
    required this.deviceId,
    this.deviceToken,
    this.accountId,
    this.tier = 'free',
  });
  final String deviceId;
  final String? deviceToken;
  final String? accountId;
  final String tier;
}
