import 'package:critalarm/core/models/weekly_check.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_notice_rule.dart';
import 'package:flutter_test/flutter_test.dart';

// Every time below is epoch seconds. The relay's answer was seen at 1000.
const int _day = 24 * 60 * 60;
const _seenAt = 1000;
const int _noticeAfter = _seenAt + 8 * _day;

WeeklyCheck _check({
  WeeklyCheckState state = WeeklyCheckState.received,
  int misses = 0,
  bool enabled = true,
  int? noticeAfter = _noticeAfter,
  int? lastReceivedAt,
  WeeklyCheckOffReason? reason,
}) => WeeklyCheck(
  enabled: enabled,
  state: state,
  reason: reason,
  misses: misses,
  noticeAfter: noticeAfter,
  lastReceivedAt: lastReceivedAt,
);

bool _shows(
  WeeklyCheck check, {
  required int now,
  bool isSetupDone = true,
  int? lastArrivalAt,
  int? dismissedAt,
  int? noticeAfter,
  int? noticeAfterSeenAt,
}) => WeeklyCheckNoticeRule.shouldShow(
  isSetupDone: isSetupDone,
  now: now,
  facts: WeeklyCheckNoticeFacts(
    check: check,
    checkSeenAt: _seenAt,
    noticeAfter: noticeAfter ?? check.noticeAfter,
    noticeAfterSeenAt: noticeAfterSeenAt ?? _seenAt,
    lastArrivalAt: lastArrivalAt,
    dismissedAt: dismissedAt,
  ),
);

void main() {
  test('nothing to say before the relay has answered', () {
    expect(
      WeeklyCheckNoticeRule.shouldShow(
        isSetupDone: true,
        facts: null,
        now: _seenAt,
      ),
      isFalse,
    );
  });

  test('a received check raises nothing', () {
    expect(_shows(_check(), now: _seenAt + 60), isFalse);
  });

  test('one miss raises nothing on Home', () {
    final check = _check(
      state: WeeklyCheckState.missedOnce,
      misses: 1,
      noticeAfter: _seenAt + _day,
    );
    expect(_shows(check, now: _seenAt + 60), isFalse);
  });

  test('two misses in a row show the notice', () {
    final check = _check(
      state: WeeklyCheckState.missedRepeatedly,
      misses: 2,
      // In the past, as the relay sends it once the run reached two.
      noticeAfter: _seenAt - 3600,
    );
    expect(_shows(check, now: _seenAt + 60), isTrue);
  });

  test('a refused token twice in a row counts the same', () {
    final check = _check(state: WeeklyCheckState.missedRepeatedly, misses: 3);
    expect(_shows(check, now: _seenAt + 60), isTrue);
  });

  group('the phone telling by its own clock', () {
    test('before notice_after nothing shows', () {
      expect(_shows(_check(), now: _noticeAfter - 1), isFalse);
    });

    test('once the clock passes notice_after the notice shows', () {
      expect(_shows(_check(), now: _noticeAfter), isTrue);
      expect(_shows(_check(), now: _noticeAfter + 30 * _day), isTrue);
    });

    test('with no notice_after the clock decides nothing', () {
      expect(
        WeeklyCheckNoticeRule.shouldShow(
          isSetupDone: true,
          now: _noticeAfter + _day,
          facts: WeeklyCheckNoticeFacts(
            check: _check(noticeAfter: null),
            checkSeenAt: _seenAt,
          ),
        ),
        isFalse,
      );
    });

    test('a check that arrived after the answer was seen holds it back', () {
      expect(
        _shows(_check(), now: _noticeAfter + 60, lastArrivalAt: _seenAt + 500),
        isFalse,
      );
    });

    test('a check that arrived before the answer was seen does not', () {
      expect(
        _shows(_check(), now: _noticeAfter + 60, lastArrivalAt: _seenAt - 500),
        isTrue,
      );
    });

    test('a receipt answer moves notice_after on, and that one is used', () {
      // The native handler answered a check at 5000 and the relay handed
      // back a later notice_after.
      const arrivedAt = 5000;
      const later = arrivedAt + 8 * _day;
      bool at(int now) => _shows(
        _check(),
        now: now,
        lastArrivalAt: arrivedAt,
        noticeAfter: later,
        noticeAfterSeenAt: arrivedAt + 1,
      );
      expect(at(_noticeAfter + 60), isFalse);
      expect(at(later - 1), isFalse);
      expect(at(later), isTrue);
    });
  });

  group('a check that arrived and whose receipt never landed', () {
    // The phone holds the relay's old answer and one arrival after it. No
    // newer answer: the receipt failed, or the phone has been offline since.
    const arrivedAt = _seenAt + 6 * _day;
    final deadline = WeeklyCheckNoticeRule.deadlineAfterArrival(arrivedAt);

    bool at(int now, {WeeklyCheck? check, int? dismissedAt}) => _shows(
      check ?? _check(),
      now: now,
      lastArrivalAt: arrivedAt,
      dismissedAt: dismissedAt,
    );

    test('the window is the longest gap the contract allows plus a round', () {
      expect(WeeklyCheckNoticeRule.longestGapBetweenRounds, 10 * _day);
      expect(WeeklyCheckNoticeRule.roundOpenFor, _day);
      expect(WeeklyCheckNoticeRule.missWindow, 11 * _day);
      expect(deadline, arrivedAt + 22 * _day);
    });

    test('it ends the window it fell in', () {
      // The relay's notice_after has passed, and this arrival answers it.
      expect(at(_noticeAfter + 60), isFalse);
    });

    test('one more window of silence is one miss and shows nothing', () {
      expect(at(arrivedAt + 11 * _day + 60), isFalse);
      expect(at(deadline - 1), isFalse);
    });

    test('two windows of silence offline show the notice', () {
      expect(at(deadline), isTrue);
      expect(at(deadline + 90 * _day), isTrue);
    });

    test('it does not hide later misses behind an old count either', () {
      final twice = _check(
        state: WeeklyCheckState.missedRepeatedly,
        misses: 2,
        noticeAfter: _seenAt - 3600,
      );
      expect(at(arrivedAt + 60, check: twice), isFalse);
      expect(at(deadline, check: twice), isTrue);
    });

    test('a newer arrival moves the deadline on', () {
      const later = arrivedAt + 7 * _day;
      expect(
        _shows(_check(), now: deadline, lastArrivalAt: later),
        isFalse,
      );
      expect(
        _shows(
          _check(),
          now: WeeklyCheckNoticeRule.deadlineAfterArrival(later),
          lastArrivalAt: later,
        ),
        isTrue,
      );
    });

    test('closed before the arrival, the later run still shows', () {
      expect(at(deadline, dismissedAt: _seenAt + 100), isTrue);
    });

    test('closed after the arrival, it stays gone', () {
      expect(at(deadline + _day, dismissedAt: deadline + 60), isFalse);
    });
  });

  group('an arrival the phone cannot place', () {
    test('with none known the relay answer stands', () {
      expect(_shows(_check(), now: _noticeAfter - 1), isFalse);
      expect(_shows(_check(), now: _noticeAfter), isTrue);
    });

    test('a time in the future neither hides nor raises', () {
      const absurd = 4000000000;
      expect(
        _shows(_check(), now: _noticeAfter - 1, lastArrivalAt: absurd),
        isFalse,
      );
      expect(
        _shows(_check(), now: _noticeAfter, lastArrivalAt: absurd),
        isTrue,
      );
      final twice = _check(state: WeeklyCheckState.missedRepeatedly, misses: 2);
      expect(_shows(twice, now: _seenAt + 60, lastArrivalAt: absurd), isTrue);
    });

    test('zero or less is no arrival', () {
      expect(_shows(_check(), now: _noticeAfter, lastArrivalAt: 0), isTrue);
      expect(_shows(_check(), now: _noticeAfter, lastArrivalAt: -5), isTrue);
    });
  });

  test('a check arriving after two misses takes the notice away', () {
    final check = _check(state: WeeklyCheckState.missedRepeatedly, misses: 2);
    expect(
      _shows(
        check,
        now: _seenAt + 600,
        lastArrivalAt: _seenAt + 300,
        // The receipt answer that came with it.
        noticeAfter: _seenAt + 300 + 8 * _day,
        noticeAfterSeenAt: _seenAt + 301,
      ),
      isFalse,
    );
  });

  group('closing it', () {
    final check = _check(state: WeeklyCheckState.missedRepeatedly, misses: 2);

    test('keeps it gone for this run of misses', () {
      expect(
        _shows(check, now: _seenAt + 600, dismissedAt: _seenAt + 100),
        isFalse,
      );
      // Still the same run a month on, with a third and a fourth miss.
      expect(
        _shows(
          _check(state: WeeklyCheckState.missedRepeatedly, misses: 4),
          now: _seenAt + 30 * _day,
          dismissedAt: _seenAt + 100,
        ),
        isFalse,
      );
    });

    test('a later run of misses shows it again', () {
      // A check reached the phone after the close, so that run ended. The
      // clock then passed the notice_after its receipt brought.
      const arrivedAt = _seenAt + 2 * _day;
      const later = arrivedAt + 8 * _day;
      expect(
        _shows(
          _check(),
          now: later + 60,
          dismissedAt: _seenAt + 100,
          lastArrivalAt: arrivedAt,
          noticeAfter: later,
          noticeAfterSeenAt: arrivedAt + 1,
        ),
        isTrue,
      );
    });

    test('a later run the relay reports shows it again', () {
      // The relay counted a receipt after the close, then two more misses.
      expect(
        _shows(
          _check(
            state: WeeklyCheckState.missedRepeatedly,
            misses: 2,
            lastReceivedAt: _seenAt + 2 * _day,
          ),
          now: _seenAt + 20 * _day,
          dismissedAt: _seenAt + 100,
        ),
        isTrue,
      );
    });

    test('closing the later run keeps that one gone too', () {
      const arrivedAt = _seenAt + 2 * _day;
      const later = arrivedAt + 8 * _day;
      expect(
        _shows(
          _check(),
          now: later + 600,
          dismissedAt: later + 60,
          lastArrivalAt: arrivedAt,
          noticeAfter: later,
          noticeAfterSeenAt: arrivedAt + 1,
        ),
        isFalse,
      );
    });
  });

  group('two rounds missed, for the Reliability screen', () {
    bool missed(WeeklyCheck check, {required int now, int? dismissedAt}) =>
        WeeklyCheckNoticeRule.twoRoundsMissed(
          now: now,
          facts: WeeklyCheckNoticeFacts(
            check: check,
            checkSeenAt: _seenAt,
            noticeAfter: check.noticeAfter,
            noticeAfterSeenAt: _seenAt,
            dismissedAt: dismissedAt,
          ),
        );

    test('it is the notice without setup and without the close', () {
      final twice = _check(state: WeeklyCheckState.missedRepeatedly, misses: 2);
      expect(missed(twice, now: _seenAt + 60), isTrue);
      // Closing the Home notice does not make the screen say all good.
      expect(
        missed(twice, now: _seenAt + 600, dismissedAt: _seenAt + 100),
        isTrue,
      );
      expect(
        _shows(twice, now: _seenAt + 600, dismissedAt: _seenAt + 100),
        isFalse,
      );
    });

    test('whenever the notice shows, this is true', () {
      for (final (check, now) in [
        (_check(), _noticeAfter),
        (_check(state: WeeklyCheckState.missedRepeatedly, misses: 2), _seenAt),
      ]) {
        expect(_shows(check, now: now), isTrue);
        expect(missed(check, now: now), isTrue);
      }
    });

    test('one miss, off and nothing known are false', () {
      expect(
        missed(
          _check(state: WeeklyCheckState.missedOnce, misses: 1),
          now: _seenAt + 60,
        ),
        isFalse,
      );
      expect(
        missed(
          _check(state: WeeklyCheckState.off, enabled: false, misses: 2),
          now: _noticeAfter + _day,
        ),
        isFalse,
      );
      expect(
        WeeklyCheckNoticeRule.twoRoundsMissed(facts: null, now: _noticeAfter),
        isFalse,
      );
    });
  });

  group('never shows', () {
    final twice = _check(state: WeeklyCheckState.missedRepeatedly, misses: 2);

    test('before setup is done', () {
      expect(_shows(twice, now: _seenAt + 60, isSetupDone: false), isFalse);
    });

    test('while the check is switched off', () {
      final off = _check(
        state: WeeklyCheckState.off,
        enabled: false,
        reason: WeeklyCheckOffReason.disabled,
        misses: 2,
      );
      expect(_shows(off, now: _noticeAfter + _day), isFalse);
    });

    test('once the pack was lost', () {
      final lost = _check(
        state: WeeklyCheckState.off,
        reason: WeeklyCheckOffReason.pack,
        misses: 2,
      );
      expect(_shows(lost, now: _noticeAfter + _day), isFalse);
    });
  });
}
