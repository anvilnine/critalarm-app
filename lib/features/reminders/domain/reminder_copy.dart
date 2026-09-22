import 'package:critalarm/core/notifications/channel_ids.dart';
import 'package:critalarm/features/reminders/domain/reminder_args.dart';
import 'package:critalarm/features/reminders/domain/reminder_candidate.dart';
import 'package:critalarm/features/reminders/domain/reminder_kind.dart';
import 'package:critalarm/features/reminders/domain/reminder_scheduler.dart';
import 'package:critalarm/features/reminders/domain/rules/plan_heads_up_rule.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';

/// Turns a planned reminder into the words and buttons the lock screen
/// shows. Strings are resolved here, in Dart, because the native side has
/// no access to the app's translations.
final class ReminderCopy {
  const ReminderCopy({required this.isIos});

  /// Picks "App Store" or "Google Play" for idea 21.
  final bool isIos;

  static const List<String> drillTitles = [
    LocaleKeys.reminders_drill_title_1,
    LocaleKeys.reminders_drill_title_2,
    LocaleKeys.reminders_drill_title_3,
    LocaleKeys.reminders_drill_title_4,
    LocaleKeys.reminders_drill_title_5,
    LocaleKeys.reminders_drill_title_6,
    LocaleKeys.reminders_drill_title_7,
    LocaleKeys.reminders_drill_title_8,
    LocaleKeys.reminders_drill_title_9,
    LocaleKeys.reminders_drill_title_10,
  ];

  static const List<String> drillBodies = [
    LocaleKeys.reminders_drill_body_1,
    LocaleKeys.reminders_drill_body_2,
    LocaleKeys.reminders_drill_body_3,
    LocaleKeys.reminders_drill_body_4,
    LocaleKeys.reminders_drill_body_5,
    LocaleKeys.reminders_drill_body_6,
    LocaleKeys.reminders_drill_body_7,
    LocaleKeys.reminders_drill_body_8,
    LocaleKeys.reminders_drill_body_9,
    LocaleKeys.reminders_drill_body_10,
  ];

  /// Drill lines that carry `{days}` and so need the one/other forms.
  static const Set<String> pluralKeys = {
    LocaleKeys.reminders_drill_title_1,
    LocaleKeys.reminders_drill_body_2,
    LocaleKeys.reminders_drill_title_3,
    LocaleKeys.reminders_drill_title_5,
    LocaleKeys.reminders_drill_title_8,
  };

  static const List<String> reviewTitles = [
    LocaleKeys.reminders_review_title_1,
    LocaleKeys.reminders_review_title_2,
  ];

  static const List<String> reviewBodies = [
    LocaleKeys.reminders_review_body_1,
    LocaleKeys.reminders_review_body_2,
  ];

  static const List<String> feedbackTitles = [
    LocaleKeys.reminders_feedback_title_1,
    LocaleKeys.reminders_feedback_title_2,
  ];

  static const List<String> feedbackBodies = [
    LocaleKeys.reminders_feedback_body_1,
    LocaleKeys.reminders_feedback_body_2,
  ];

  ReminderRequest build(ReminderCandidate candidate) {
    final args = candidate.args;
    final (title, body, actions) = switch (candidate.kind) {
      ReminderKind.fireDrill => _drill(args),
      ReminderKind.silentTopic => (
        LocaleKeys.reminders_silent_title.tr(
          namedArgs: {'topic': args[ReminderArgs.topic] ?? ''},
        ),
        LocaleKeys.reminders_silent_body.tr(),
        [_action(ReminderActionIds.curl, LocaleKeys.reminders_action_curl)],
      ),
      ReminderKind.backup => (
        LocaleKeys.reminders_backup_title.plural(
          int.tryParse(args[ReminderArgs.count] ?? '') ?? 2,
        ),
        LocaleKeys.reminders_backup_body.tr(),
        [
          _action(
            ReminderActionIds.signIn,
            LocaleKeys.reminders_action_sign_in,
          ),
        ],
      ),
      ReminderKind.planHeadsUp => _plan(args),
      ReminderKind.morningAfter => (
        LocaleKeys.reminders_morning_title.tr(
          namedArgs: {'time': args[ReminderArgs.time] ?? ''},
        ),
        LocaleKeys.reminders_morning_body.plural(
          int.tryParse(args[ReminderArgs.seconds] ?? '') ?? 0,
          namedArgs: {'topic': args[ReminderArgs.topic] ?? ''},
        ),
        [
          _action(
            ReminderActionIds.seePro,
            LocaleKeys.reminders_action_see_pro,
          ),
          ReminderAction(
            id: ReminderActionIds.notNow,
            title: LocaleKeys.common_not_now.tr(),
            opensApp: false,
          ),
        ],
      ),
      ReminderKind.proLater => (
        LocaleKeys.reminders_pro_later_title.tr(),
        LocaleKeys.reminders_pro_later_body.tr(),
        [
          _action(
            ReminderActionIds.seePro,
            LocaleKeys.reminders_action_see_pro,
          ),
        ],
      ),
      ReminderKind.reviewAsk => _review(args),
      ReminderKind.feedbackAsk => _feedback(args),
    };

    return ReminderRequest(
      id: candidate.id,
      kind: candidate.kind,
      fireAt: candidate.fireAt,
      title: title,
      body: body,
      hiddenPreview: LocaleKeys.reminders_hidden_preview.tr(),
      channelId: candidate.kind.isOffer
          ? ChannelIds.offers
          : ChannelIds.reminders,
      faceAsset: candidate.kind.face.assetPath,
      actions: actions,
      payload: {
        ReminderArgs.kind: candidate.kind.wireName,
        ReminderArgs.id: '${candidate.id}',
        ...args,
      },
    );
  }

  static int _pool(Map<String, String> args, int size) {
    final index = int.tryParse(args[ReminderArgs.pool] ?? '') ?? 0;
    return index < 0 || index >= size ? 0 : index;
  }

  static String _drillLine(
    String key, {
    required int days,
    required String topic,
  }) => pluralKeys.contains(key)
      ? key.plural(days, namedArgs: {'topic': topic})
      : key.tr(namedArgs: {'topic': topic});

  (String, String, List<ReminderAction>) _drill(Map<String, String> args) {
    final index = _pool(args, drillTitles.length);
    final days = int.tryParse(args[ReminderArgs.days] ?? '') ?? 30;
    final topic = args[ReminderArgs.topic] ?? '';
    return (
      _drillLine(drillTitles[index], days: days, topic: topic),
      _drillLine(drillBodies[index], days: days, topic: topic),
      [_action(ReminderActionIds.ring, LocaleKeys.reminders_action_ring)],
    );
  }

  (String, String, List<ReminderAction>) _plan(Map<String, String> args) {
    final notice = PlanNotice.values.asNameMap()[args[ReminderArgs.notice]];
    return switch (notice) {
      PlanNotice.renew => (
        LocaleKeys.reminders_plan_renew_title.tr(
          namedArgs: {
            'date': args[ReminderArgs.date] ?? '',
            'price': args[ReminderArgs.price] ?? '',
          },
        ),
        LocaleKeys.reminders_plan_renew_body.tr(),
        const <ReminderAction>[],
      ),
      PlanNotice.ends => (
        LocaleKeys.reminders_plan_ends_title.tr(
          namedArgs: {'weekday': args[ReminderArgs.weekday] ?? ''},
        ),
        LocaleKeys.reminders_plan_ends_body.tr(),
        const <ReminderAction>[],
      ),
      PlanNotice.billing || null => (
        LocaleKeys.reminders_plan_billing_title.tr(),
        LocaleKeys.reminders_plan_billing_body.tr(),
        [
          _action(
            ReminderActionIds.updatePayment,
            LocaleKeys.reminders_action_update_payment,
          ),
        ],
      ),
    };
  }

  (String, String, List<ReminderAction>) _review(Map<String, String> args) {
    final index = _pool(args, reviewTitles.length);
    final store = isIos
        ? LocaleKeys.reminders_store_app_store.tr()
        : LocaleKeys.reminders_store_google_play.tr();
    return (
      reviewTitles[index].tr(),
      reviewBodies[index].tr(namedArgs: {'store': store}),
      [_action(ReminderActionIds.rate, LocaleKeys.reminders_review_action)],
    );
  }

  (String, String, List<ReminderAction>) _feedback(Map<String, String> args) {
    final index = _pool(args, feedbackTitles.length);
    return (
      feedbackTitles[index].tr(),
      feedbackBodies[index].tr(),
      [
        _action(
          ReminderActionIds.feedback,
          LocaleKeys.settings_help_feedback_row,
        ),
      ],
    );
  }

  static ReminderAction _action(String id, String titleKey) =>
      ReminderAction(id: id, title: titleKey.tr());
}
