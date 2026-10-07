import 'package:critalarm/features/in_app_notices/domain/missed_alarm_notice_rule.dart';
import 'package:critalarm/features/in_app_notices/domain/setup_gate.dart';
import 'package:critalarm/features/in_app_notices/presentation/missed_alarm_notice_view.dart';
import 'package:critalarm/features/reliability/data/shared_prefs_missed_alarm_store.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_reader.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_rule.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/phone_record.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final now = DateTime.utc(2026, 10, 7, 9);

  MissedAlarm alarm(
    String id, {
    Duration ago = const Duration(hours: 6),
    String topic = 'prod',
    MissedReason reason = MissedReason.unanswered,
  }) => MissedAlarm(
    incidentId: id,
    topic: topic,
    at: now.subtract(ago),
    reason: reason,
  );

  MissedAlarmNotice? notice(
    List<MissedAlarm>? missed, {
    bool isSetupDone = true,
    Set<String> dismissed = const {},
  }) => MissedAlarmNoticeRule.noticeFor(
    isSetupDone: isSetupDone,
    missed: missed,
    dismissedIds: dismissed,
    now: now,
  );

  test('nothing missed shows nothing', () {
    expect(notice(const []), isNull);
  });

  test('a read that failed shows nothing', () {
    expect(notice(null), isNull);
  });

  test('one missed alarm shows once, with its topic, time and reason', () {
    final result = notice([
      alarm('a', topic: 'db', reason: MissedReason.rangUnanswered),
    ])!;
    expect(result.count, 1);
    expect(result.incidentIds, ['a']);
    expect(result.topic, 'db');
    expect(result.at, now.subtract(const Duration(hours: 6)));
    expect(result.reason, MissedReason.rangUnanswered);
  });

  test('three missed alarms are one entry with a count of three, and the '
      'newest one named', () {
    final result = notice([
      alarm('a', ago: const Duration(days: 2), topic: 'old'),
      alarm(
        'b',
        ago: const Duration(hours: 1),
        topic: 'newest',
        reason: MissedReason.noPushReached,
      ),
      alarm('c', ago: const Duration(days: 1), topic: 'middle'),
    ])!;
    expect(result.count, 3);
    expect(result.incidentIds, ['b', 'c', 'a']);
    expect(result.topic, 'newest');
    expect(result.reason, MissedReason.noPushReached);
  });

  test('nothing shows before setup is done', () {
    expect(notice([alarm('a')], isSetupDone: false), isNull);
  });

  test('SetupGate holds it back until the Topics guide is over', () async {
    var guideSeen = false;
    final gate = SetupGate(
      isOnboardingDone: () async => true,
      hasSeenFeatureGuide: () => guideSeen,
    );
    expect(notice([alarm('a')], isSetupDone: await gate.isDone()), isNull);
    guideSeen = true;
    expect(notice([alarm('a')], isSetupDone: await gate.isDone()), isNotNull);
  });

  test('a closed alarm does not show, and does not count', () {
    expect(notice([alarm('a')], dismissed: {'a'}), isNull);
    final result = notice(
      [alarm('a'), alarm('b', ago: const Duration(hours: 9))],
      dismissed: {'a'},
    )!;
    expect(result.count, 1);
    expect(result.incidentIds, ['b']);
  });

  test('older than seven days does not show', () {
    expect(
      notice([alarm('a', ago: const Duration(days: 7, minutes: 1))]),
      isNull,
    );
  });

  test('closing sticks across launches, and a new miss still shows', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    MissedAlarmReader readerOver(SharedPreferences prefs) => MissedAlarmReader(
      store: SharedPrefsMissedAlarmStore(prefs),
      readIncidents: () => const [],
      readCriticalTopics: () async => const {},
      capture: () async => const PhoneCapture(),
      isSetupDone: () async => true,
      readServer: () async => 'https://alerts.example.com',
      firstLaunchAt: () => now,
      setupIncidentIds: () => const {},
      everyPushIsLogged: true,
      now: () => now,
    );

    final shown = notice([alarm('a'), alarm('b')])!;
    await readerOver(prefs).dismiss(shown.incidentIds);

    // The app is opened again: a new store over the same phone.
    final dismissed = SharedPrefsMissedAlarmStore(
      prefs,
    ).readDismissed().keys.toSet();
    expect(notice([alarm('a'), alarm('b')], dismissed: dismissed), isNull);
    final next = notice(
      [alarm('a'), alarm('b'), alarm('c', ago: const Duration(minutes: 20))],
      dismissed: dismissed,
    )!;
    expect(next.incidentIds, ['c']);
  });

  group('the card', () {
    test('every reason has its own words and its own face', () {
      expect(
        MissedReason.values.map(missedAlarmReasonKey).toSet(),
        hasLength(MissedReason.values.length),
      );
      expect(
        MissedReason.values.map(missedAlarmFace).toSet(),
        hasLength(MissedReason.values.length),
      );
      expect(
        missedAlarmReasonKey(MissedReason.unanswered),
        LocaleKeys.notices_missed_alarm_reason_unanswered,
      );
    });

    test('today reads as the hour, another day carries the weekday', () {
      final at = DateTime(2026, 10, 7, 3, 12);
      expect(
        missedAlarmTime(at, now: DateTime(2026, 10, 7, 8)),
        '03:12',
      );
      expect(
        missedAlarmTime(at, now: DateTime(2026, 10, 8, 8)),
        'Wed 03:12',
      );
    });
  });
}
