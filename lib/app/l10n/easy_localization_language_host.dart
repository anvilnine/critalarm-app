import 'package:critalarm/core/l10n/app_locales.dart';
import 'package:critalarm/core/l10n/shipped_locales.dart';
import 'package:critalarm/features/language/domain/language_locale_host.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The context-bound easy_localization operations, replaceable in unit tests.
abstract interface class LanguageLocaleOperations {
  Locale get locale;
  Future<void> setLocale(Locale locale);
  Future<void> resetLocale();
  Future<void> deleteSaveLocale();
  Future<void> translationsReady();
}

class _ContextLocaleOperations implements LanguageLocaleOperations {
  _ContextLocaleOperations(this.context);
  final BuildContext context;

  @override
  Locale get locale => context.locale;
  @override
  Future<void> setLocale(Locale locale) => context.setLocale(locale);
  @override
  Future<void> resetLocale() => context.resetLocale();
  @override
  Future<void> deleteSaveLocale() => context.deleteSaveLocale();
  @override
  Future<void> translationsReady() => WidgetsBinding.instance.endOfFrame;
}

/// Bound to the app context above the router, never a screen's context.
class EasyLocalizationLanguageHost implements LanguageLocaleHost {
  EasyLocalizationLanguageHost(
    this.preferences, {
    this._operations,
    Locale Function()? phoneLocale,
  }) : _readPhoneLocale = phoneLocale ?? _resolvePhoneLocale;

  final SharedPreferences preferences;
  LanguageLocaleOperations? _operations;
  final Locale Function() _readPhoneLocale;

  void attach(BuildContext context) {
    _operations = _ContextLocaleOperations(context);
  }

  void detach() => _operations = null;

  @override
  String? get savedTag {
    final saved = preferences.getString('locale')?.replaceAll('_', '-');
    return shippedLocaleTags.contains(saved) ? saved : null;
  }

  @override
  String get currentTag => _operations?.locale.toLanguageTag() ??
      savedTag ?? _readPhoneLocale().toLanguageTag();

  static Locale _resolvePhoneLocale() => basicLocaleListResolution(
    WidgetsBinding.instance.platformDispatcher.locales,
    shippedLocales,
  );

  @override
  Future<void> apply(String? tag) async {
    final operations = _operations;
    if (operations == null) throw StateError('Language host is not attached');
    if (tag == null) {
      // resetLocale uses easy_localization's launch-time device snapshot.
      // Resolve again so phone changes during this run also take effect.
      await operations.resetLocale();
      await operations.setLocale(_readPhoneLocale());
      await operations.deleteSaveLocale();
    } else {
      final locale = localeFromTag(tag);
      await operations.setLocale(locale);
      // setLocale skips persistence when the effective locale is unchanged.
      // An explicit pick must still survive launch, even on an English phone.
      if (!await preferences.setString('locale', locale.toString())) {
        throw StateError('Language choice was not saved');
      }
    }
    // Global .tr() updates in the localization delegate during the frame.
    // Cached text and reminder copy must wait for that delegate.
    await operations.translationsReady();
  }
}
