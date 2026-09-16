import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/network_failure_message.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/onboarding/domain/entities/device_registration.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_info.dart';
import 'package:critalarm/features/onboarding/domain/repositories/server_repository.dart';

/// In-memory implementation of [ServerRepository] backed by [ApiClient].
class InMemoryServerRepository implements ServerRepository {
  const InMemoryServerRepository(this._client);

  final ApiClient _client;

  @override
  Future<AppResult<ServerInfo>> getServerInfo([Uri? candidateBaseUri]) async {
    try {
      final info = await _client.getServerInfo(candidateBaseUri);
      return info.toSuccess();
    } on ApiException catch (e) {
      return Failure.api(
        statusCode: e.statusCode,
        message: e.message,
        code: e.code,
        cap: e.cap,
      ).toFailure();
    } on Exception catch (e) {
      return Failure.unexpected(message: networkFailureMessage(e)).toFailure();
    }
  }

  @override
  Future<AppResult<DeviceRegistrationResponse>> registerDevice(
    DeviceRegistration registration,
  ) async {
    try {
      final response = await _client.registerDevice(registration);
      return response.toSuccess();
    } on ApiException catch (e) {
      return Failure.api(
        statusCode: e.statusCode,
        message: e.message,
        code: e.code,
        cap: e.cap,
      ).toFailure();
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }
}
