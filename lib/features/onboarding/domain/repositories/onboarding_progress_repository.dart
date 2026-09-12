import 'package:critalarm/core/result/result.dart';

abstract interface class OnboardingProgressRepository {
  Future<AppResult<bool>> isCompleted();

  Future<AppResult<Unit>> markCompleted();
}
