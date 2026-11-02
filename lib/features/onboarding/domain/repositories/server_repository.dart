import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/onboarding/domain/entities/device_registration.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_info.dart';

/// Domain contract for connecting to a server and registering devices.
abstract interface class ServerRepository {
  Future<AppResult<ServerInfo>> getServerInfo([Uri? candidateBaseUri]);

  /// Asks the server at [baseUri] whether it accepts [adminToken], on a read
  /// that changes nothing. Completes when it does. Throws an `ApiException`
  /// carrying the status when the server answers anything else, and
  /// whatever the transport threw when it could not be asked.
  Future<void> checkAdminToken(Uri baseUri, String adminToken);

  Future<AppResult<DeviceRegistrationResponse>> registerDevice(
    DeviceRegistration registration,
  );
}
