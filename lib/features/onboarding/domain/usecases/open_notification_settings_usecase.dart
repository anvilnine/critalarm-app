import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/repositories/notification_permission_repository.dart';

/// Usecase to deep-link to system notification settings.
class OpenNotificationSettingsUsecase implements UseCase<NoParams, bool> {
  const OpenNotificationSettingsUsecase(this._repository);

  final NotificationPermissionRepository _repository;

  @override
  Future<AppResult<bool>> call(NoParams input) => _repository.openSettings();
}
