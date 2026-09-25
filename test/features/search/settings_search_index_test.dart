import 'package:critalarm/features/search/domain/settings_search_index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SettingsSearchIndex', () {
    test('every id is unique, so results cannot collide', () {
      final ids = SettingsSearchIndex.all.map((d) => d.id).toList();

      expect(ids.toSet(), hasLength(ids.length));
    });

    test('the sound list answers to record and voice memo', () {
      final sound = SettingsSearchIndex.all.singleWhere(
        (d) => d.id == 'alarm_sound',
      );

      expect(sound.keywords, containsAll(['record', 'voice memo']));
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
      final release = SettingsSearchIndex.forBuild(
        includeDevOnly: false,
        showsStorage: true,
      );

      expect(release.any((d) => d.devOnly), isFalse);
      expect(
        release.any((d) => d.routePath.startsWith('/settings/developer')),
        isFalse,
      );
    });

    test('a build that skips the paywall gets everything', () {
      expect(
        SettingsSearchIndex.forBuild(includeDevOnly: true, showsStorage: true),
        hasLength(SettingsSearchIndex.all.length),
      );
      expect(
        SettingsSearchIndex.forBuild(
          includeDevOnly: false,
          showsStorage: true,
        ).length,
        lessThan(SettingsSearchIndex.all.length),
      );
    });

    test('a free relay account cannot find the Storage rows', () {
      final free = SettingsSearchIndex.forBuild(
        includeDevOnly: true,
        showsStorage: false,
      );

      expect(free.map((d) => d.id), isNot(contains('storage-delete-after')));
      expect(free.map((d) => d.id), isNot(contains('storage-keep-critical')));
    });

    test('a paid or self-hosted account finds the Storage rows', () {
      final paid = SettingsSearchIndex.forBuild(
        includeDevOnly: false,
        showsStorage: true,
      );

      expect(
        paid.map((d) => d.id),
        containsAll(['storage-delete-after', 'storage-keep-critical']),
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
