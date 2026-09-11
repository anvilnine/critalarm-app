import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_item.dart';
import 'package:critalarm/features/permissions/domain/repositories/device_permissions_repository.dart';

/// Usecase to fetch all required device permissions and their statuses.
class GetDevicePermissionsUsecase
    implements UseCase<NoParams, List<DevicePermissionItem>> {
  const GetDevicePermissionsUsecase(this._repository);

  final DevicePermissionsRepository _repository;

  @override
  Future<AppResult<List<DevicePermissionItem>>> call(NoParams input) =>
      _repository.getPermissions();
}
