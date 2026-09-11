import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/settings/domain/entities/privacy_settings.dart';
import 'package:critalarm/features/settings/domain/repositories/privacy_repository.dart';

/// Usecase to retrieve the user's stored privacy choices.
class GetPrivacySettingsUsecase implements UseCase<NoParams, PrivacySettings> {
  const GetPrivacySettingsUsecase(this._repository);

  final PrivacyRepository _repository;

  @override
  Future<AppResult<PrivacySettings>> call(NoParams input) =>
      _repository.getPrivacySettings();
}
