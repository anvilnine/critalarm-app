import 'package:freezed_annotation/freezed_annotation.dart';

part 'device_registration.freezed.dart';
part 'device_registration.g.dart';

/// Caps applied per account on the relay.
@freezed
abstract class AccountCaps with _$AccountCaps {
  const factory AccountCaps({
    @Default(1) int devices,
    @JsonKey(name: 'critical_topics') @Default(1) int criticalTopics,
    @JsonKey(name: 'p4_daily') @Default(50) int p4Daily,
  }) = _AccountCaps;

  factory AccountCaps.fromJson(Map<String, dynamic> json) =>
      _$AccountCapsFromJson(json);
}

/// Registration payload sent by the app to the relay.
@freezed
abstract class DeviceRegistration with _$DeviceRegistration {
  const factory DeviceRegistration({
    @JsonKey(name: 'device_id') required String deviceId,
    required String platform,
    @JsonKey(name: 'push_token') required String pushToken,
    @JsonKey(name: 'app_version') required String appVersion,
  }) = _DeviceRegistration;

  factory DeviceRegistration.fromJson(Map<String, dynamic> json) =>
      _$DeviceRegistrationFromJson(json);
}

/// Response returned from the relay upon registration.
@freezed
abstract class DeviceRegistrationResponse with _$DeviceRegistrationResponse {
  const factory DeviceRegistrationResponse({
    @JsonKey(name: 'account_id') required String accountId,
    required AccountCaps caps,
    @JsonKey(name: 'device_token') String? deviceToken,
    @Default('free') String tier,
  }) = _DeviceRegistrationResponse;

  factory DeviceRegistrationResponse.fromJson(Map<String, dynamic> json) =>
      _$DeviceRegistrationResponseFromJson(json);
}
