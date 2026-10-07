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
