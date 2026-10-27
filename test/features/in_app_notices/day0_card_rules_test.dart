import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/in_app_notices/domain/day0_card_rules.dart';
import 'package:critalarm/features/in_app_notices/domain/home_ask_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_in_app_notice_repository.dart';
import '../topics/support/home_setup_fakes.dart';

class _MockAccount extends Mock implements AccountRepository {}

void main() {
  final now = DateTime(2026, 10, 7, 10);

  /// Everything true, nothing shown before: the card starts.
  Day0CardDecision decide({
    bool isHosted = true,
    bool holdsHosted = false,
    bool isSetupDone = true,
    bool isFirstMessageReceived = true,
    DateTime? firstRealAckAt,
    bool hasFirstRealAck = true,
    DateTime? shownAt,
    DateTime? endedAt,
    int openCount = 0,
    bool isNewOpen = true,
    bool isWeb = false,
    bool isRinging = false,
    bool isAskDue = false,
    List<DateTime?> otherAskedAt = const [],
  }) => Day0CardRules.decide(
    isHosted: isHosted,
    holdsHosted: holdsHosted,
    isSetupDone: isSetupDone,
    isFirstMessageReceived: isFirstMessageReceived,
    firstRealAckAt: hasFirstRealAck
        ? (firstRealAckAt ?? now.subtract(const Duration(days: 2)))
        : null,
    shownAt: shownAt,
    endedAt: endedAt,
    openCount: openCount,
    isNewOpen: isNewOpen,
    now: now,
    isWeb: isWeb,
    isRinging: isRinging,
    isAskDue: isAskDue,
    otherAskedAt: otherAskedAt,
  );

  group('Day0CardRules.decide, starting', () {
    test('starts when every condition holds', () {
      expect(decide(), Day0CardDecision.start);
    });

    test('a server that is not hosted keeps it away', () {
      expect(decide(isHosted: false), Day0CardDecision.none);
    });

    test('a paid account keeps it away', () {
      expect(decide(holdsHosted: true), Day0CardDecision.none);
    });

    test('setup not done keeps it away', () {
      expect(decide(isSetupDone: false), Day0CardDecision.none);
    });

    test('no first message keeps it away', () {
      expect(decide(isFirstMessageReceived: false), Day0CardDecision.none);
    });

    test('no first real acknowledge keeps it away', () {
      expect(decide(hasFirstRealAck: false), Day0CardDecision.none);
    });

    test('web keeps it away', () {
      expect(decide(isWeb: true), Day0CardDecision.none);
    });

    test('a ringing alarm keeps it away', () {
      expect(decide(isRinging: true), Day0CardDecision.none);
    });

    test('a sheet due in the same visit keeps it away', () {
      expect(decide(isAskDue: true), Day0CardDecision.none);
    });

    test('a card that ended never comes back', () {
      expect(
        decide(endedAt: now.subtract(const Duration(days: 1))),
        Day0CardDecision.none,
      );
      expect(
        decide(
          shownAt: now.subtract(const Duration(days: 9)),
          endedAt: now.subtract(const Duration(days: 8)),
        ),
        Day0CardDecision.none,
      );
    });
  });

  group('Day0CardRules.decide, the 24 hour gap', () {
    test('waits while any other ask is inside the gap', () {
      for (var i = 0; i < 4; i++) {
        final asks = List<DateTime?>.filled(4, null);
        asks[i] = now.subtract(const Duration(hours: 2));
        expect(
          decide(otherAskedAt: asks),
          Day0CardDecision.none,
          reason: 'ask $i',
        );
      }
    });

    test('starts once the gap has passed', () {
      expect(
        decide(otherAskedAt: [now.subtract(HomeAskRules.gap)]),
        Day0CardDecision.start,
      );
      expect(
        decide(
          otherAskedAt: [
            now.subtract(HomeAskRules.gap - const Duration(minutes: 1)),
          ],
        ),
        Day0CardDecision.none,
      );
    });

    test('the card counts as an ask for the others', () {
      // The card shown 2 hours ago is a stamp the other rules read.
      expect(
        HomeAskRules.isWithinGap(
          now: now,
          askedAt: [now.subtract(const Duration(hours: 2))],
        ),
        isTrue,
      );
    });
  });

  group('Day0CardRules.decide, once shown', () {
    final shownAt = DateTime(2026, 10, 6, 10);

    test('keeps showing, and the gap does not apply to itself', () {
      expect(
        decide(
          shownAt: shownAt,
          openCount: 1,
          otherAskedAt: [now.subtract(const Duration(hours: 1))],
        ),
        Day0CardDecision.keep,
      );
    });

    test('is never started a second time', () {
      expect(
        decide(shownAt: shownAt, openCount: 1),
        isNot(Day0CardDecision.start),
      );
    });

    test('ends on the open after the third', () {
      expect(
        decide(shownAt: shownAt, openCount: 2),
        Day0CardDecision.keep,
      );
      expect(
        decide(shownAt: shownAt, openCount: Day0CardRules.maxOpens),
        Day0CardDecision.end,
      );
    });

    test('a look that is not a new open does not use up the third', () {
      expect(
        decide(
          shownAt: shownAt,
          openCount: Day0CardRules.maxOpens,
          isNewOpen: false,
        ),
        Day0CardDecision.keep,
      );
    });

    test('goes quiet when the user pays, or on web, or in an alarm', () {
      expect(
        decide(shownAt: shownAt, openCount: 1, holdsHosted: true),
        Day0CardDecision.none,
      );
      expect(
        decide(shownAt: shownAt, openCount: 1, isWeb: true),
        Day0CardDecision.none,
      );
      expect(
        decide(shownAt: shownAt, openCount: 1, isRinging: true),
        Day0CardDecision.none,
      );
    });
  });

  group('Day0CardRules.next', () {
    late FakeInAppNoticeRepository notices;
    late _MockAccount account;
    late FakeFirstMessageStore firstMessage;

    setUp(() {
      notices = FakeInAppNoticeRepository()..now = () => now;
      account = _MockAccount();
      when(account.readHoldsHosted).thenAnswer((_) async => false);
      when(account.readServerMode).thenAnswer((_) async => ServerMode.hosted);
      firstMessage = FakeFirstMessageStore()..isReceived = true;
      notices.firstRealAcknowledgedAt = now.subtract(const Duration(days: 1));
    });

    Day0CardRules rules({bool isRinging = false}) => Day0CardRules(
      noticeRepository: notices,
      accountRepository: account,
      firstMessageStore: firstMessage,
      isWeb: false,
      now: () => now,
      isRinging: () => isRinging,
    );

    test('reads the stored stamps and starts', () async {
      expect(await rules().next(isNewOpen: true), Day0CardDecision.start);
    });

    test('a failed paid read counts as paid', () async {
      when(account.readHoldsHosted).thenThrow(StateError('keychain'));
      expect(await rules().next(isNewOpen: true), Day0CardDecision.none);
    });

    test('reads every other ask stamp for the gap', () async {
      final recent = now.subtract(const Duration(hours: 3));
      for (final set in <void Function()>[
        () => notices.proAskedAt = recent,
        () => notices.consentAskedAt = recent,
        () => notices.reviewAskedAt = recent,
        () => notices.feedbackAskedAt = recent,
      ]) {
        notices
          ..proAskedAt = null
          ..consentAskedAt = null
          ..reviewAskedAt = null
          ..feedbackAskedAt = null;
        set();
        expect(await rules().next(isNewOpen: true), Day0CardDecision.none);
      }
    });

    test('a ringing alarm keeps it away', () async {
      expect(
        await rules(isRinging: true).next(isNewOpen: true),
        Day0CardDecision.none,
      );
    });
  });

  group('countsAsHomeOpen', () {
    test('a resume with Home in front counts', () {
      expect(
        countsAsHomeOpen(
          isCovered: false,
          isRouteElsewhere: false,
          isTabShown: true,
        ),
        isTrue,
      );
    });

    test('a resume with another screen pushed over Home does not', () {
      expect(
        countsAsHomeOpen(
          isCovered: true,
          isRouteElsewhere: false,
          isTabShown: true,
        ),
        isFalse,
      );
    });

    test('a resume while the router shows another screen does not', () {
      expect(
        countsAsHomeOpen(
          isCovered: false,
          isRouteElsewhere: true,
          isTabShown: true,
        ),
        isFalse,
      );
    });

    test('a resume on another tab does not', () {
      expect(
        countsAsHomeOpen(
          isCovered: false,
          isRouteElsewhere: false,
          isTabShown: false,
        ),
        isFalse,
      );
    });
  });
}
