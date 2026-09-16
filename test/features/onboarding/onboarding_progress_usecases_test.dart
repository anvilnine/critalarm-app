import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/repositories/onboarding_progress_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/complete_onboarding_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_onboarding_completed_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockOnboardingProgressRepository extends Mock
    implements OnboardingProgressRepository {}

void main() {
  late MockOnboardingProgressRepository repository;

  setUp(() {
    repository = MockOnboardingProgressRepository();
  });

  test('GetOnboardingCompletedUsecase delegates to repository', () async {
    when(() => repository.isCompleted()).thenAnswer(
      (_) async => true.toSuccess(),
    );

    final result = await GetOnboardingCompletedUsecase(repository)(
      const NoParams(),
    );

    expect(result.getOrNull(), isTrue);
    verify(() => repository.isCompleted()).called(1);
  });

  test('CompleteOnboardingUsecase marks done and drops the draft', () async {
    when(() => repository.markCompleted()).thenAnswer(
      (_) async => unit.toSuccess(),
    );
    when(() => repository.clearDraft()).thenAnswer(
      (_) async => unit.toSuccess(),
    );

    final result = await CompleteOnboardingUsecase(repository)(
      const NoParams(),
    );

    expect(result.isSuccess(), isTrue);
    verify(() => repository.markCompleted()).called(1);
    // A leftover draft would drop a second run into a step already passed.
    verify(() => repository.clearDraft()).called(1);
  });
}
