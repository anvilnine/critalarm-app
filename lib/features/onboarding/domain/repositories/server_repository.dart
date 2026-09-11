import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/onboarding/domain/entities/device_registration.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_info.dart';

/// Domain contract for connecting to a server and registering devices.
abstract interface class ServerRepository {
  Future<AppResult<ServerInfo>> getServerInfo();

  Future<AppResult<DeviceRegistrationResponse>> registerDevice(
    DeviceRegistration registration,
  );
}
