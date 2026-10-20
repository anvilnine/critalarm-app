import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';

/// The active translation bundle owns its intl locale identifier. This keeps
/// context-free formatters in sync with easy_localization, which does not set
/// Intl.defaultLocale. Read on every call, never cache across language changes.
/// An explicit override supports price books used by captures and unit tests.
String currentFormatLocale([String? override]) {
  var locale = override ??
      (trExists(LocaleKeys.dart_format_locale)
          ? LocaleKeys.dart_format_locale.tr()
          : Intl.getCurrentLocale());
  // The debug pseudo bundle uses English date and number symbols.
  if (locale.startsWith('[')) locale = 'en';
  locale = Intl.canonicalizedLocale(locale);
  if (!NumberFormat.localeExists(locale)) return 'en_US';
  try {
    if (DateFormat.localeExists(locale)) return locale;
  } on Exception catch (_) {
    // intl's localeExists itself throws before symbols are initialized.
    // en_US has built-in date and number data, even in a fresh isolate.
  }
  return 'en_US';
}

/// Localized digits without grouping, including padding for clock fields.
String formatInt(int value, {int minimumDigits = 1}) =>
    NumberFormat('0' * minimumDigits, currentFormatLocale()).format(value);

/// Rounds display values before formatting, scrubbing binary floating-point
/// noise. No grouping, and trailing decimal zeros are omitted unless required
/// by [minDecimals]. Stored and parsed values keep their full precision.
String formatNum(double v, {int maxDecimals = 1, int minDecimals = 0}) {
  final rounded = double.parse(v.toStringAsFixed(maxDecimals));
  final format = NumberFormat.decimalPattern(currentFormatLocale())
    ..turnOffGrouping()
    ..minimumFractionDigits = minDecimals
    ..maximumFractionDigits = maxDecimals;
  // Fold rounded negative zero back to zero.
  return format.format(rounded == 0 ? 0 : rounded);
}
