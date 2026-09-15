import 'dart:convert';
import 'dart:io';

import 'package:critalarm/features/search/data/repositories/asset_docs_index_repository.dart';
import 'package:critalarm/features/search/domain/entities/docs_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves the real file off disk, so the test checks the asset that ships and
/// not a copy that could drift from it.
class _FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = File(key).readAsBytesSync();
    return ByteData.view(bytes.buffer);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final raw = File(AssetDocsIndexRepository.assetPath).readAsStringSync();
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final pages = (decoded['pages'] as List<dynamic>)
      .map((e) => DocsPage.fromJson(e as Map<String, dynamic>))
      .toList();

  group('the documentation index that ships with the app', () {
    test('is valid JSON with at least one page', () {
      expect(pages, isNotEmpty);
    });

    test('has no duplicate slugs', () {
      final slugs = pages.map((p) => p.slug).toList();

      expect(slugs.toSet(), hasLength(slugs.length));
    });

    test('every page has a title and a group to file it under', () {
      for (final page in pages) {
        expect(page.title, isNotEmpty, reason: '${page.slug} needs a title');
        expect(page.group, isNotEmpty, reason: '${page.slug} needs a group');
      }
    });

    test('every URL is an https link on the public site', () {
      // This file ships in a public repo, so nothing internal belongs in it.
      for (final page in pages) {
        expect(
          page.url,
          startsWith('https://critalarm.app/'),
          reason: '${page.slug} must point at the public site',
        );
      }
    });

    test('every URL matches its own slug', () {
      for (final page in pages) {
        expect(
          page.url,
          'https://critalarm.app/${page.slug}/',
          reason: '${page.slug} and its URL disagree',
        );
      }
    });

    test('the repository reads it and caches the result', () async {
      final repository = AssetDocsIndexRepository(bundle: _FileBundle());

      final first = await repository.getPages();
      final second = await repository.getPages();

      expect(first.getOrNull(), hasLength(pages.length));
      expect(identical(first.getOrNull(), second.getOrNull()), isTrue);
    });
  });
}
