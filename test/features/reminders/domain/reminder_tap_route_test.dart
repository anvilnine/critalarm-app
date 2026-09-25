import 'package:critalarm/features/reminders/domain/reminder_kind.dart';
import 'package:critalarm/features/reminders/domain/reminder_scheduler.dart';
import 'package:critalarm/features/reminders/domain/reminder_tap_route.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ReminderTapAction? resolve(
    ReminderKind kind, {
    String action = 'open',
    Map<String, String> payload = const {},
  }) => ReminderTapRoute.resolve(
    ReminderTap(kind: kind, actionId: action, payload: payload),
  );

  String? path(ReminderTapAction? action) =>
      action is OpenRouteAction ? action.path : null;

  test('"Ring me now" and a drill tap open the confirm screen', () {
    expect(path(resolve(ReminderKind.fireDrill, action: 'ring')), '/ring');
    expect(path(resolve(ReminderKind.fireDrill)), '/ring');
  });

  test('"Get curl line" opens the topic with the curl flow', () {
    expect(
      path(
        resolve(ReminderKind.silentTopic, payload: const {'topic': 'prod db'}),
      ),
      '/topics/prod%20db?curl=1',
    );
  });

  test('backup opens sign-in', () {
    expect(path(resolve(ReminderKind.backup)), '/settings/account');
  });

  test('plan heads-up opens the store subscription page', () {
    final action = resolve(
      ReminderKind.planHeadsUp,
      payload: const {'url': 'https://apps.apple.com/account/subscriptions'},
    );
    expect(action, isA<OpenUrlAction>());
    expect(resolve(ReminderKind.planHeadsUp), isNull);
  });

  test('Pro taps open the paywall with a source and count as asked', () {
    expect(
      path(resolve(ReminderKind.morningAfter, action: 'see_pro')),
      '/paywall?source=reminder_morning_after',
    );
    expect(
      path(resolve(ReminderKind.proLater)),
      '/paywall?source=reminder_pro_later',
    );
    expect(
      ReminderTapRoute.countsAsProAsk(
        const ReminderTap(kind: ReminderKind.morningAfter, actionId: 'open'),
      ),
      isTrue,
    );
    expect(
      ReminderTapRoute.countsAsProAsk(
        const ReminderTap(kind: ReminderKind.backup, actionId: 'open'),
      ),
      isFalse,
    );
  });

  test('Pro taps go home for a paid user', () {
    for (final kind in [ReminderKind.morningAfter, ReminderKind.proLater]) {
      final action = ReminderTapRoute.resolve(
        ReminderTap(kind: kind, actionId: 'open'),
        isPaid: true,
      );
      expect(path(action), '/');
    }
  });

  test('review opens the store page and feedback opens the form', () {
    expect(resolve(ReminderKind.reviewAsk), isA<OpenStoreReviewAction>());
    final feedback = resolve(ReminderKind.feedbackAsk);
    expect(feedback, isA<OpenFeedbackFormAction>());
    expect((feedback! as OpenFeedbackFormAction).source, 'reminder_feedback');
  });
}
