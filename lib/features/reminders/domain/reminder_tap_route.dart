import 'package:critalarm/features/feedback/domain/feedback_links.dart';
import 'package:critalarm/features/reminders/domain/reminder_args.dart';
import 'package:critalarm/features/reminders/domain/reminder_kind.dart';
import 'package:critalarm/features/reminders/domain/reminder_scheduler.dart';

/// What a reminder tap does.
sealed class ReminderTapAction {
  const ReminderTapAction();
}

final class OpenRouteAction extends ReminderTapAction {
  const OpenRouteAction(this.path);

  final String path;
}

final class OpenUrlAction extends ReminderTapAction {
  const OpenUrlAction(this.url);

  final Uri url;
}

/// The store's write-review page. Never `requestReview()`: both stores say
/// not to call their popup from a tap, because it may show nothing.
final class OpenStoreReviewAction extends ReminderTapAction {
  const OpenStoreReviewAction();
}

final class OpenFeedbackFormAction extends ReminderTapAction {
  const OpenFeedbackFormAction(this.source);

  final String source;
}

/// Maps a reminder tap to where it goes. The body and the button of a
/// reminder go to the same place.
abstract final class ReminderTapRoute {
  static const String ringPath = '/ring';
  static const String signInPath = '/settings/account';
  static const String morningAfterSource = 'reminder_morning_after';
  static const String proLaterSource = 'reminder_pro_later';

  /// Home, for a Pro tap from someone who already pays.
  static const String homePath = '/';

  /// [isPaid] sends a Pro nudge home instead of to the paywall: a reminder
  /// planned before the purchase can still land after it.
  static ReminderTapAction? resolve(
    ReminderTap tap, {
    bool isPaid = false,
  }) => switch (tap.kind) {
    ReminderKind.fireDrill => const OpenRouteAction(ringPath),
    ReminderKind.silentTopic => _topic(tap.payload[ReminderArgs.topic]),
    ReminderKind.backup => const OpenRouteAction(signInPath),
    ReminderKind.planHeadsUp => _url(tap.payload[ReminderArgs.url]),
    ReminderKind.morningAfter =>
      isPaid
          ? const OpenRouteAction(homePath)
          : const OpenRouteAction('/paywall?source=$morningAfterSource'),
    ReminderKind.proLater =>
      isPaid
          ? const OpenRouteAction(homePath)
          : const OpenRouteAction('/paywall?source=$proLaterSource'),
    ReminderKind.reviewAsk => const OpenStoreReviewAction(),
    ReminderKind.feedbackAsk => const OpenFeedbackFormAction(
      FeedbackLinks.reminderSource,
    ),
  };

  /// Any tap on idea 10 or the Pro notice is the ask being made. Delivery
  /// alone is not.
  static bool countsAsProAsk(ReminderTap tap) =>
      tap.kind == ReminderKind.morningAfter ||
      tap.kind == ReminderKind.proLater;

  static ReminderTapAction? _topic(String? topic) {
    if (topic == null || topic.isEmpty) return null;
    return OpenRouteAction('/topics/${Uri.encodeComponent(topic)}?curl=1');
  }

  static ReminderTapAction? _url(String? url) {
    final uri = url == null || url.isEmpty ? null : Uri.tryParse(url);
    return uri == null ? null : OpenUrlAction(uri);
  }
}
