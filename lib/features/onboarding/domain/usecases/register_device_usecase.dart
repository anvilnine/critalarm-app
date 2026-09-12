import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/push/push_token_provider.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';

final class RegisterDeviceUsecase {
  RegisterDeviceUsecase(this._api, this._identity, this._tokens);

  final ApiClient _api;
  final DeviceIdentityStore _identity;
  final PushTokenProvider _tokens;

  Future<DeviceRegistrationResponse> call({required String appVersion}) async {
    final identity = await _identity.readOrCreate();
    final registration = DeviceRegistration(
      deviceId: identity.deviceId,
      platform: 'android',
      pushToken: await _tokens.getToken(),
      appVersion: appVersion,
    );
    final response = identity.deviceToken == null
        ? await _api.registerDevice(registration)
        : await _api.refreshDevice(registration, identity.deviceToken!);
    final token = response.deviceToken ?? identity.deviceToken;
    if (token == null) throw StateError('Registration omitted device token');
    await _identity.saveRegistration(
      deviceToken: token,
      accountId: response.accountId,
      tier: response.tier,
    );
    return response;
  }
}
