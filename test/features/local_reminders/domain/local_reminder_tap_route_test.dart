import 'package:critalarm/features/local_reminders/domain/local_reminder_kind.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_scheduler.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_tap_route.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  LocalReminderTapAction? resolve(
    LocalReminderKind kind, {
    String action = 'open',
    Map<String, String> payload = const {},
  }) => LocalReminderTapRoute.resolve(
    LocalReminderTap(kind: kind, actionId: action, payload: payload),
  );

  String? path(LocalReminderTapAction? action) =>
      action is OpenRouteAction ? action.path : null;

  test('"Ring me now" and a drill tap open the confirm screen', () {
    expect(path(resolve(LocalReminderKind.fireDrill, action: 'ring')), '/ring');
    expect(path(resolve(LocalReminderKind.fireDrill)), '/ring');
  });

  test('"Get curl line" opens the topic with the curl flow', () {
    expect(
      path(
        resolve(
          LocalReminderKind.silentTopic,
          payload: const {'topic': 'prod db'},
        ),
      ),
      '/topics/prod%20db?curl=1',
    );
  });

  test('backup opens sign-in', () {
    expect(path(resolve(LocalReminderKind.backup)), '/settings/account');
  });

  test('plan heads-up opens the store subscription page', () {
    final action = resolve(
      LocalReminderKind.planHeadsUp,
      payload: const {'url': 'https://apps.apple.com/account/subscriptions'},
    );
    expect(action, isA<OpenUrlAction>());
    expect(resolve(LocalReminderKind.planHeadsUp), isNull);
  });

  test('Pro taps open the paywall with a source and count as asked', () {
    expect(
      path(resolve(LocalReminderKind.morningAfter, action: 'see_pro')),
      '/paywall?source=reminder_morning_after',
    );
    expect(
      path(resolve(LocalReminderKind.proLater)),
      '/paywall?source=reminder_pro_later',
    );
    expect(
      LocalReminderTapRoute.countsAsProAsk(
        const LocalReminderTap(
          kind: LocalReminderKind.morningAfter,
          actionId: 'open',
        ),
      ),
      isTrue,
    );
    expect(
      LocalReminderTapRoute.countsAsProAsk(
        const LocalReminderTap(
          kind: LocalReminderKind.backup,
          actionId: 'open',
        ),
      ),
      isFalse,
    );
  });

  test('Pro taps go home for a paid user', () {
    for (final kind in [
      LocalReminderKind.morningAfter,
      LocalReminderKind.proLater,
    ]) {
      final action = LocalReminderTapRoute.resolve(
        LocalReminderTap(kind: kind, actionId: 'open'),
        isPaid: true,
      );
      expect(path(action), '/');
    }
  });

  test('review opens the store page and feedback opens the form', () {
    expect(resolve(LocalReminderKind.reviewAsk), isA<OpenStoreReviewAction>());
    final feedback = resolve(LocalReminderKind.feedbackAsk);
    expect(feedback, isA<OpenFeedbackFormAction>());
    expect((feedback! as OpenFeedbackFormAction).source, 'reminder_feedback');
  });
}
