import 'package:critalarm/core/format/number_format.dart';
import 'package:flutter/widgets.dart';

/// Upper-cases [text] the way [locale]'s language does it.
///
/// Dart's `toUpperCase()` maps `i` to `I`. Turkish writes `İ` for a dotted
/// lowercase `i` and `I` for the dotless `ı`. Every other language uses the
/// plain mapping. Use this for translated text. Leave `toUpperCase()` alone
/// for HTTP methods, currency codes and other text that is not translated.
///
/// "iPad" keeps its own case, so a label reads "IPAD" nowhere: Apple's name
/// is written the same in every language and every case.
String upperForLocale(String text, Locale locale) {
  if (text.contains(_ipad)) {
    return text
        .split(_ipad)
        .map((part) => upperForLocale(part, locale))
        .join(_ipad);
  }
  if (locale.languageCode == 'tr') {
    // `ı` already becomes `I` in toUpperCase(), so only `i` needs a hand.
    return text.replaceAll('i', 'İ').toUpperCase();
  }
  return text.toUpperCase();
}

const String _ipad = 'iPad';

/// [upperForLocale] for code with no [BuildContext], using the language of the
/// active translation bundle (the same source as [currentFormatLocale]).
String upperForCurrentLocale(String text) {
  final tag = currentFormatLocale().split(RegExp('[-_]')).first;
  return upperForLocale(text, Locale(tag));
}

/// [upperForLocale] for a widget's `build`. Reads the locale the app passes to
/// `MaterialApp` (easy_localization's `context.locale`), so the widget rebuilds
/// when the language changes. Falls back to the active bundle's language when
/// no `Localizations` widget is above [context].
String upperInContext(String text, BuildContext context) {
  final locale = Localizations.maybeLocaleOf(context);
  return locale == null
      ? upperForCurrentLocale(text)
      : upperForLocale(text, locale);
}
