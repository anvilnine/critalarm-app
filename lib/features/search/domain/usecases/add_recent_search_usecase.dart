import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/search/domain/repositories/recent_searches_repository.dart';

class AddRecentSearchUsecase implements UseCase<String, List<String>> {
  const AddRecentSearchUsecase(this._repository);

  final RecentSearchesRepository _repository;

  @override
  Future<AppResult<List<String>>> call(String input) => _repository.add(input);
}
