import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/search/domain/repositories/recent_searches_repository.dart';

class GetRecentSearchesUsecase implements UseCase<NoParams, List<String>> {
  const GetRecentSearchesUsecase(this._repository);

  final RecentSearchesRepository _repository;

  @override
  Future<AppResult<List<String>>> call(NoParams input) =>
      _repository.getRecent();
}
