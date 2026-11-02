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
