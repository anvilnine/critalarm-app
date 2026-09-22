import 'dart:async';

import 'package:critalarm/app/reminder_bindings.dart';
import 'package:critalarm/core/alarm/alarm_focus.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/telemetry/reminder_analytics.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/features/reminders/domain/reminder_kind.dart';
import 'package:critalarm/features/reminders/domain/reminder_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/reminders/fake_reminder_scheduler.dart';
import '../helpers/fake_home_prompt_repository.dart';

/// Never finishes logging, like a slow analytics call.
class _StuckGate extends NoopTelemetryGate {
  @override
  Future<void> logEvent(String name, [Map<String, Object?>? parameters]) =>
      Completer<void>().future;
}

void main() {
  late FakeReminderScheduler scheduler;
  late FakeHomePromptRepository prompts;
  late List<String> routes;
  late List<Uri> urls;
  late int reviews;
  late List<String> forms;
  late ReminderBindings bindings;

  setUp(() {
    scheduler = FakeReminderScheduler();
    prompts = FakeHomePromptRepository();
    routes = [];
    urls = [];
    reviews = 0;
    forms = [];
    bindings = ReminderBindings(
      scheduler: scheduler,
      prompts: prompts,
      focus: AlarmFocus(),
      navigate: routes.add,
      openUrl: (url) async => urls.add(url),
      openStoreReview: () async => reviews++,
      openFeedbackForm: (source) async => forms.add(source),
    );
  });

  test('a cold-launch tap is taken on start', () async {
    scheduler.pendingTap = const ReminderTap(
      kind: ReminderKind.fireDrill,
      actionId: 'ring',
    );
    bindings.start();
    await Future<void>.delayed(Duration.zero);
    expect(routes, ['/ring']);
  });

  test('a live tap routes and a Pro tap counts as asked', () async {
    bindings.start();
    scheduler.tapController.add(
      const ReminderTap(kind: ReminderKind.morningAfter, actionId: 'see_pro'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(routes, ['/paywall?source=reminder_morning_after']);
    expect(prompts.proAskedAt, isNotNull);
  });

  test('review, feedback and plan taps hand off', () async {
    await bindings.handle(
      const ReminderTap(kind: ReminderKind.reviewAsk, actionId: 'rate'),
    );
    await bindings.handle(
      const ReminderTap(kind: ReminderKind.feedbackAsk, actionId: 'open'),
    );
    await bindings.handle(
      const ReminderTap(
        kind: ReminderKind.planHeadsUp,
        actionId: 'update_payment',
        payload: {'url': 'https://play.google.com/store/account/subscriptions'},
      ),
    );
    expect(reviews, 1);
    expect(forms, ['reminder_feedback']);
    expect(urls.single.host, 'play.google.com');
    expect(prompts.proAskedAt, isNull);
  });

  test('routes without waiting for analytics', () async {
    final stuck = ReminderBindings(
      scheduler: scheduler,
      prompts: prompts,
      focus: AlarmFocus(),
      navigate: routes.add,
      openUrl: (url) async => urls.add(url),
      openStoreReview: () async => reviews++,
      openFeedbackForm: (source) async => forms.add(source),
      analytics: ReminderAnalytics(_StuckGate()),
    );
    await stuck.handle(
      const ReminderTap(kind: ReminderKind.fireDrill, actionId: 'ring'),
    );
    expect(routes, ['/ring']);
  });

  test('a store or browser that throws never escapes', () async {
    final throwing = ReminderBindings(
      scheduler: scheduler,
      prompts: prompts,
      focus: AlarmFocus(),
      navigate: routes.add,
      openUrl: (_) async => throw StateError('no browser'),
      openStoreReview: () async => throw StateError('no store'),
      openFeedbackForm: (_) async => throw StateError('no form'),
    );
    await throwing.handle(
      const ReminderTap(kind: ReminderKind.reviewAsk, actionId: 'rate'),
    );
    await throwing.handle(
      const ReminderTap(kind: ReminderKind.feedbackAsk, actionId: 'open'),
    );
    await throwing.handle(
      const ReminderTap(
        kind: ReminderKind.planHeadsUp,
        actionId: 'update_payment',
        payload: {'url': 'https://play.google.com/store/account/subscriptions'},
      ),
    );
  });

  test('a reminder tap opens no url while an alarm is up', () async {
    final ringing = StreamController<List<Incident>>.broadcast();
    final focus = AlarmFocus(incidents: ringing.stream);
    final guarded = ReminderBindings(
      scheduler: scheduler,
      prompts: prompts,
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
      const ReminderTap(
        kind: ReminderKind.planHeadsUp,
        actionId: 'update_payment',
        payload: {'url': 'https://play.google.com/store/account/subscriptions'},
      ),
    );

    expect(urls, isEmpty);
    await focus.dispose();
    await ringing.close();
  });
}
