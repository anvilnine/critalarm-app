import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Tells the native side which language the person picked in the app, so the
/// surfaces that run without Flutter follow it: the notification extension,
/// the AlarmKit buttons, the Live Activity and the widgets on iOS; the alarm
/// and status cards, the widgets and the notification channel names on
/// Android.
///
/// - iOS stores the tag in the app group (`NativeL10n` in
///   ios/Shared/L10n/NativeL10n.swift), registers the notification buttons
///   again and reloads the widgets.
/// - Android stores it, hands it to `LocaleManager` on Android 13 and later,
///   renames the notification channels (same ids, so their sound and
///   importance stay) and redraws the widgets (`LocaleChannel.kt`).
///
/// Local reminders hold text Dart rendered when it planned them, so they
/// change language on the next plan pass (`LocalReminderPlanTrigger.run`),
/// which the caller runs after a switch.
// ignore: one_member_abstracts
abstract interface class NativeLocaleBridge {
  /// [locale] is the pick, null for System default (the phone's language).
  /// Call it after easy_localization has switched (`setLocale` or
  /// `resetLocale`). Never throws: a platform with no handler, or a failed
  /// call, leaves the native text as it was.
  Future<void> setAppLocale(Locale? locale);
}

/// The method channel the iOS `AppDelegate` and Android `MainActivity` answer.
final class MethodChannelNativeLocaleBridge implements NativeLocaleBridge {
  const MethodChannelNativeLocaleBridge([
    this._channel = const MethodChannel(channelName),
  ]);

  static const channelName = 'app.critalarm/locale';

  final MethodChannel _channel;

  /// The BCP 47 tag the native side reads: `en`, `pt-BR`, `zh-Hans`,
  /// `en-XA`. Null for System default.
  static String? tagFor(Locale? locale) => locale?.toLanguageTag();

  @override
  Future<void> setAppLocale(Locale? locale) async {
    try {
      await _channel.invokeMethod<void>('setAppLocale', {
        'tag': tagFor(locale),
      });
    } on MissingPluginException {
      // Web and tests: no native side to tell.
    } on PlatformException catch (error) {
      debugPrint('native_locale_failed code=${error.code}');
    }
  }
}

/// Registered on web, where nothing native shows text.
final class NoopNativeLocaleBridge implements NativeLocaleBridge {
  const NoopNativeLocaleBridge();

  @override
  Future<void> setAppLocale(Locale? locale) async {}
}
