import 'package:critalarm/app/l10n/easy_localization_language_host.dart';
import 'package:critalarm/app/l10n/language_feedback.dart';
import 'package:critalarm/core/l10n/native_locale_bridge.dart';
import 'package:critalarm/features/feedback/domain/repositories/device_report_repository.dart';
import 'package:critalarm/features/language/presentation/language_cubit.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_plan_trigger.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The language host, the native bridge and the language cubit.
void registerLanguage(GetIt getIt, {required SharedPreferences prefs}) {
  getIt
    ..registerLazySingleton<NativeLocaleBridge>(
      () => kIsWeb
          ? const NoopNativeLocaleBridge()
          : const MethodChannelNativeLocaleBridge(),
    )
    ..registerLazySingleton(() => EasyLocalizationLanguageHost(prefs))
    ..registerLazySingleton(
      () => LanguageCubit(
        host: getIt<EasyLocalizationLanguageHost>(),
        bridge: getIt<NativeLocaleBridge>(),
        replanReminders: () => getIt<LocalReminderPlanTrigger>().run(),
        openReport: LanguageFeedback(
          readReport: ({required locale}) =>
              getIt<DeviceReportRepository>().read(locale: locale),
        ).open,
      ),
    );
}
