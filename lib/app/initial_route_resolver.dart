import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_onboarding_completed_usecase.dart';

String initialLocationFor({
  required bool hasServerConnection,
  required bool hasCompletedOnboarding,
}) => !hasServerConnection && !hasCompletedOnboarding ? '/onboarding' : '/';

class InitialRouteResolver {
  const InitialRouteResolver(
    this._getConnection,
    this._getOnboardingCompleted,
  );

  final GetConnectionUsecase _getConnection;
  final GetOnboardingCompletedUsecase _getOnboardingCompleted;

  Future<String> call() async {
    final connection = await _getConnection(const NoParams());
    final completed = await _getOnboardingCompleted(const NoParams());

    return initialLocationFor(
      hasServerConnection: connection.isSuccess(),
      hasCompletedOnboarding: completed.getOrNull() ?? false,
    );
  }
}
