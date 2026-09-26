import 'dart:async';

import 'package:critalarm/app/local_reminder_bindings.dart';
import 'package:critalarm/core/alarm/alarm_focus.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/telemetry/local_reminder_analytics.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_kind.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/local_reminders/fake_local_reminder_scheduler.dart';
import '../helpers/fake_in_app_notice_repository.dart';

/// Never finishes logging, like a slow analytics call.
class _StuckGate extends NoopTelemetryGate {
  @override
  Future<void> logEvent(String name, [Map<String, Object?>? parameters]) =>
      Completer<void>().future;
}

void main() {
  late FakeLocalReminderScheduler scheduler;
  late FakeInAppNoticeRepository notices;
  late List<String> routes;
  late List<Uri> urls;
  late int reviews;
  late List<String> forms;
  late LocalReminderBindings bindings;

  setUp(() {
    scheduler = FakeLocalReminderScheduler();
    notices = FakeInAppNoticeRepository();
    routes = [];
    urls = [];
    reviews = 0;
    forms = [];
    bindings = LocalReminderBindings(
      scheduler: scheduler,
      notices: notices,
      focus: AlarmFocus(),
      navigate: routes.add,
      openUrl: (url) async => urls.add(url),
      openStoreReview: () async => reviews++,
      openFeedbackForm: (source) async => forms.add(source),
    );
  });

  test('a cold-launch tap is taken on start', () async {
    scheduler.pendingTap = const LocalReminderTap(
      kind: LocalReminderKind.fireDrill,
      actionId: 'ring',
    );
    bindings.start();
    await Future<void>.delayed(Duration.zero);
    expect(routes, ['/ring']);
  });

  test('a live tap routes and a Pro tap counts as asked', () async {
    bindings.start();
    scheduler.tapController.add(
      const LocalReminderTap(
        kind: LocalReminderKind.morningAfter,
        actionId: 'see_pro',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(routes, ['/paywall?source=reminder_morning_after']);
    expect(notices.proAskedAt, isNotNull);
  });

  test('review, feedback and plan taps hand off', () async {
    await bindings.handle(
      const LocalReminderTap(
        kind: LocalReminderKind.reviewAsk,
        actionId: 'rate',
      ),
    );
    await bindings.handle(
      const LocalReminderTap(
        kind: LocalReminderKind.feedbackAsk,
        actionId: 'open',
      ),
    );
    await bindings.handle(
      const LocalReminderTap(
        kind: LocalReminderKind.planHeadsUp,
        actionId: 'update_payment',
        payload: {'url': 'https://play.google.com/store/account/subscriptions'},
      ),
    );
    expect(reviews, 1);
    expect(forms, ['reminder_feedback']);
    expect(urls.single.host, 'play.google.com');
    expect(notices.proAskedAt, isNull);
  });

  test('routes without waiting for analytics', () async {
    final stuck = LocalReminderBindings(
      scheduler: scheduler,
      notices: notices,
      focus: AlarmFocus(),
      navigate: routes.add,
      openUrl: (url) async => urls.add(url),
      openStoreReview: () async => reviews++,
      openFeedbackForm: (source) async => forms.add(source),
      analytics: LocalReminderAnalytics(_StuckGate()),
    );
    await stuck.handle(
      const LocalReminderTap(
        kind: LocalReminderKind.fireDrill,
        actionId: 'ring',
      ),
    );
    expect(routes, ['/ring']);
  });

  test('a store or browser that throws never escapes', () async {
    final throwing = LocalReminderBindings(
      scheduler: scheduler,
      notices: notices,
      focus: AlarmFocus(),
      navigate: routes.add,
      openUrl: (_) async => throw StateError('no browser'),
      openStoreReview: () async => throw StateError('no store'),
      openFeedbackForm: (_) async => throw StateError('no form'),
    );
    await throwing.handle(
      const LocalReminderTap(
        kind: LocalReminderKind.reviewAsk,
        actionId: 'rate',
      ),
    );
    await throwing.handle(
      const LocalReminderTap(
        kind: LocalReminderKind.feedbackAsk,
        actionId: 'open',
      ),
    );
    await throwing.handle(
      const LocalReminderTap(
        kind: LocalReminderKind.planHeadsUp,
        actionId: 'update_payment',
        payload: {'url': 'https://play.google.com/store/account/subscriptions'},
      ),
    );
  });

  test('a reminder tap opens no url while an alarm is up', () async {
    final ringing = StreamController<List<Incident>>.broadcast();
    final focus = AlarmFocus(incidents: ringing.stream);
    final guarded = LocalReminderBindings(
      scheduler: scheduler,
      notices: notices,
      focus: focus,
      navigate: routes.add,
      openUrl: (url) async => urls.add(url),
      openStoreReview: () async => reviews++,
      openFeedbackForm: (source) async => forms.add(source),
    );
    ringing.add([
      Incident(id: 'inc_1', topic: 'ops', openedAt: DateTime.now()),
    ]);
    await Future<void>.delayed(Duration.zero);

    await guarded.handle(
      const LocalReminderTap(
        kind: LocalReminderKind.planHeadsUp,
        actionId: 'update_payment',
        payload: {'url': 'https://play.google.com/store/account/subscriptions'},
      ),
    );

    expect(urls, isEmpty);
    await focus.dispose();
    await ringing.close();
  });
}
