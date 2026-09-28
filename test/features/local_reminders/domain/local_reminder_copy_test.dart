import 'package:critalarm/features/local_reminders/domain/local_reminder_args.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_candidate.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_copy.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_kind.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ios = LocalReminderCopy(isIos: true);
  const android = LocalReminderCopy(isIos: false);
  final fireAt = DateTime(2026, 9, 26, 10);

  LocalReminderCandidate candidate(
    LocalReminderKind kind,
    Map<String, String> args,
  ) => LocalReminderCandidate(kind: kind, id: 9100, fireAt: fireAt, args: args);

  test('fire drill line 1 with a count and a topic', () {
    final r = ios.build(
      candidate(LocalReminderKind.fireDrill, {
        LocalReminderArgs.topic: 'prod-db',
        LocalReminderArgs.days: '34',
        LocalReminderArgs.pool: '0',
      }),
    );
    expect(r.title, 'Last test alarm: 34 days ago');
    expect(r.body, 'Ring one now to check prod-db still gets through.');
    expect(r.actions.single.id, LocalReminderActionIds.ring);
    expect(r.actions.single.title, 'Ring me now');
    expect(r.channelId, 'reminders_v1');
    expect(r.faceAsset, 'assets/reminder_faces/curious.png');
    expect(r.payload['kind'], 'fire_drill');
    expect(r.payload['id'], '9100');
    expect(r.hiddenPreview, 'Crit Alarm reminder');
  });

  test('every fire drill line fills in', () {
    for (var i = 0; i < 10; i++) {
      final r = ios.build(
        candidate(LocalReminderKind.fireDrill, {
          LocalReminderArgs.topic: 'prod-db',
          LocalReminderArgs.days: '34',
          LocalReminderArgs.pool: '$i',
        }),
      );
      expect(r.title, isNot(contains('{')), reason: 'title $i');
      expect(r.body, isNot(contains('{')), reason: 'body $i');
    }
  });

  test('silent topic and backup', () {
    final silent = ios.build(
      candidate(LocalReminderKind.silentTopic, {
        LocalReminderArgs.topic: 'prod-db',
      }),
    );
    expect(silent.title, "prod-db hasn't heard from anything yet");
    expect(silent.actions.single.title, 'Get curl line');

    final backup = ios.build(
      candidate(LocalReminderKind.backup, {LocalReminderArgs.count: '3'}),
    );
    expect(backup.title, "3 topics aren't backed up to an account");
    expect(backup.actions.single.title, 'Sign in');
  });

  test('plan heads-up, all three notices', () {
    final billing = ios.build(
      candidate(LocalReminderKind.planHeadsUp, {
        LocalReminderArgs.headsUp: 'billing',
      }),
    );
    expect(billing.title, "Your Pro payment didn't go through");
    expect(billing.actions.single.title, 'Update payment');

    final renew = ios.build(
      candidate(LocalReminderKind.planHeadsUp, {
        LocalReminderArgs.headsUp: 'renew',
        LocalReminderArgs.date: '4 Oct',
        LocalReminderArgs.price: 'PRICE',
      }),
    );
    expect(renew.title, 'Pro renews on 4 Oct for PRICE');
    expect(renew.actions, isEmpty);

    final ends = ios.build(
      candidate(LocalReminderKind.planHeadsUp, {
        LocalReminderArgs.headsUp: 'ends',
        LocalReminderArgs.weekday: 'Friday',
      }),
    );
    expect(ends.title, 'Pro ends Friday');
  });

  test('the morning after goes on the Offers channel', () {
    final r = ios.build(
      candidate(LocalReminderKind.morningAfter, {
        LocalReminderArgs.time: '03:12',
        LocalReminderArgs.topic: 'db-2',
        LocalReminderArgs.seconds: '48',
      }),
    );
    expect(r.title, 'Crit Alarm woke you at 03:12');
    expect(
      r.body,
      'db-2 rang and you were up in 48 s. Pro gives you unlimited critical '
      'topics and 90 days of history.',
    );
    expect(r.channelId, 'offers_v1');
    expect(r.actions.map((a) => a.id), [
      LocalReminderActionIds.seePro,
      LocalReminderActionIds.notNow,
    ]);
    expect(r.actions.last.opensApp, isFalse);
  });

  test('the Pro later notice repeats the See Pro offer', () {
    final r = ios.build(candidate(LocalReminderKind.proLater, const {}));
    expect(r.title, 'Still thinking about Pro?');
    expect(
      r.body,
      'Pro gives you unlimited critical topics and 90 days of history.',
    );
    expect(r.actions.map((a) => a.id), [LocalReminderActionIds.seePro]);
    expect(r.actions.single.title, 'See Pro');
  });

  test('the review ask names the store per platform', () {
    final a = ios.build(
      candidate(LocalReminderKind.reviewAsk, {LocalReminderArgs.pool: '0'}),
    );
    expect(
      a.body,
      'If it is, a short review on App Store helps other on-call people '
      'find it.',
    );
    expect(a.actions.single.title, 'Rate');
    final b = android.build(
      candidate(LocalReminderKind.reviewAsk, {LocalReminderArgs.pool: '1'}),
    );
    expect(b.title, 'Got a minute for a rating?');
    expect(b.body, contains('Google Play'));
    expect(b.faceAsset, 'assets/reminder_faces/happy.png');
  });

  test('the feedback ask reuses the Help row label', () {
    final r = ios.build(
      candidate(LocalReminderKind.feedbackAsk, {LocalReminderArgs.pool: '0'}),
    );
    expect(r.title, 'Three weeks with Crit Alarm');
    expect(r.actions.single.title, 'Send feedback');
    expect(r.faceAsset, 'assets/reminder_faces/watching.png');
  });
}
