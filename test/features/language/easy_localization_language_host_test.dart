import 'package:critalarm/app/l10n/easy_localization_language_host.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Operations implements LanguageLocaleOperations {
  _Operations(this.preferences);
  final SharedPreferences preferences;
  final calls = <String>[];
  @override
  Locale locale = const Locale('en');
  @override
  Future<void> setLocale(Locale value) async {
    calls.add('set:${value.toLanguageTag()}');
    if (value == locale) return;
    locale = value;
    await preferences.setString('locale', value.toString());
  }

  @override
  Future<void> resetLocale() async {
    calls.add('reset');
    // Mirrors resetLocale saving easy_localization's launch-time device locale.
    await preferences.setString('locale', 'en');
    locale = const Locale('en');
  }

  @override
  Future<void> deleteSaveLocale() async {
    calls.add('delete');
    await preferences.remove('locale');
  }

  @override
  Future<void> translationsReady() async => calls.add('ready');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'same effective language is still saved as an explicit selection',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final operations = _Operations(preferences);
      final host = EasyLocalizationLanguageHost(
        preferences,
        operations: operations,
        phoneLocale: () => const Locale('en'),
      );
      await host.apply('en');
      expect(preferences.getString('locale'), 'en');
      expect(host.savedTag, 'en');
      expect(operations.calls, ['set:en', 'ready']);
      final restored = EasyLocalizationLanguageHost(preferences);
      expect(restored.savedTag, 'en');
    },
  );

  test(
    'reset deletes the locale after reset saves it and uses '
    'current phone locale',
    () async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('locale', 'en');
      var phone = const Locale('de');
      final operations = _Operations(preferences);
      final host = EasyLocalizationLanguageHost(
        preferences,
        operations: operations,
        phoneLocale: () => phone,
      );
      await host.apply(null);
      expect(preferences.containsKey('locale'), isFalse);
      expect(host.savedTag, isNull);
      expect(host.currentTag, 'de');
      expect(operations.calls, ['reset', 'set:de', 'delete', 'ready']);
      phone = const Locale('ja');
      await host.apply(null);
      expect(host.currentTag, 'ja');
      expect(preferences.containsKey('locale'), isFalse);
    },
  );
}
