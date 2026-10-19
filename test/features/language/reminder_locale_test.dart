import 'package:critalarm/core/l10n/native_locale_bridge.dart';
import 'package:critalarm/features/language/domain/language_locale_host.dart';
import 'package:critalarm/features/language/presentation/language_cubit.dart';
import 'package:critalarm/features/local_reminders/data/shared_prefs_local_reminder_store.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_copy.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_ids.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_inputs.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_plan_pass.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_settler.dart';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_in_app_notice_repository.dart';
import '../local_reminders/fake_local_reminder_scheduler.dart';

void _translate(String prefix) => Localization.load(
  const Locale('en'),
  translations: Translations({
    'local_reminders': {
      'hidden_preview': '$prefix preview',
      'action_ring': '$prefix ring',
      for (var i = 1; i <= 10; i++) ...{
        'drill_title_$i':
            LocalReminderCopy.pluralKeys.contains(
              'local_reminders.drill_title_$i',
            )
            ? {'one': '$prefix title', 'other': '$prefix title'}
            : '$prefix title',
        'drill_body_$i':
            LocalReminderCopy.pluralKeys.contains(
              'local_reminders.drill_body_$i',
            )
            ? {'one': '$prefix body', 'other': '$prefix body'}
            : '$prefix body',
      },
    },
  }),
);

class _Host implements LanguageLocaleHost {
  @override
  String? savedTag;
  @override
  String get currentTag => 'en';
  @override
  Future<void> apply(String? tag) async {
    savedTag = tag;
    _translate('new');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'selection reruns the real plan and replaces scheduled reminder copy',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPrefsLocalReminderStore(
        await SharedPreferences.getInstance(),
      );
      final scheduler = FakeLocalReminderScheduler();
      final pass = LocalReminderPlanPass(
        store: store,
        scheduler: scheduler,
        settler: LocalReminderSettler(
          store: store,
          notices: FakeInAppNoticeRepository(),
        ),
        readInputs: () async => LocalReminderInputs(
          now: DateTime(2026, 9, 22, 12),
          topics: const [LocalReminderTopic(name: 'prod-db', isCritical: true)],
          lastTestAt: {'prod-db': DateTime(2026, 8, 20)},
        ),
        copy: const LocalReminderCopy(isIos: true),
        isWeb: false,
        clock: () => DateTime.utc(2026, 9, 22, 12),
      );
      _translate('old');
      await pass.run();
      final before = scheduler.scheduled[LocalReminderIds.drill]!;
      expect(before.hiddenPreview, 'old preview');
      final cubit = LanguageCubit(
        host: _Host(),
        bridge: const NoopNativeLocaleBridge(),
        replanReminders: pass.run,
        openReport: (_, _) async => null,
      );
      await cubit.select('en');
      final after = scheduler.scheduled[LocalReminderIds.drill]!;
      expect(after.hiddenPreview, 'new preview');
      expect(after.actions.single.title, 'new ring');
      expect(after.id, before.id);
      expect(after.fireAt, before.fireAt);
      await cubit.close();
      await scheduler.tapController.close();
    },
  );
}
