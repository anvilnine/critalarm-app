import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';
import 'package:critalarm/features/onboarding/domain/repositories/notification_permission_repository.dart';

/// Usecase to request notification and full-screen intent permissions.
class RequestNotificationPermissionUsecase
    implements UseCase<NoParams, NotificationPermissionStatus> {
  const RequestNotificationPermissionUsecase(this._repository);

  final NotificationPermissionRepository _repository;

  @override
  Future<AppResult<NotificationPermissionStatus>> call(NoParams input) =>
      _repository.requestPermission();
}
