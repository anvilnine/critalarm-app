import 'package:critalarm/features/feedback/domain/feedback_links.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_args.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_kind.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_scheduler.dart';

/// What a reminder tap does.
sealed class LocalReminderTapAction {
  const LocalReminderTapAction();
}

final class OpenRouteAction extends LocalReminderTapAction {
  const OpenRouteAction(this.path);

  final String path;
}

final class OpenUrlAction extends LocalReminderTapAction {
  const OpenUrlAction(this.url);

  final Uri url;
}

/// The store's write-review page. Never `requestReview()`: both stores say
/// not to call their popup from a tap, because it may show nothing.
final class OpenStoreReviewAction extends LocalReminderTapAction {
  const OpenStoreReviewAction();
}

final class OpenFeedbackFormAction extends LocalReminderTapAction {
  const OpenFeedbackFormAction(this.source);

  final String source;
}

/// Maps a reminder tap to where it goes. The body and the button of a
/// reminder go to the same place.
abstract final class LocalReminderTapRoute {
  static const String ringPath = '/ring';
  static const String signInPath = '/settings/account';
  static const String morningAfterSource = 'reminder_morning_after';
  static const String proLaterSource = 'reminder_pro_later';

  /// Home, for a Pro tap from someone who already pays.
  static const String homePath = '/';

  /// [isPaid] sends a Pro nudge home instead of to the paywall: a reminder
  /// planned before the purchase can still land after it.
  static LocalReminderTapAction? resolve(
    LocalReminderTap tap, {
    bool isPaid = false,
  }) => switch (tap.kind) {
    LocalReminderKind.fireDrill => const OpenRouteAction(ringPath),
    LocalReminderKind.silentTopic => _topic(
      tap.payload[LocalReminderArgs.topic],
    ),
    LocalReminderKind.backup => const OpenRouteAction(signInPath),
    LocalReminderKind.planHeadsUp => _url(tap.payload[LocalReminderArgs.url]),
    LocalReminderKind.morningAfter =>
      isPaid
          ? const OpenRouteAction(homePath)
          : const OpenRouteAction('/paywall?source=$morningAfterSource'),
    LocalReminderKind.proLater =>
      isPaid
          ? const OpenRouteAction(homePath)
          : const OpenRouteAction('/paywall?source=$proLaterSource'),
    LocalReminderKind.reviewAsk => const OpenStoreReviewAction(),
    LocalReminderKind.feedbackAsk => const OpenFeedbackFormAction(
      FeedbackLinks.localReminderSource,
    ),
  };

  /// Any tap on idea 10 or the Pro notice is the ask being made. Delivery
  /// alone is not.
  static bool countsAsProAsk(LocalReminderTap tap) =>
      tap.kind == LocalReminderKind.morningAfter ||
      tap.kind == LocalReminderKind.proLater;

  static LocalReminderTapAction? _topic(String? topic) {
    if (topic == null || topic.isEmpty) return null;
    return OpenRouteAction('/topics/${Uri.encodeComponent(topic)}?curl=1');
  }

  static LocalReminderTapAction? _url(String? url) {
    final uri = url == null || url.isEmpty ? null : Uri.tryParse(url);
    return uri == null ? null : OpenUrlAction(uri);
  }
}
