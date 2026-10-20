import 'package:critalarm/core/l10n/app_locales.dart';
import 'package:critalarm/core/l10n/native_locale_bridge.dart';
import 'package:critalarm/core/l10n/shipped_locales.dart';
import 'package:critalarm/features/language/domain/language_locale_host.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Names stay in their own language, independent of the current selection.
/// Entries do not ship a language: only shippedLocaleTags controls the list.
const languageNativeNames = <String, String>{
  'en': 'English',
  'de': 'Deutsch',
  'ja': '日本語',
};

class LanguageChoice {
  const LanguageChoice(this.tag, this.nativeName);
  final String? tag;
  final String nativeName;
}

class LanguageState {
  const LanguageState({required this.selectedTag, required this.effectiveTag});
  final String? selectedTag;
  final String effectiveTag;
}

/// App-lifetime selection. Part 2 observes this with BlocProvider.value.
/// A state is emitted only after translations, native text and reminders
/// update.
class LanguageCubit extends Cubit<LanguageState> {
  LanguageCubit({
    required this.host,
    required this.bridge,
    required this.replanReminders,
    required this.openReport,
  }) : super(LanguageState(
         selectedTag: host.savedTag,
         effectiveTag: host.currentTag,
       ));

  final LanguageLocaleHost host;
  final NativeLocaleBridge bridge;
  final Future<void> Function() replanReminders;

  /// Returns a URL the caller can offer to copy if opening failed.
  final Future<Uri?> Function(String locale, String screen) openReport;
  Future<void> _pending = Future<void>.value();

  List<LanguageChoice> get choices => List.unmodifiable([
    LanguageChoice(null, LocaleKeys.language_system_default.tr()),
    for (final tag in shippedLocaleTags)
      LanguageChoice(tag, languageNativeNames[tag]!),
  ]);

  bool get canReport => true;

  Future<void> synchronizeNative() => bridge.setAppLocale(
    host.savedTag == null ? null : localeFromTag(host.savedTag!),
  );

  Future<void> select(String? tag) {
    if (tag != null && !shippedLocaleTags.contains(tag)) {
      return Future<void>.error(ArgumentError.value(tag, 'tag'));
    }
    final next = _pending.then((_) async {
      await host.apply(tag);
      await bridge.setAppLocale(tag == null ? null : localeFromTag(tag));
      await replanReminders();
      if (!isClosed) {
        emit(LanguageState(selectedTag: tag, effectiveTag: host.currentTag));
      }
    });
    // A failed write does not prevent the next selection from being tried.
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> followSystemLocale() async {
    await _pending;
    if (host.savedTag == null) await select(null);
  }

  Future<Uri?> reportMistake({required String screen}) =>
      openReport(host.currentTag, screen);
}
