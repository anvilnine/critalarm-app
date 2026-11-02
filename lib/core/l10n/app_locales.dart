import 'package:critalarm/core/l10n/shipped_locales.dart';
import 'package:flutter/widgets.dart';

/// A [Locale] for a BCP 47 tag from [shippedLocaleTags]: `en`, `pt-BR`,
/// `zh-Hans`. A four letter part is a script, any other part a country.
Locale localeFromTag(String tag) {
  final parts = tag.split(RegExp('[-_]'));
  String? script;
  String? country;
  for (final part in parts.skip(1)) {
    if (part.length == 4) {
      script = part;
    } else {
      country = part;
    }
  }
  return Locale.fromSubtags(
    languageCode: parts.first,
    scriptCode: script,
    countryCode: country,
  );
}

/// The shipped locales, from the one list in `shipped_locales.dart`.
List<Locale> get shippedLocales => [
  for (final tag in shippedLocaleTags) localeFromTag(tag),
];

/// Pseudo-localization is opt-in and never listed in release or profile builds.
/// Tests pass these build values explicitly without needing a widget tree.
List<Locale> localesForBuild({
  required bool isDebug,
  required bool pseudoRequested,
}) => [
  ...shippedLocales,
  if (isDebug && pseudoRequested) localeFromTag(pseudoLocaleTag),
];

/// The locale a debug run starts in when `PSEUDO_LOCALE=true` is passed.
/// Null everywhere else, so easy_localization uses the saved or device locale.
Locale? pseudoStartLocale({
  required bool isDebug,
  required bool pseudoRequested,
}) => isDebug && pseudoRequested ? localeFromTag(pseudoLocaleTag) : null;

/// Regions that write Traditional Chinese when the phone gives no script.
const _traditionalChineseCountries = {'TW', 'HK', 'MO'};

/// Folds a Chinese phone locale onto the script the app ships: Traditional
/// (`zh-Hant`) for script Hant, or for no script and a country of TW, HK or MO.
/// Every other Chinese locale becomes `zh-Hans`. A non-Chinese locale is
/// returned as it is.
///
/// easy_localization and Flutter both match by language code once the script
/// or country differs, and take the first shipped Chinese locale. A phone that
/// reports `zh_TW` would then get Simplified. This puts the script on first.
Locale foldChineseLocale(Locale locale) {
  if (locale.languageCode != 'zh') return locale;
  final script = locale.scriptCode;
  final traditional = script != null && script.isNotEmpty
      ? script == 'Hant'
      : _traditionalChineseCountries.contains(locale.countryCode);
  return localeFromTag(traditional ? 'zh-Hant' : 'zh-Hans');
}

/// The shipped locale for a phone's preferred locales, in priority order.
///
/// Same as Flutter's [basicLocaleListResolution] (exact match, then language
/// and script, then language and country, then language alone, else the first
/// shipped locale), after the Chinese fold in [foldChineseLocale].
Locale resolvePhoneLocales(
  List<Locale>? phoneLocales, [
  List<Locale>? supported,
]) => basicLocaleListResolution([
  for (final locale in phoneLocales ?? const <Locale>[])
    foldChineseLocale(locale),
], supported ?? shippedLocales);

/// The locale to start in when nothing is saved: the folded Chinese locale if
/// the phone's first locale is Chinese, else null so easy_localization picks
/// from the phone on its own. [Locale] lists come from
/// `PlatformDispatcher.locales`.
Locale? chinesePhoneStartLocale(
  List<Locale> phoneLocales, [
  List<Locale>? supported,
]) => phoneLocales.isNotEmpty && phoneLocales.first.languageCode == 'zh'
    ? resolvePhoneLocales(phoneLocales, supported)
    : null;
