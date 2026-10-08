import 'package:critalarm/core/models/weekly_check.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/presentation/reliability_rows.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_access.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_standing.dart';
import 'package:critalarm/features/weekly_check/presentation/weekly_check_views.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 7, 9);
  final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
  const day = 24 * 60 * 60;

  WeeklyCheckBodyView view(
    WeeklyCheck? check, {
    bool missedByClock = false,
  }) => weeklyCheckBodyView(
    standing: weeklyCheckStanding(
      check: check,
      access: WeeklyCheckAccess.open,
      missedByClock: missedByClock,
    ),
    check: check,
    now: now,
  );

  WeeklyCheck on(WeeklyCheckState? state, {int misses = 0}) => WeeklyCheck(
    enabled: true,
    state: state,
    misses: misses,
    lastSentAt: nowSeconds - 2 * 3600,
    lastReceivedAt: state == WeeklyCheckState.received
        ? nowSeconds - 2 * 3600
        : null,
    nextDueAt: nowSeconds + 6 * day,
    noticeAfter: nowSeconds + 14 * day,
  );

  const neverOn = WeeklyCheck(
    enabled: false,
    state: WeeklyCheckState.off,
    reason: WeeklyCheckOffReason.disabled,
  );
  final off = WeeklyCheck(
    enabled: false,
    state: WeeklyCheckState.off,
    reason: WeeklyCheckOffReason.disabled,
    lastSentAt: nowSeconds - 9 * day,
  );

  group('the row, one line for each state', () {
    test('while off the line says what the check does', () {
      for (final v in [view(null), view(neverOn), view(off)]) {
        expect(v.lineKey, LocaleKeys.weekly_check_what_line);
        expect(v.isOn, isFalse);
      }
    });

    test('waiting for the first check', () {
      final v = view(on(WeeklyCheckState.waiting));
      expect(v.lineKey, LocaleKeys.weekly_check_line_waiting);
      expect(v.isOn, isTrue);
    });

    test('last check received, and when', () {
      final v = view(on(WeeklyCheckState.received));
      expect(v.lineKey, LocaleKeys.weekly_check_line_received);
      expect(v.lineWhen, '07:00');
      expect(v.isOn, isTrue);
    });

    test('received with no time from the relay still says received', () {
      final v = view(
        const WeeklyCheck(enabled: true, state: WeeklyCheckState.received),
      );
      expect(v.lineKey, LocaleKeys.weekly_check_line_received_plain);
      expect(v.lineWhen, isNull);
    });

    test('one missed needs a look', () {
      final v = view(on(WeeklyCheckState.missedOnce, misses: 1));
      expect(v.lineKey, LocaleKeys.weekly_check_line_missed_once);
      expect(v.isOn, isTrue);
    });

    test('missed repeatedly', () {
      final v = view(on(WeeklyCheckState.missedRepeatedly, misses: 2));
      expect(v.lineKey, LocaleKeys.weekly_check_line_missed_repeatedly);
    });

    test('the phone telling by its own clock reads the same', () {
      final v = view(on(WeeklyCheckState.received), missedByClock: true);
      expect(v.lineKey, LocaleKeys.weekly_check_line_missed_repeatedly);
    });

    test('the push token was refused', () {
      final v = view(on(WeeklyCheckState.tokenRefused, misses: 1));
      expect(v.lineKey, LocaleKeys.weekly_check_line_token_refused);
    });

    test('the relay holds no push token', () {
      final v = view(on(WeeklyCheckState.noToken));
      expect(v.lineKey, LocaleKeys.weekly_check_line_no_token);
    });

    test('a state this build does not know still shows the switch on', () {
      final v = view(on(null));
      expect(v.lineKey, LocaleKeys.weekly_check_what_line);
      expect(v.isOn, isTrue);
    });

    test('Hosted back, with the relay still answering from the lapse: the '
        'switch is on as the person left it', () {
      final v = view(
        WeeklyCheck(
          enabled: true,
          state: WeeklyCheckState.off,
          reason: WeeklyCheckOffReason.tier,
          lastSentAt: nowSeconds - 30 * day,
        ),
      );
      expect(v.isOn, isTrue);
      expect(v.lineKey, LocaleKeys.weekly_check_what_line);
    });

    test('no line of any state claims that alarms work', () {
      final keys = {
        view(null).lineKey,
        for (final state in WeeklyCheckState.values) view(on(state)).lineKey,
      };
      for (final key in keys) {
        expect(key.contains('proof'), isFalse);
        expect(key.contains('alarm'), isFalse);
      }
    });
  });

  group('the way to past checks', () {
    test('shows once the relay has sent a check', () {
      expect(weeklyCheckShowsRounds(on(WeeklyCheckState.waiting)), isTrue);
      expect(weeklyCheckShowsRounds(off), isTrue);
    });

    test('is not there before any was sent', () {
      expect(weeklyCheckShowsRounds(null), isFalse);
      expect(weeklyCheckShowsRounds(neverOn), isFalse);
      expect(
        weeklyCheckShowsRounds(
          const WeeklyCheck(enabled: true, state: WeeklyCheckState.waiting),
        ),
        isFalse,
      );
    });
  });

  group('a round: a face, its result in a few words, its time', () {
    WeeklyCheckRound round(String? result, {String? reason}) =>
        WeeklyCheckRound.fromJson({
          'id': 'rnd_1',
          'opened_at': nowSeconds - 3 * 3600,
          'closes_at': nowSeconds + 9 * 3600,
          'closed_at': result == null ? null : nowSeconds - 3 * 3600 + 4,
          'attempts': 1,
          'result': result,
          'reason': reason,
        });

    test('each result has a word', () {
      expect(
        weeklyCheckResultKey(round('received')),
        LocaleKeys.weekly_check_result_received,
      );
      expect(
        weeklyCheckResultKey(round('missed')),
        LocaleKeys.weekly_check_result_missed,
      );
      expect(
        weeklyCheckResultKey(round('refused')),
        LocaleKeys.weekly_check_result_refused,
      );
    });

    test('skipped says "switched off" only when that is the reason', () {
      expect(
        weeklyCheckResultKey(round('skipped', reason: 'disabled')),
        LocaleKeys.weekly_check_result_skipped_off,
      );
      // Every other reason the contract lists, and none at all.
      // `pack` is on a round that closed before 1.19.0.
      for (final reason in [
        'tier',
        'pack',
        'no_token',
        'held',
        'unsent',
        'a_reason_from_later',
        null,
      ]) {
        expect(
          weeklyCheckResultKey(round('skipped', reason: reason)),
          LocaleKeys.weekly_check_result_skipped,
          reason: '$reason',
        );
      }
    });

    test('a round still open says when it is due by', () {
      final open = round(null);
      expect(open.isOpen, isTrue);
      final v = weeklyCheckRoundView(open, now: now);
      expect(v.wordKey, LocaleKeys.weekly_check_result_open_due);
      // It closes at 18:00 today.
      expect(v.wordTime, '18:00');
      // One time on the row.
      expect(v.when, isNull);
    });

    test('an open round with no closing time is waiting', () {
      final open = WeeklyCheckRound(
        id: 'rnd_2',
        openedAt: nowSeconds - 3 * 3600,
        isOpen: true,
      );
      final v = weeklyCheckRoundView(open, now: now);
      expect(v.wordKey, LocaleKeys.weekly_check_result_open);
      expect(v.wordTime, isNull);
      expect(v.when, '06:00');
    });

    test('a result this build does not know is closed, not open', () {
      final odd = round('paused');
      expect(odd.isOpen, isFalse);
      expect(weeklyCheckResultKey(odd), LocaleKeys.weekly_check_result_closed);
    });

    test('a closed round is listed at the time it opened', () {
      final v = weeklyCheckRoundView(round('missed'), now: now);
      expect(v.when, '06:00');
      expect(v.wordTime, isNull);
      final old = WeeklyCheckRound(
        id: 'rnd_0',
        openedAt: nowSeconds - 7 * day,
        result: WeeklyCheckResult.received,
      );
      expect(weeklyCheckRoundView(old, now: now).when, 'Wed 30 Sep, 09:00');
    });

    test('a missed or refused round wears the face of a broken check', () {
      final broken = reliabilityStateFace(ReliabilityState.broken);
      expect(broken, FaceState.sad);
      expect(weeklyCheckResultFace(round('missed')), broken);
      expect(weeklyCheckResultFace(round('refused')), broken);
    });

    test('a received round is a tick with no face', () {
      expect(weeklyCheckResultFace(round('received')), isNull);
      expect(weeklyCheckResultShowsTick(round('received')), isTrue);
    });

    test('skipped, open and closed rounds have no mark', () {
      for (final r in [
        round('skipped'),
        round(null),
        round('paused'),
        round('missed'),
        round('refused'),
      ]) {
        expect(weeklyCheckResultShowsTick(r), isFalse, reason: '${r.result}');
      }
      for (final r in [round('skipped'), round(null), round('paused')]) {
        expect(weeklyCheckResultFace(r), isNull, reason: '${r.result}');
      }
    });
  });
}
