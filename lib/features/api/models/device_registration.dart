import 'package:critalarm/features/api/models/caps.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'device_registration.freezed.dart';
part 'device_registration.g.dart';

/// Device registration response as described in api.md §4.2.
@freezed
abstract class DeviceRegistration with _$DeviceRegistration {
  @JsonSerializable(explicitToJson: true)
  const factory DeviceRegistration({
    @JsonKey(name: 'device_token') required String deviceToken,
    @JsonKey(name: 'account_id') required String accountId,
    required String tier,
    required Caps caps,
  }) = _DeviceRegistration;

  factory DeviceRegistration.fromJson(Map<String, dynamic> json) =>
      _$DeviceRegistrationFromJson(json);
}
