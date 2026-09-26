import 'package:critalarm/features/local_reminders/domain/local_reminder_copy.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_kind.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_lab_samples.dart';
import 'package:critalarm/features/local_reminders/domain/quick_action_items.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every key the copy reads resolves to English', () {
    final keys = [
      ...LocalReminderCopy.drillTitles,
      ...LocalReminderCopy.drillBodies,
      ...LocalReminderCopy.reviewTitles,
      ...LocalReminderCopy.reviewBodies,
      ...LocalReminderCopy.feedbackTitles,
      ...LocalReminderCopy.feedbackBodies,
      for (final action in QuickActionType.values) action.titleKey,
      LocaleKeys.reminders_silent_title,
      LocaleKeys.reminders_silent_body,
      LocaleKeys.reminders_backup_title,
      LocaleKeys.reminders_backup_body,
      LocaleKeys.reminders_plan_billing_title,
      LocaleKeys.reminders_plan_billing_body,
      LocaleKeys.reminders_plan_renew_title,
      LocaleKeys.reminders_plan_renew_body,
      LocaleKeys.reminders_plan_ends_title,
      LocaleKeys.reminders_plan_ends_body,
      LocaleKeys.reminders_morning_title,
      LocaleKeys.reminders_morning_body,
      LocaleKeys.reminders_pro_later_title,
      LocaleKeys.reminders_pro_later_body,
      LocaleKeys.reminders_review_action,
      LocaleKeys.reminders_store_app_store,
      LocaleKeys.reminders_store_google_play,
      LocaleKeys.reminders_action_ring,
      LocaleKeys.reminders_action_curl,
      LocaleKeys.reminders_action_sign_in,
      LocaleKeys.reminders_action_update_payment,
      LocaleKeys.reminders_action_see_pro,
      LocaleKeys.reminders_hidden_preview,
      LocaleKeys.common_not_now,
      LocaleKeys.settings_help_feedback_row,
      LocaleKeys.home_pro_prompt_later,
    ];
    for (final key in keys) {
      final isPlural =
          LocalReminderCopy.pluralKeys.contains(key) ||
          key == LocaleKeys.reminders_backup_title ||
          key == LocaleKeys.reminders_morning_body;
      final text = isPlural
          ? key.plural(2, namedArgs: {'topic': 'prod-db'})
          : key.tr(namedArgs: {'topic': 'prod-db', 'store': 'App Store'});
      expect(text, isNot(key), reason: key);
      expect(text, isNot(contains('\u2014')), reason: key);
    }
  });

  test('every kind builds with no key or placeholder left over', () {
    for (final isIos in [true, false]) {
      final copy = LocalReminderCopy(isIos: isIos);
      for (final kind in LocalReminderKind.values) {
        final request = copy.build(
          LocalReminderLabSamples.candidate(kind, DateTime(2026, 10, 3, 10)),
        );
        final texts = [
          request.title,
          request.body,
          request.hiddenPreview,
          for (final action in request.actions) action.title,
        ];
        for (final text in texts) {
          final reason = '${kind.wireName} ios=$isIos: $text';
          expect(text, isNotEmpty, reason: reason);
          expect(text, isNot(contains('reminders.')), reason: reason);
          expect(text, isNot(contains('{')), reason: reason);
        }
      }
    }
  });

  test('the morning after body counts seconds at 1 and at many', () {
    final one = LocaleKeys.reminders_morning_body.plural(
      1,
      namedArgs: {'topic': 'prod-db'},
    );
    final many = LocaleKeys.reminders_morning_body.plural(
      40,
      namedArgs: {'topic': 'prod-db'},
    );
    expect(one, isNot(many));
    expect(many, contains('40'));
  });

  test('counts read naturally at 1 and at many', () {
    expect(LocaleKeys.reminders_backup_title.plural(1), contains('1 topic '));
    expect(LocaleKeys.reminders_backup_title.plural(3), contains('3 topics'));
    expect(
      LocaleKeys.reminders_ring_last_test.plural(1),
      'Last test 1 day ago',
    );
    expect(
      LocaleKeys.reminders_drill_title_8.plural(34),
      '34 quiet days',
    );
  });
}
