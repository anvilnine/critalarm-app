import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/push/push_token_provider.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:flutter/foundation.dart';

/// `ios` or `android`, the two values api.md §4.2 accepts for `platform`.
String defaultPushPlatform() =>
    defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

final class RegisterDeviceUsecase {
  RegisterDeviceUsecase(
    this._api,
    this._identity,
    this._tokens, {
    String Function()? platform,
    this.identifyAccount,
  }) : _platform = platform ?? defaultPushPlatform;

  final Future<void> Function(String)? identifyAccount;
  final ApiClient _api;
  final DeviceIdentityStore _identity;
  final PushTokenProvider _tokens;
  final String Function() _platform;

  Future<DeviceRegistrationResponse> call({
    required String appVersion,
    String? pushToken,
    Uri? relayUri,
  }) async {
    final identity = await _identity.readOrCreate();
    final registration = DeviceRegistration(
      deviceId: identity.deviceId,
      platform: _platform(),
      pushToken: pushToken ?? await _tokens.getToken(),
      appVersion: appVersion,
    );
    // api.md §4.2: the first call mints the device token, later calls PATCH the
    // same device id with the new push token. Re-POSTing would answer 401.
    final response = identity.deviceToken == null
        ? await _api.registerDevice(registration, relayUri: relayUri)
        : await _api.refreshDevice(
            registration,
            identity.deviceToken!,
            relayUri: relayUri,
          );
    final token = response.deviceToken ?? identity.deviceToken;
    if (token == null || token.trim().isEmpty) {
      throw StateError('Registration omitted device token');
    }
    await _identity.saveRegistration(
      deviceToken: token,
      accountId: response.accountId,
      tier: response.tier,
    );
    await identifyAccount?.call(response.accountId);
    return response;
  }
}
