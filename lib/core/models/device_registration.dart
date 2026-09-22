import 'package:freezed_annotation/freezed_annotation.dart';

part 'device_registration.freezed.dart';
part 'device_registration.g.dart';

/// Caps applied per account on the relay.
///
/// `history_incidents` was removed in 1.16.0 (api.md §4.2). `history_days` is
/// a retention window now, not a count of alarms.
@freezed
abstract class AccountCaps with _$AccountCaps {
  const factory AccountCaps({
    int? devices,
    @JsonKey(name: 'critical_topics') int? criticalTopics,
    @JsonKey(name: 'p4_daily') int? p4Daily,
    @JsonKey(name: 'history_days') int? historyDays,
  }) = _AccountCaps;

  factory AccountCaps.fromJson(Map<String, dynamic> json) =>
      _$AccountCapsFromJson(json);

  /// The `free` column of the cap table in api.md §4.2. Used until the relay
  /// has answered with the real caps.
  static const free = AccountCaps(
    devices: 5,
    criticalTopics: 2,
    p4Daily: 50,
    historyDays: 7,
  );
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
    // api.md §4.2: present only on the call that created the account. A join
    // answers without it, because the caller already holds one.
    @JsonKey(name: 'account_join_token') String? accountJoinToken,
    @Default('free') String tier,
  }) = _DeviceRegistrationResponse;

  factory DeviceRegistrationResponse.fromJson(Map<String, dynamic> json) =>
      _$DeviceRegistrationResponseFromJson(json);
}
