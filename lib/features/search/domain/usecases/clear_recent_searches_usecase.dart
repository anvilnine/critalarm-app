import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/search/domain/repositories/recent_searches_repository.dart';

class ClearRecentSearchesUsecase implements UseCase<NoParams, Unit> {
  const ClearRecentSearchesUsecase(this._repository);

  final RecentSearchesRepository _repository;

  @override
  Future<AppResult<Unit>> call(NoParams input) => _repository.clear();
}
