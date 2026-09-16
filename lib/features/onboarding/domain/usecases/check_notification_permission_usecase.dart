import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';
import 'package:critalarm/features/onboarding/domain/repositories/notification_permission_repository.dart';

/// Reads the current notification permission without prompting.
///
/// Onboarding needs this twice: to skip a step the user has already granted,
/// and to notice a grant made in system Settings while the app was away.
class CheckNotificationPermissionUsecase
    implements UseCase<NoParams, NotificationPermissionStatus> {
  const CheckNotificationPermissionUsecase(this._repository);

  final NotificationPermissionRepository _repository;

  @override
  Future<AppResult<NotificationPermissionStatus>> call(NoParams input) =>
      _repository.checkPermission();
}
