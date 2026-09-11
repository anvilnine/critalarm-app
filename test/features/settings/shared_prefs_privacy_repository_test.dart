import 'package:critalarm/features/settings/data/repositories/shared_prefs_privacy_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late SharedPrefsPrivacyRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = SharedPrefsPrivacyRepository(prefs);
  });

  group('SharedPrefsPrivacyRepository', () {
    test(
      'defaults to false for both analytics and crash reporting when unset',
      () async {
        final result = await repository.getPrivacySettings();

        expect(result.isSuccess(), isTrue);
        result.fold(
          (settings) {
            expect(settings.analyticsEnabled, isFalse);
            expect(settings.crashReportingEnabled, isFalse);
          },
          (failure) => fail('Expected success, got $failure'),
        );
      },
    );

    test(
      'setAnalyticsEnabled persists true and false in SharedPreferences',
      () async {
        final setResult = await repository.setAnalyticsEnabled(enabled: true);
        expect(setResult.isSuccess(), isTrue);
        expect(prefs.getBool('privacy_analytics_enabled'), isTrue);

        final getResult = await repository.getPrivacySettings();
        expect(getResult.getOrNull()?.analyticsEnabled, isTrue);

        final setFalseResult = await repository.setAnalyticsEnabled(
          enabled: false,
        );
        expect(setFalseResult.isSuccess(), isTrue);
        expect(prefs.getBool('privacy_analytics_enabled'), isFalse);
        expect(
          (await repository.getPrivacySettings()).getOrNull()?.analyticsEnabled,
          isFalse,
        );
      },
    );

    test(
      'setCrashReportingEnabled persists true and false in SharedPreferences',
      () async {
        final setResult = await repository.setCrashReportingEnabled(
          enabled: true,
        );
        expect(setResult.isSuccess(), isTrue);
        expect(prefs.getBool('privacy_crashlytics_enabled'), isTrue);

        final getResult = await repository.getPrivacySettings();
        expect(getResult.getOrNull()?.crashReportingEnabled, isTrue);

        final setFalseResult = await repository.setCrashReportingEnabled(
          enabled: false,
        );
        expect(setFalseResult.isSuccess(), isTrue);
        expect(prefs.getBool('privacy_crashlytics_enabled'), isFalse);
        expect(
          (await repository.getPrivacySettings())
              .getOrNull()
              ?.crashReportingEnabled,
          isFalse,
        );
      },
    );

    test('independent toggles do not overwrite each other', () async {
      await repository.setAnalyticsEnabled(enabled: true);
      await repository.setCrashReportingEnabled(enabled: false);

      var settings = (await repository.getPrivacySettings()).getOrNull();
      expect(settings?.analyticsEnabled, isTrue);
      expect(settings?.crashReportingEnabled, isFalse);

      await repository.setCrashReportingEnabled(enabled: true);
      settings = (await repository.getPrivacySettings()).getOrNull();
      expect(settings?.analyticsEnabled, isTrue);
      expect(settings?.crashReportingEnabled, isTrue);
    });
  });
}
