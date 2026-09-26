import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/in_app_notices/domain/home_ask_rules.dart';
import 'package:critalarm/features/settings/domain/entities/privacy_settings.dart';
import 'package:critalarm/features/settings/domain/repositories/privacy_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_in_app_notice_repository.dart';

void main() {
  // 10:00 on 21 September. Every case below counts from here.
  final now = DateTime(2026, 9, 21, 10);

  HomeAsk decide({
    DateTime? firstSeenAt,
    DateTime? consentAskedAt,
    bool isConsentGiven = false,
    DateTime? reviewAskedAt,
    int reviewAskCount = 0,
    DateTime? lastAcknowledgedAt,
    DateTime? proAskedAt,
    bool isRinging = false,
    bool isWeb = false,
  }) {
    return HomeAskRules.decide(
      now: now,
      firstSeenAt: firstSeenAt,
      consentAskedAt: consentAskedAt,
      isConsentGiven: isConsentGiven,
      reviewAskedAt: reviewAskedAt,
      reviewAskCount: reviewAskCount,
      lastAcknowledgedAt: lastAcknowledgedAt,
      proAskedAt: proAskedAt,
      isRinging: isRinging,
      isWeb: isWeb,
      isSetupDone: true,
    );
  }

  group('consent sheet', () {
    test('asks on the first open of a later calendar day', () {
      // 23:50 yesterday is still yesterday, so ten minutes is enough.
      expect(
        decide(firstSeenAt: DateTime(2026, 9, 20, 23, 50)),
        HomeAsk.consent,
      );
    });

    test('waits while the install is still on its first day', () {
      expect(decide(firstSeenAt: DateTime(2026, 9, 21, 0, 5)), HomeAsk.none);
    });

    test('waits when home has never opened', () {
      expect(decide(), HomeAsk.none);
    });

    test('never asks twice', () {
      expect(
        decide(
          firstSeenAt: DateTime(2026, 9),
          consentAskedAt: DateTime(2026, 9, 2),
        ),
        HomeAsk.none,
      );
    });

    test('skips when both switches are already on', () {
      expect(
        decide(firstSeenAt: DateTime(2026, 9), isConsentGiven: true),
        HomeAsk.none,
      );
    });

    test('skips on web', () {
      expect(
        decide(firstSeenAt: DateTime(2026, 9), isWeb: true),
        HomeAsk.none,
      );
    });

    test('skips while an alarm is ringing', () {
      expect(
        decide(firstSeenAt: DateTime(2026, 9), isRinging: true),
        HomeAsk.none,
      );
    });

    test('skips within 24 hours of the Pro sheet', () {
      expect(
        decide(
          firstSeenAt: DateTime(2026, 9),
          proAskedAt: now.subtract(const Duration(hours: 23)),
        ),
        HomeAsk.none,
      );
    });

    test('comes before the review popup when both are due', () {
      expect(
        decide(
          firstSeenAt: DateTime(2026, 9),
          lastAcknowledgedAt: DateTime(2026, 9, 20, 23),
        ),
        HomeAsk.consent,
      );
    });
  });

  group('review popup', () {
    // Consent already answered, so only the review rules decide.
    HomeAsk decideReview({
      DateTime? firstSeenAt,
      DateTime? reviewAskedAt,
      int reviewAskCount = 0,
      DateTime? lastAcknowledgedAt,
      DateTime? proAskedAt,
      bool isRinging = false,
      bool isWeb = false,
    }) {
      return decide(
        firstSeenAt: firstSeenAt ?? DateTime(2026, 9),
        consentAskedAt: DateTime(2026, 9, 2),
        reviewAskedAt: reviewAskedAt,
        reviewAskCount: reviewAskCount,
        lastAcknowledgedAt: lastAcknowledgedAt,
        proAskedAt: proAskedAt,
        isRinging: isRinging,
        isWeb: isWeb,
      );
    }

    test('asks the calendar day after an acknowledge', () {
      expect(
        decideReview(lastAcknowledgedAt: DateTime(2026, 9, 20, 23, 14)),
        HomeAsk.review,
      );
    });

    test('waits on the same day as the acknowledge', () {
      expect(
        decideReview(lastAcknowledgedAt: DateTime(2026, 9, 21, 2)),
        HomeAsk.none,
      );
    });

    test('never asks without an acknowledge', () {
      expect(decideReview(), HomeAsk.none);
    });

    test('waits until the install is 3 days old', () {
      expect(
        decideReview(
          firstSeenAt: DateTime(2026, 9, 19, 12),
          lastAcknowledgedAt: DateTime(2026, 9, 20),
        ),
        HomeAsk.none,
      );
    });

    test('needs a new acknowledge since the last ask', () {
      expect(
        decideReview(
          lastAcknowledgedAt: DateTime(2026, 1, 10),
          reviewAskedAt: DateTime(2026, 1, 11),
          reviewAskCount: 1,
        ),
        HomeAsk.none,
      );
    });

    test('waits 120 days between asks', () {
      expect(
        decideReview(
          reviewAskedAt: now.subtract(const Duration(days: 119)),
          reviewAskCount: 1,
          lastAcknowledgedAt: DateTime(2026, 9, 20),
        ),
        HomeAsk.none,
      );
      expect(
        decideReview(
          reviewAskedAt: now.subtract(const Duration(days: 120)),
          reviewAskCount: 1,
          lastAcknowledgedAt: DateTime(2026, 9, 20),
        ),
        HomeAsk.review,
      );
    });

    test('stops after 3 asks', () {
      expect(
        decideReview(
          reviewAskedAt: DateTime(2025),
          reviewAskCount: 3,
          lastAcknowledgedAt: DateTime(2026, 9, 20),
        ),
        HomeAsk.none,
      );
    });

    test('skips on web', () {
      expect(
        decideReview(lastAcknowledgedAt: DateTime(2026, 9, 20), isWeb: true),
        HomeAsk.none,
      );
    });

    test('skips while an alarm is ringing', () {
      expect(
        decideReview(
          lastAcknowledgedAt: DateTime(2026, 9, 20),
          isRinging: true,
        ),
        HomeAsk.none,
      );
    });

    test('skips within 24 hours of the Pro sheet', () {
      expect(
        decideReview(
          lastAcknowledgedAt: DateTime(2026, 9, 20),
          proAskedAt: DateTime(2026, 9, 20, 23, 14),
        ),
        HomeAsk.none,
      );
    });
  });

  group('24 hour gap', () {
    test('counts the consent sheet against the review popup', () {
      expect(
        decide(
          firstSeenAt: DateTime(2026, 9),
          consentAskedAt: now.subtract(const Duration(hours: 2)),
          lastAcknowledgedAt: DateTime(2026, 9, 20),
        ),
        HomeAsk.none,
      );
    });

    test('isWithinGap reads the latest of the given asks', () {
      expect(
        HomeAskRules.isWithinGap(
          now: now,
          askedAt: [
            null,
            now.subtract(const Duration(days: 3)),
            now.subtract(const Duration(hours: 5)),
          ],
        ),
        isTrue,
      );
      expect(
        HomeAskRules.isWithinGap(
          now: now,
          askedAt: [
            now.subtract(const Duration(hours: 24)),
          ],
        ),
        isFalse,
      );
    });
  });

  group('reminders', () {
    HomeAsk review({
      required DateTime lastAcknowledgedAt,
      DateTime? feedbackAskedAt,
      DateTime? at,
    }) => HomeAskRules.decide(
      now: at ?? now,
      firstSeenAt: DateTime(2026, 9),
      consentAskedAt: DateTime(2026, 9, 2),
      isConsentGiven: false,
      reviewAskedAt: null,
      reviewAskCount: 0,
      lastAcknowledgedAt: lastAcknowledgedAt,
      proAskedAt: null,
      isRinging: false,
      isWeb: false,
      isSetupDone: true,
      feedbackAskedAt: feedbackAskedAt,
    );

    test('skips the review popup within 24 hours of a night ack', () {
      // Acked at 03:00 on 20 September; home opens 23 hours later.
      expect(
        review(
          lastAcknowledgedAt: DateTime(2026, 9, 20, 3),
          at: DateTime(2026, 9, 21, 2),
        ),
        HomeAsk.none,
      );
    });

    test('asks again once 24 hours have passed since a night ack', () {
      expect(
        review(lastAcknowledgedAt: DateTime(2026, 9, 20, 3)),
        HomeAsk.review,
      );
    });

    test('waits 24 hours after a feedback ask', () {
      expect(
        review(
          lastAcknowledgedAt: DateTime(2026, 9, 19, 14),
          feedbackAskedAt: DateTime(2026, 9, 21, 9),
        ),
        HomeAsk.none,
      );
    });

    test(
      'asks nothing before onboarding and the first Feature Guide are done',
      () {
        expect(
          HomeAskRules.decide(
            now: now,
            firstSeenAt: DateTime(2026, 9),
            consentAskedAt: null,
            isConsentGiven: false,
            reviewAskedAt: null,
            reviewAskCount: 0,
            lastAcknowledgedAt: null,
            proAskedAt: null,
            isRinging: false,
            isWeb: false,
            isSetupDone: false,
          ),
          HomeAsk.none,
        );
      },
    );

    test('next() settles reminder asks before it reads anything', () async {
      final notices = FakeInAppNoticeRepository()
        ..firstSeenAt = DateTime(2026, 9)
        ..consentAskedAt = DateTime(2026, 9, 2)
        ..lastAcknowledgedAt = DateTime(2026, 9, 15);
      var settled = false;
      final rules = HomeAskRules(
        noticeRepository: notices,
        privacyRepository: _NoPrivacy(),
        isWeb: false,
        now: () => now,
        settle: () async {
          settled = true;
          await notices.markReviewAsked(
            at: now.subtract(const Duration(hours: 1)),
          );
        },
      );
      expect(await rules.next(), HomeAsk.none);
      expect(settled, isTrue);
    });

    test('no review ask on a day the shared list was acked', () async {
      // Everything the review ask needs, with the repository's own stamp two
      // days old, so only the shared list can block it.
      final notices = FakeInAppNoticeRepository()
        ..firstSeenAt = DateTime(2026, 9)
        ..consentAskedAt = DateTime(2026, 9, 2)
        ..lastAcknowledgedAt = DateTime(2026, 9, 19, 14);
      HomeAskRules rules({DateTime? Function()? newestAckedAt}) => HomeAskRules(
        noticeRepository: notices,
        privacyRepository: _NoPrivacy(),
        isWeb: false,
        now: () => now,
        newestAckedAt: newestAckedAt,
      );

      expect(await rules().next(), HomeAsk.review);
      expect(
        await rules(newestAckedAt: () => DateTime(2026, 9, 21, 9)).next(),
        HomeAsk.none,
      );
    });
  });
}

class _NoPrivacy implements PrivacyRepository {
  @override
  Future<AppResult<PrivacySettings>> getPrivacySettings() async =>
      const Success(PrivacySettings());

  @override
  Future<AppResult<Unit>> setAnalyticsEnabled({required bool enabled}) async =>
      const Success(unit);

  @override
  Future<AppResult<Unit>> setCrashReportingEnabled({
    required bool enabled,
  }) async => const Success(unit);
}
