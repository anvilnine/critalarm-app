import 'package:critalarm/features/search/domain/settings_search_index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SettingsSearchIndex', () {
    test('every id is unique, so results cannot collide', () {
      final ids = SettingsSearchIndex.all.map((d) => d.id).toList();

      expect(ids.toSet(), hasLength(ids.length));
    });

    test('every destination points somewhere inside the app', () {
      for (final destination in SettingsSearchIndex.all) {
        expect(
          destination.routePath,
          startsWith('/'),
          reason: '${destination.id} must be an app route',
        );
      }
    });

    test('a release build cannot find the developer screen', () {
      final release = SettingsSearchIndex.forBuild(includeDevOnly: false);

      expect(release.any((d) => d.devOnly), isFalse);
      expect(
        release.any((d) => d.routePath.startsWith('/settings/developer')),
        isFalse,
      );
    });

    test('a build that skips the paywall gets everything', () {
      expect(
        SettingsSearchIndex.forBuild(includeDevOnly: true),
        hasLength(SettingsSearchIndex.all.length),
      );
      expect(
        SettingsSearchIndex.forBuild(includeDevOnly: false).length,
        lessThan(SettingsSearchIndex.all.length),
      );
    });

    test('keywords are lowercase, because matching lowercases the query', () {
      for (final destination in SettingsSearchIndex.all) {
        for (final keyword in destination.keywords) {
          expect(
            keyword,
            keyword.toLowerCase(),
            reason: '${destination.id} keyword "$keyword" must be lowercase',
          );
        }
      }
    });
  });
}
