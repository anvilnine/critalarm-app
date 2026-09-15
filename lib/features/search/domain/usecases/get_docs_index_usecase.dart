import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/search/domain/entities/docs_page.dart';
import 'package:critalarm/features/search/domain/repositories/docs_index_repository.dart';

class GetDocsIndexUsecase implements UseCase<NoParams, List<DocsPage>> {
  const GetDocsIndexUsecase(this._repository);

  final DocsIndexRepository _repository;

  @override
  Future<AppResult<List<DocsPage>>> call(NoParams input) =>
      _repository.getPages();
}
