import 'package:critalarm/features/paywall/data/asset_price_book.dart';
import 'package:critalarm/features/paywall/domain/price_book.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization/src/easy_localization_controller.dart';
import 'package:easy_localization/src/localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loads `assets/translations/en.json` so `.tr()` returns real English text
/// inside unit tests, and the bundled price book for the demo buy model.
///
/// Cubits build their user-facing strings with `LocaleKeys.x.tr()`. Outside a
/// widget tree easy_localization has nothing loaded, so `.tr()` hands back the
/// key path instead of the text. Call this from `setUpAll` in any test that
/// reads a string off a cubit state.
Future<void> loadTestTranslations() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
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

  // The paywall's made-up buy model draws the price book's prices, so the
  // book is read here too, in en_US so a price is worded the same everywhere.
  PriceBookInUse.current = await AssetPriceBook.load(
    rootBundle,
    locale: 'en_US',
  );
}
