import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/repositories/connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/clear_connection_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectionRepository extends Mock implements ConnectionRepository {}

void main() {
  late MockConnectionRepository repository;

  setUp(() {
    repository = MockConnectionRepository();
  });

  group('ClearConnectionUsecase', () {
    test('delegates clearConnection to repository', () async {
      when(() => repository.clearConnection())
          .thenAnswer((_) async => unit.toSuccess());

      final usecase = ClearConnectionUsecase(repository);
      final result = await usecase(const NoParams());

      expect(result.isSuccess(), isTrue);
      verify(() => repository.clearConnection()).called(1);
    });
  });
}
