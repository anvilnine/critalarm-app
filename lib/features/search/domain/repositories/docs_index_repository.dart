import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/search/domain/entities/docs_page.dart';

/// The documentation pages on critalarm.app, so they can be searched offline.
// ignore: one_member_abstracts
abstract interface class DocsIndexRepository {
  Future<AppResult<List<DocsPage>>> getPages();
}
