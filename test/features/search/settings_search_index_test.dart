import 'package:critalarm/features/search/domain/settings_search_index.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
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

    test('the sound list answers to the emergency sound words', () {
      final sound = SettingsSearchIndex.all.singleWhere(
        (d) => d.id == 'alarm_sound',
      );
      expect(
        sound.keywords,
        containsAll(['emergency', 'klaxon', 'sos', 'beeper', 'horn', 'bell']),
      );
    });

    test('the priorities page is found by priority and by p5', () {
      final release = SettingsSearchIndex.forBuild(
        includeDevOnly: false,
      );
      final priorities = release.singleWhere((d) => d.id == 'priorities');

      expect(priorities.routePath, '/settings/priorities');
      expect(priorities.keywords, containsAll(['priority', 'p5']));
    });

    test('the permissions screen is listed under Will it wake me?', () {
      final permissions = SettingsSearchIndex.all.singleWhere(
        (d) => d.id == 'permissions',
      );

      expect(permissions.routePath, '/settings/permissions');
      expect(permissions.titleKey, LocaleKeys.device_permissions_title);
      expect(permissions.parentTitleKey, LocaleKeys.reliability_title);
      expect(
        SettingsSearchIndex.all.map((d) => d.id),
        isNot(contains('health')),
      );
      // The old name still finds it, though it is never shown.
      expect(permissions.keywords, contains('health'));
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
      );

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
        SettingsSearchIndex.forBuild(
          includeDevOnly: false,
        ).length,
        lessThan(SettingsSearchIndex.all.length),
      );
    });

    test('everyone finds the Storage rows, on any plan and any server', () {
      for (final isSelfHosted in [false, true]) {
        final found = SettingsSearchIndex.forBuild(
          includeDevOnly: false,
          isSelfHosted: isSelfHosted,
        );
        expect(
          found.map((d) => d.id),
          containsAll(['storage-delete-after', 'storage-keep-critical']),
          reason: 'own server: $isSelfHosted',
        );
      }
    });

    test('a phone on its own server cannot find the plan row', () {
      final own = SettingsSearchIndex.forBuild(
        includeDevOnly: false,
        isSelfHosted: true,
      );
      final hosted = SettingsSearchIndex.forBuild(
        includeDevOnly: false,
      );

      expect(own.map((d) => d.id), isNot(contains('plan')));
      expect(own.any((d) => d.routePath.startsWith('/paywall')), isFalse);
      expect(hosted.map((d) => d.id), contains('plan'));
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
