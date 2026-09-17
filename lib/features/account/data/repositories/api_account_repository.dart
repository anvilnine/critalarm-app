import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/version/app_version.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/account/domain/repositories/identity_repository.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/repositories/connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';

/// The account routes, plus the sign-out dance that needs four of them.
final class ApiAccountRepository implements AccountRepository {
  const ApiAccountRepository({
    required this.api,
    required this.sessions,
    required this.devices,
    required this.register,
    required this.identities,
    required this.connections,
  });

  final ApiClient api;
  final ApiSessionStore sessions;
  final DeviceIdentityStore devices;
  final RegisterDeviceUsecase register;
  final IdentityRepository identities;
  final ConnectionRepository connections;

  @override
  Future<AccountLinkResult> link(String identityToken) =>
      api.linkAccount(identityToken: identityToken);

  @override
  Future<AccountMergeResult> merge({
    required String identityToken,
    required String intoAccount,
  }) => api.mergeAccount(
    identityToken: identityToken,
    intoAccount: intoAccount,
  );

  @override
  Future<AccountSwitchResult> switchTo({
    required String identityToken,
    required String intoAccount,
  }) => api.switchAccount(
    identityToken: identityToken,
    intoAccount: intoAccount,
  );

  @override
  Future<ServerMode?> readServerMode() async => (await sessions.read())?.mode;

  @override
  Future<void> signOutDevice() async {
    final current = await devices.readOrCreate();
    final token = current.deviceToken;
    // Delete first. If the server refuses, the phone still holds a credential
    // that works, which is the difference between a failed sign-out and a
    // handset that can never talk to the server again.
    if (token != null) {
      await api.deleteDevice(deviceId: current.deviceId, deviceToken: token);
    }
    final connection = (await connections.getConnection()).getOrNull();
    await identities.clearSession();
    await connections.clearConnection();
    await devices.resetIdentity();
    final response = await register(appVersion: appVersion);
    final fresh = response.deviceToken;
    if (fresh == null) return;
    // Every /v1/ route authenticates on the device token alone, and the saved
    // session and connection both still carry the one that was just deleted.
    final session = await sessions.read();
    if (session != null) {
      await sessions.write(
        ApiSession(
          baseUri: session.baseUri,
          relayUri: session.relayUri,
          mode: session.mode,
          managementCredential: fresh,
        ),
      );
    }
    if (connection != null) {
      await connections.saveConnection(
        ServerConnection(
          serverUrl: connection.serverUrl,
          adminToken: fresh,
        ),
      );
    }
  }
}
