import 'dart:convert';

import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/search/domain/entities/docs_page.dart';
import 'package:critalarm/features/search/domain/repositories/docs_index_repository.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';

/// Reads the documentation index that ships with the app.
///
/// The file is a hand-maintained copy of what is published on critalarm.app.
/// Only public information is in it: page titles, descriptions and public URLs.
class AssetDocsIndexRepository implements DocsIndexRepository {
  AssetDocsIndexRepository({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  static const String assetPath = 'assets/docs/docs_index.json';

  final AssetBundle _bundle;

  /// Read once per launch. The file never changes while the app is running.
  List<DocsPage>? _cache;

  @override
  Future<AppResult<List<DocsPage>>> getPages() async {
    final cached = _cache;
    if (cached != null) return cached.toSuccess();

    try {
      final raw = await _bundle.loadString(assetPath);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final pages = <DocsPage>[
        for (final entry in decoded['pages'] as List<dynamic>)
          DocsPage.fromJson(entry as Map<String, dynamic>),
      ];
      _cache = pages;
      return pages.toSuccess();
    } on Object catch (error) {
      // A missing asset throws a FlutterError, which is an Error and not an
      // Exception, so this catches everything rather than Exception alone.
      return Failure.unexpected(
        message: '${LocaleKeys.storage_errors_read_docs_index.tr()} ($error)',
      ).toFailure<List<DocsPage>>();
    }
  }
}
