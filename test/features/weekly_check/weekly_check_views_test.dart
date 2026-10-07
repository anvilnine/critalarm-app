import 'package:critalarm/core/models/weekly_check.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/weekly_check/presentation/weekly_check_views.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 7, 9);
  final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
  const day = 24 * 60 * 60;

  WeeklyCheckBodyView view(
    WeeklyCheck? check, {
    bool isSelfHosted = false,
  }) => weeklyCheckBodyView(
    check: check,
    isSelfHosted: isSelfHosted,
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

  group('the row, one line for each state', () {
    test('before the relay has answered it is ready to switch on', () {
      final v = view(null);
      expect(v.lineKey, LocaleKeys.pro_pack_weekly_ready_line);
      expect(v.isOn, isFalse);
      expect(v.nextDueKey, isNull);
    });

    test('waiting for the first check', () {
      final v = view(on(WeeklyCheckState.waiting));
      expect(v.lineKey, LocaleKeys.weekly_check_line_waiting);
      expect(v.isOn, isTrue);
      expect(v.nextDueKey, LocaleKeys.weekly_check_next_due);
      expect(v.nextDueWhen, isNotEmpty);
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

    test('the push token was refused', () {
      final v = view(on(WeeklyCheckState.tokenRefused, misses: 1));
      expect(v.lineKey, LocaleKeys.weekly_check_line_token_refused);
    });

    test('the relay holds no push token', () {
      final v = view(on(WeeklyCheckState.noToken));
      expect(v.lineKey, LocaleKeys.weekly_check_line_no_token);
    });

    test('switched off', () {
      final v = view(
        WeeklyCheck(
          enabled: false,
          state: WeeklyCheckState.off,
          reason: WeeklyCheckOffReason.disabled,
          lastSentAt: nowSeconds - 9 * day,
        ),
      );
      expect(v.lineKey, LocaleKeys.weekly_check_line_off);
      expect(v.isOn, isFalse);
      expect(v.nextDueKey, isNull);
    });

    test('never switched on reads as ready, not as switched off', () {
      final v = view(
        const WeeklyCheck(
          enabled: false,
          state: WeeklyCheckState.off,
          reason: WeeklyCheckOffReason.disabled,
        ),
      );
      expect(v.lineKey, LocaleKeys.pro_pack_weekly_ready_line);
    });

    test('the pack was lost', () {
      final v = view(
        const WeeklyCheck(
          enabled: true,
          state: WeeklyCheckState.off,
          reason: WeeklyCheckOffReason.pack,
        ),
      );
      expect(v.lineKey, LocaleKeys.weekly_check_line_pack_lost);
      expect(v.isOn, isFalse);
      expect(v.showsSelfHostedLine, isFalse);
    });

    test('a state this build does not know still shows the switch on', () {
      final v = view(on(null));
      expect(v.lineKey, LocaleKeys.weekly_check_line_on);
      expect(v.isOn, isTrue);
    });

    test('each state has its own face', () {
      final faces = [
        view(null).face,
        for (final state in WeeklyCheckState.values)
          if (state != WeeklyCheckState.off) view(on(state)).face,
        view(
          const WeeklyCheck(
            enabled: true,
            state: WeeklyCheckState.off,
            reason: WeeklyCheckOffReason.pack,
          ),
        ).face,
      ];
      expect(faces.toSet().length, faces.length);
      // Received keeps the face the unlocked row had before the check.
      expect(view(on(WeeklyCheckState.received)).face, FaceState.confident);
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

  group('when the next check is due', () {
    test('a day ahead is named', () {
      final v = view(on(WeeklyCheckState.received));
      expect(v.nextDueKey, LocaleKeys.weekly_check_next_due);
      expect(v.nextDueWhen, weeklyCheckDay(nowSeconds + 6 * day));
    });

    test('a moment already passed just says it is due', () {
      final v = view(
        WeeklyCheck(
          enabled: true,
          state: WeeklyCheckState.missedOnce,
          misses: 1,
          nextDueAt: nowSeconds - 60,
        ),
      );
      expect(v.nextDueKey, LocaleKeys.weekly_check_next_due_now);
      expect(v.nextDueWhen, isNull);
    });
  });

  group('on a self-hosted phone', () {
    test('every enrolled state carries the relay line', () {
      for (final state in WeeklyCheckState.values) {
        if (state == WeeklyCheckState.off) continue;
        expect(
          view(on(state), isSelfHosted: true).showsSelfHostedLine,
          isTrue,
          reason: state.name,
        );
      }
    });

    test('a cloud phone never does', () {
      for (final state in WeeklyCheckState.values) {
        expect(view(on(state)).showsSelfHostedLine, isFalse);
      }
    });

    test('switched off says nothing more', () {
      final v = view(
        const WeeklyCheck(
          enabled: false,
          state: WeeklyCheckState.off,
          reason: WeeklyCheckOffReason.disabled,
        ),
        isSelfHosted: true,
      );
      expect(v.showsSelfHostedLine, isFalse);
    });
  });

  group('a round, its result in a word', () {
    WeeklyCheckRound round(String? result) => WeeklyCheckRound.fromJson({
      'id': 'rnd_1',
      'opened_at': nowSeconds - 3 * 3600,
      'closes_at': nowSeconds + 21 * 3600,
      'closed_at': result == null ? null : nowSeconds - 3 * 3600 + 4,
      'attempts': 1,
      'result': result,
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
      expect(
        weeklyCheckResultKey(round('skipped')),
        LocaleKeys.weekly_check_result_skipped,
      );
    });

    test('a round still open is waiting', () {
      expect(round(null).isOpen, isTrue);
      expect(
        weeklyCheckResultKey(round(null)),
        LocaleKeys.weekly_check_result_open,
      );
    });

    test('a result this build does not know is closed, not open', () {
      final odd = round('paused');
      expect(odd.isOpen, isFalse);
      expect(weeklyCheckResultKey(odd), LocaleKeys.weekly_check_result_closed);
    });

    test('the time is when the round opened', () {
      expect(weeklyCheckRoundView(round('missed'), now: now).when, '06:00');
      final old = WeeklyCheckRound(
        id: 'rnd_0',
        openedAt: nowSeconds - 7 * day,
        result: WeeklyCheckResult.received,
      );
      expect(
        weeklyCheckRoundView(old, now: now).when,
        'Wed 30 Sep, 09:00',
      );
    });
  });
}
