import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/usecases/get_device_permissions_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// How many device permissions are missing right now.
///
/// The floating bar shows one dot on Settings when this is above zero, which
/// is the only place the app warns that it cannot ring.
class ShellCubit extends Cubit<int> {
  ShellCubit(this._getPermissions) : super(0);

  final GetDevicePermissionsUsecase _getPermissions;

  Future<void> refresh() async {
    final result = await _getPermissions(const NoParams());
    result.fold(
      (items) {
        final missing = items
            .where((p) => p.affectsReadiness)
            .where((p) => p.status != DevicePermissionStatus.granted)
            .length;
        if (!isClosed) emit(missing);
      },
      (_) {},
    );
  }
}
