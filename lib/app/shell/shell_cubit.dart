import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_item.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/usecases/get_device_permissions_usecase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The device permissions Crit Alarm needs that are not on right now.
@immutable
class ShellHealth {
  const ShellHealth({this.missing = const []});

  final List<DevicePermissionItem> missing;

  int get missingCount => missing.length;
  bool get isHealthy => missing.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShellHealth && listEquals(missing, other.missing);

  @override
  int get hashCode => Object.hashAll(missing);
}

/// What is missing before Crit Alarm can actually ring.
///
/// The floating bar shows a dot on Settings while this is not empty, and the
/// topics screen puts a banner above the list naming what to turn on.
class ShellCubit extends Cubit<ShellHealth> {
  ShellCubit(this._getPermissions) : super(const ShellHealth());

  final GetDevicePermissionsUsecase _getPermissions;

  Future<void> refresh() async {
    final result = await _getPermissions(const NoParams());
    result.fold(
      (items) {
        final missing = items
            .where((p) => p.affectsReadiness)
            .where((p) => p.status != DevicePermissionStatus.granted)
            .toList();
        if (!isClosed) emit(ShellHealth(missing: missing));
      },
      (_) {},
    );
  }
}
