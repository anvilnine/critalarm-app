import 'package:critalarm/core/notifications/channel_ids.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_args.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_candidate.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_kind.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_scheduler.dart';
import 'package:critalarm/features/local_reminders/domain/rules/plan_heads_up_rule.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';

/// Turns a planned reminder into the words and buttons the lock screen
/// shows. Strings are resolved here, in Dart, because the native side has
/// no access to the app's translations.
final class LocalReminderCopy {
  const LocalReminderCopy({required this.isIos});

  /// Picks "App Store" or "Google Play" for idea 21.
  final bool isIos;

  static const List<String> drillTitles = [
    LocaleKeys.local_reminders_drill_title_1,
    LocaleKeys.local_reminders_drill_title_2,
    LocaleKeys.local_reminders_drill_title_3,
    LocaleKeys.local_reminders_drill_title_4,
    LocaleKeys.local_reminders_drill_title_5,
    LocaleKeys.local_reminders_drill_title_6,
    LocaleKeys.local_reminders_drill_title_7,
    LocaleKeys.local_reminders_drill_title_8,
    LocaleKeys.local_reminders_drill_title_9,
    LocaleKeys.local_reminders_drill_title_10,
  ];

  static const List<String> drillBodies = [
    LocaleKeys.local_reminders_drill_body_1,
    LocaleKeys.local_reminders_drill_body_2,
    LocaleKeys.local_reminders_drill_body_3,
    LocaleKeys.local_reminders_drill_body_4,
    LocaleKeys.local_reminders_drill_body_5,
    LocaleKeys.local_reminders_drill_body_6,
    LocaleKeys.local_reminders_drill_body_7,
    LocaleKeys.local_reminders_drill_body_8,
    LocaleKeys.local_reminders_drill_body_9,
    LocaleKeys.local_reminders_drill_body_10,
  ];

  /// Drill lines that carry `{days}` and so need the one/other forms.
  static const Set<String> pluralKeys = {
    LocaleKeys.local_reminders_drill_title_1,
    LocaleKeys.local_reminders_drill_body_2,
    LocaleKeys.local_reminders_drill_title_3,
    LocaleKeys.local_reminders_drill_title_5,
    LocaleKeys.local_reminders_drill_title_8,
  };

  static const List<String> reviewTitles = [
    LocaleKeys.local_reminders_review_title_1,
    LocaleKeys.local_reminders_review_title_2,
  ];

  static const List<String> reviewBodies = [
    LocaleKeys.local_reminders_review_body_1,
    LocaleKeys.local_reminders_review_body_2,
  ];

  static const List<String> feedbackTitles = [
    LocaleKeys.local_reminders_feedback_title_1,
    LocaleKeys.local_reminders_feedback_title_2,
  ];

  static const List<String> feedbackBodies = [
    LocaleKeys.local_reminders_feedback_body_1,
    LocaleKeys.local_reminders_feedback_body_2,
  ];

  LocalReminderRequest build(LocalReminderCandidate candidate) {
    final args = candidate.args;
    final (title, body, actions) = switch (candidate.kind) {
      LocalReminderKind.fireDrill => _drill(args),
      LocalReminderKind.silentTopic => (
        LocaleKeys.local_reminders_silent_title.tr(
          namedArgs: {'topic': args[LocalReminderArgs.topic] ?? ''},
        ),
        LocaleKeys.local_reminders_silent_body.tr(),
        [
          _action(
            LocalReminderActionIds.curl,
            LocaleKeys.local_reminders_action_curl,
          ),
        ],
      ),
      LocalReminderKind.backup => (
        LocaleKeys.local_reminders_backup_title.plural(
          int.tryParse(args[LocalReminderArgs.count] ?? '') ?? 2,
        ),
        LocaleKeys.local_reminders_backup_body.tr(),
        [
          _action(
            LocalReminderActionIds.signIn,
            LocaleKeys.local_reminders_action_sign_in,
          ),
        ],
      ),
      LocalReminderKind.planHeadsUp => _plan(args),
      LocalReminderKind.morningAfter => (
        LocaleKeys.local_reminders_morning_title.tr(
          namedArgs: {'time': args[LocalReminderArgs.time] ?? ''},
        ),
        LocaleKeys.local_reminders_morning_body.plural(
          int.tryParse(args[LocalReminderArgs.seconds] ?? '') ?? 0,
          namedArgs: {'topic': args[LocalReminderArgs.topic] ?? ''},
        ),
        [
          _action(
            LocalReminderActionIds.seePro,
            LocaleKeys.local_reminders_action_see_pro,
          ),
          LocalReminderAction(
            id: LocalReminderActionIds.notNow,
            title: LocaleKeys.common_not_now.tr(),
            opensApp: false,
          ),
        ],
      ),
      LocalReminderKind.proLater => (
        LocaleKeys.local_reminders_pro_later_title.tr(),
        LocaleKeys.local_reminders_pro_later_body.tr(),
        [
          _action(
            LocalReminderActionIds.seePro,
            LocaleKeys.local_reminders_action_see_pro,
          ),
        ],
      ),
      LocalReminderKind.reviewAsk => _review(args),
      LocalReminderKind.feedbackAsk => _feedback(args),
    };

    return LocalReminderRequest(
      id: candidate.id,
      kind: candidate.kind,
      fireAt: candidate.fireAt,
      title: title,
      body: body,
      hiddenPreview: LocaleKeys.local_reminders_hidden_preview.tr(),
      channelId: candidate.kind.isOffer
          ? ChannelIds.offers
          : ChannelIds.reminders,
      faceAsset: candidate.kind.face.assetPath,
      actions: actions,
      payload: {
        LocalReminderArgs.kind: candidate.kind.wireName,
        LocalReminderArgs.id: '${candidate.id}',
        ...args,
      },
    );
  }

  static int _pool(Map<String, String> args, int size) {
    final index = int.tryParse(args[LocalReminderArgs.pool] ?? '') ?? 0;
    return index < 0 || index >= size ? 0 : index;
  }

  static String _drillLine(
    String key, {
    required int days,
    required String topic,
  }) => pluralKeys.contains(key)
      ? key.plural(days, namedArgs: {'topic': topic})
      : key.tr(namedArgs: {'topic': topic});

  (String, String, List<LocalReminderAction>) _drill(Map<String, String> args) {
    final index = _pool(args, drillTitles.length);
    final days = int.tryParse(args[LocalReminderArgs.days] ?? '') ?? 30;
    final topic = args[LocalReminderArgs.topic] ?? '';
    return (
      _drillLine(drillTitles[index], days: days, topic: topic),
      _drillLine(drillBodies[index], days: days, topic: topic),
      [
        _action(
          LocalReminderActionIds.ring,
          LocaleKeys.local_reminders_action_ring,
        ),
      ],
    );
  }

  (String, String, List<LocalReminderAction>) _plan(Map<String, String> args) {
    final kind = PlanHeadsUpKind.values
        .asNameMap()[args[LocalReminderArgs.headsUp]];
    return switch (kind) {
      PlanHeadsUpKind.renew => (
        LocaleKeys.local_reminders_plan_renew_title.tr(
          namedArgs: {
            'date': args[LocalReminderArgs.date] ?? '',
            'price': args[LocalReminderArgs.price] ?? '',
          },
        ),
        LocaleKeys.local_reminders_plan_renew_body.tr(),
        const <LocalReminderAction>[],
      ),
      PlanHeadsUpKind.ends => (
        LocaleKeys.local_reminders_plan_ends_title.tr(
          namedArgs: {'weekday': args[LocalReminderArgs.weekday] ?? ''},
        ),
        LocaleKeys.local_reminders_plan_ends_body.tr(),
        const <LocalReminderAction>[],
      ),
      PlanHeadsUpKind.billing || null => (
        LocaleKeys.local_reminders_plan_billing_title.tr(),
        LocaleKeys.local_reminders_plan_billing_body.tr(),
        [
          _action(
            LocalReminderActionIds.updatePayment,
            LocaleKeys.local_reminders_action_update_payment,
          ),
        ],
      ),
    };
  }

  (String, String, List<LocalReminderAction>) _review(
    Map<String, String> args,
  ) {
    final index = _pool(args, reviewTitles.length);
    final store = isIos
        ? LocaleKeys.local_reminders_store_app_store.tr()
        : LocaleKeys.local_reminders_store_google_play.tr();
    return (
      reviewTitles[index].tr(),
      reviewBodies[index].tr(namedArgs: {'store': store}),
      [
        _action(
          LocalReminderActionIds.rate,
          LocaleKeys.local_reminders_review_action,
        ),
      ],
    );
  }

  (String, String, List<LocalReminderAction>) _feedback(
    Map<String, String> args,
  ) {
    final index = _pool(args, feedbackTitles.length);
    return (
      feedbackTitles[index].tr(),
      feedbackBodies[index].tr(),
      [
        _action(
          LocalReminderActionIds.feedback,
          LocaleKeys.settings_help_feedback_row,
        ),
      ],
    );
  }

  static LocalReminderAction _action(String id, String titleKey) =>
      LocalReminderAction(id: id, title: titleKey.tr());
}
