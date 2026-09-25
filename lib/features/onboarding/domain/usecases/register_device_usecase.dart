import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/models/device_identity.dart';
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
    PlanChanges? planChanges,
  }) : _platform = platform ?? defaultPushPlatform,
       _planChanges = planChanges ?? appPlanChanges;

  final PlanChanges _planChanges;

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
        ? await _firstRegistration(registration, identity, relayUri)
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
      caps: response.caps,
      accountJoinToken: response.accountJoinToken,
    );
    // Screens that read the tier once, like Settings and History, reload on
    // this. Only a real change bumps, so the launch registration stays quiet.
    if (response.tier != identity.tier || response.caps != identity.caps) {
      _planChanges.bump();
    }
    await _releaseRetiredDevice(identity, relayUri);
    await identifyAccount?.call(response.accountId);
    return response;
  }

  /// The POST that mints this handset's `dv_`.
  ///
  /// With a join token in hand the device attaches to an account another
  /// handset on the same Apple ID already made. Without one it creates its
  /// own account, which is what every device did before.
  Future<DeviceRegistrationResponse> _firstRegistration(
    DeviceRegistration registration,
    DeviceIdentity identity,
    Uri? relayUri,
  ) async {
    final join = identity.accountJoinToken;
    if (join == null) {
      return _api.registerDevice(registration, relayUri: relayUri);
    }
    try {
      return await _api.registerDevice(
        registration,
        relayUri: relayUri,
        accountJoinToken: join,
      );
    } on ApiException catch (error) {
      // api.md §4.2: a join token matching no account answers 401. That
      // account is gone, so the handset starts its own rather than sit with no
      // way to register. A 429 on the device cap is a different thing: no
      // token was issued and the person has to hear about it.
      if (error.statusCode != 401) rethrow;
      return _api.registerDevice(registration, relayUri: relayUri);
    }
  }

  /// Retires the row an iPhone and an iPad shared before the Keychain split.
  ///
  /// Runs only once this handset has a row of its own, so nothing is released
  /// before its replacement exists. A call that fails leaves the pair on disk
  /// and the next launch tries again (api.md §4.2).
  Future<void> _releaseRetiredDevice(
    DeviceIdentity identity,
    Uri? relayUri,
  ) async {
    final id = identity.retiredDeviceId;
    final token = identity.retiredDeviceToken;
    if (id == null || token == null || id == identity.deviceId) return;
    try {
      await _api.deleteDevice(
        deviceId: id,
        deviceToken: token,
        relayUri: relayUri,
      );
    } on ApiException catch (error) {
      // 404 means the row is already gone, so there is nothing left to owe.
      if (error.statusCode != 404) return;
    } on Object catch (_) {
      return;
    }
    await _identity.clearRetiredDevice();
  }
}
