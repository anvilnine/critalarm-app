import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/version/app_version.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';

class EstablishApiSessionUsecase {
  const EstablishApiSessionUsecase(
    this._sessions,
    this._register,
    this._identity,
  );
  final ApiSessionStore _sessions;
  final RegisterDeviceUsecase _register;
  final DeviceIdentityStore _identity;

  Future<ApiSession> call(ServerInfo info, String adminToken) async {
    final mode = ServerMode.fromWireValue(info.mode);
    var credential = adminToken;
    if (mode != ServerMode.selfhosted) {
      await _register(
        appVersion: appVersion,
        relayUri: Uri.parse(info.relayUrl),
      );
      credential = (await _identity.readOrCreate()).deviceToken!;
    }
    final session = ApiSession(
      baseUri: Uri.parse(info.baseUrl),
      relayUri: Uri.parse(info.relayUrl),
      mode: mode,
      managementCredential: credential,
    );
    await _sessions.write(session);
    return session;
  }
}
