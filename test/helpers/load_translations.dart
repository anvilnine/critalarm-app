import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization/src/easy_localization_controller.dart';
import 'package:easy_localization/src/localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loads `assets/translations/en.json` so `.tr()` returns real English text
/// inside unit tests.
///
/// Cubits build their user-facing strings with `LocaleKeys.x.tr()`. Outside a
/// widget tree easy_localization has nothing loaded, so `.tr()` hands back the
/// key path instead of the text. Call this from `setUpAll` in any test that
/// reads a string off a cubit state.
Future<void> loadTestTranslations() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();

  final controller = EasyLocalizationController(
    forceLocale: const Locale('en'),
    supportedLocales: const [Locale('en')],
    fallbackLocale: const Locale('en'),
    path: 'assets/translations',
    useOnlyLangCode: true,
    useFallbackTranslations: true,
    saveLocale: false,
    assetLoader: const RootBundleAssetLoader(),
    onLoadError: (e) => throw e,
  );

  await controller.loadTranslations();
  Localization.load(
    const Locale('en'),
    translations: controller.translations,
    fallbackTranslations: controller.fallbackTranslations,
  );
}
