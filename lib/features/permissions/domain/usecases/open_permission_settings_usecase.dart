import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/repositories/device_permissions_repository.dart';

/// Usecase to deep-link to system settings for a specific permission.
class OpenPermissionSettingsUsecase
    implements UseCase<DevicePermissionType, bool> {
  const OpenPermissionSettingsUsecase(this._repository);

  final DevicePermissionsRepository _repository;

  @override
  Future<AppResult<bool>> call(DevicePermissionType input) =>
      _repository.openPermissionSettings(input);
}
