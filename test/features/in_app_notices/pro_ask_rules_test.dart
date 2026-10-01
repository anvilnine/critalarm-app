import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/in_app_notices/data/repositories/shared_prefs_in_app_notice_repository.dart';
import 'package:critalarm/features/in_app_notices/domain/pro_ask_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_in_app_notice_repository.dart';

class FakeAccountRepository implements AccountRepository {
  bool isPaid = false;
  bool isPaidThrows = false;
  ServerMode? serverMode = ServerMode.hosted;

  @override
  Future<bool> readIsPaid() async {
    if (isPaidThrows) throw StateError('keychain');
    return isPaid;
  }

  @override
  Future<ServerMode?> readServerMode() async => serverMode;

  @override
  Future<AccountLinkResult> link(
    String identityToken, {
    AccountLinkIntent intent = AccountLinkIntent.signIn,
  }) async => const AccountLinkResult.claimed(accountId: 'acc1');

  @override
  Future<AccountJoinTokenResult> mintJoinToken() async =>
      const AccountJoinTokenResult.minted(joinToken: 'aj_1');

  @override
  Future<AccountMergeResult> merge({
    required String identityToken,
    required String intoAccount,
  }) async => const AccountMergeResult.merged(
    accountId: 'acc1',
    mergedFrom: 'acc2',
  );

  @override
  Future<AccountSwitchResult> switchTo({
    required String identityToken,
    required String intoAccount,
  }) async => const AccountSwitchResult.switched(accountId: 'acc1');

  @override
  Future<void> signOutDevice() async {}

  @override
  Future<AccountDeleteResult> deleteAccount({String? identityToken}) async =>
      const AccountDeleteResult.deleted();

  @override
  Future<void> wipeAfterDelete() async {}

  @override
  Future<void> recoverFromDeadCredential() async {}
}

void main() {
  // A fixed "today" so nothing in these tests waits on a real clock.
  final today = DateTime(2026, 9, 20, 9);

  group('ProAskRules.decide', () {
    test('asks a free hosted user who has never been asked', () {
      expect(
        ProAskRules.decide(
          isPaid: false,
          isSelfHosted: false,
          dismissCount: 0,
          lastAskedAt: null,
          now: today,
          isSetupDone: true,
        ),
        isTrue,
      );
    });

    test('being asked once buys 30 days of quiet', () {
      bool askAfter(Duration since) => ProAskRules.decide(
        isPaid: false,
        isSelfHosted: false,
        dismissCount: 0,
        lastAskedAt: today.subtract(since),
        now: today,
        isSetupDone: true,
      );

      expect(askAfter(const Duration(days: 1)), isFalse);
      expect(askAfter(const Duration(days: 29, hours: 23)), isFalse);
      expect(askAfter(const Duration(days: 30)), isTrue);
      expect(askAfter(const Duration(days: 45)), isTrue);
    });

    test('a second "Not now" means never again', () {
      expect(
        ProAskRules.decide(
          isPaid: false,
          isSelfHosted: false,
          dismissCount: 2,
          lastAskedAt: today.subtract(const Duration(days: 365)),
          now: today,
          isSetupDone: true,
        ),
        isFalse,
      );
    });

    test('somebody who already pays is never asked', () {
      expect(
        ProAskRules.decide(
          isPaid: true,
          isSelfHosted: false,
          dismissCount: 0,
          lastAskedAt: null,
          now: today,
          isSetupDone: true,
        ),
        isFalse,
      );
    });

    test('a self hosted server is never asked', () {
      expect(
        ProAskRules.decide(
          isPaid: false,
          isSelfHosted: true,
          dismissCount: 0,
          lastAskedAt: null,
          now: today,
          isSetupDone: true,
        ),
        isFalse,
      );
    });

    test(
      'never asks before onboarding and the first Feature Guide are done',
      () {
        expect(
          ProAskRules.decide(
            isPaid: false,
            isSelfHosted: false,
            dismissCount: 0,
            lastAskedAt: null,
            now: today,
            isSetupDone: false,
          ),
          isFalse,
        );
      },
    );
  });

  group('ProAskRules.shouldAsk', () {
    late FakeInAppNoticeRepository promptRepo;
    late FakeAccountRepository accountRepo;
    late DateTime clock;

    ProAskRules buildRules() => ProAskRules(
      noticeRepository: promptRepo,
      accountRepository: accountRepo,
      now: () => clock,
    );

    setUp(() {
      promptRepo = FakeInAppNoticeRepository()..now = () => clock;
      accountRepo = FakeAccountRepository();
      clock = today;
    });

    test('asks a free hosted user who has dismissed nothing', () async {
      expect(await buildRules().shouldAsk(), isTrue);
    });

    test('walking away from the sheet still buys quiet', () async {
      // Nobody tapped "Not now". The sheet was shown and swiped away, or
      // "See Pro plans" was tapped and the paywall backed out of. Showing it
      // is the ask, so it must not come straight back.
      await promptRepo.markProAsked();

      final rules = buildRules();
      clock = today.add(const Duration(days: 2));
      expect(await rules.shouldAsk(), isFalse);

      clock = today.add(const Duration(days: 31));
      expect(await rules.shouldAsk(), isTrue);
    });

    test(
      'goes quiet for 30 days after one "Not now", then asks again',
      () async {
        await promptRepo.dismissProAsk();

        final rules = buildRules();
        clock = today.add(const Duration(days: 29));
        expect(await rules.shouldAsk(), isFalse);

        clock = today.add(const Duration(days: 31));
        expect(await rules.shouldAsk(), isTrue);
      },
    );

    test('stays quiet for good after a second "Not now"', () async {
      await promptRepo.dismissProAsk();
      await promptRepo.dismissProAsk();

      final rules = buildRules();
      clock = today.add(const Duration(days: 400));
      expect(await rules.shouldAsk(), isFalse);
    });

    test('never asks a paid user', () async {
      accountRepo.isPaid = true;
      expect(await buildRules().shouldAsk(), isFalse);
    });

    test('a failed paid read counts as paid, so no ask', () async {
      accountRepo.isPaidThrows = true;
      expect(await buildRules().shouldAsk(), isFalse);
    });

    test('never asks in self hosted mode', () async {
      accountRepo.serverMode = ServerMode.selfhosted;
      expect(await buildRules().shouldAsk(), isFalse);
    });

    test(
      'waits 24 hours after the consent sheet or the review popup',
      () async {
        promptRepo.consentAskedAt = today.subtract(const Duration(hours: 23));
        expect(await buildRules().shouldAsk(), isFalse);

        promptRepo
          ..consentAskedAt = null
          ..reviewAskedAt = today.subtract(const Duration(hours: 2));
        expect(await buildRules().shouldAsk(), isFalse);

        promptRepo.reviewAskedAt = today.subtract(const Duration(hours: 24));
        expect(await buildRules().shouldAsk(), isTrue);
      },
    );

    test(
      'dismissProAsk records the time and adds one to the count',
      () async {
        await promptRepo.dismissProAsk();
        expect(promptRepo.getProAskDismissCount(), 1);
        expect(promptRepo.getProAskDismissedAt(), isNotNull);
        expect(promptRepo.getProAskedAt(), isNotNull);
      },
    );
  });

  group('reminders', () {
    late FakeInAppNoticeRepository promptRepo;
    late FakeAccountRepository accountRepo;

    setUp(() {
      promptRepo = FakeInAppNoticeRepository()..now = () => today;
      accountRepo = FakeAccountRepository();
    });

    ProAskRules rules({bool offersOn = false}) => ProAskRules(
      noticeRepository: promptRepo,
      accountRepository: accountRepo,
      now: () => today,
      offersOn: () => offersOn,
    );

    test('waits 24 hours after a feedback ask', () async {
      promptRepo.feedbackAskedAt = today.subtract(const Duration(hours: 2));
      expect(await rules().shouldAsk(), isFalse);
    });

    test('"Remind me later" does not count, "Not now" does', () async {
      // Runs against the real repository, not the fake: this proves what
      // SharedPreferences actually stores, not what the fake mimics.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPrefsInAppNoticeRepository(prefs);

      await repo.remindProAskLater();
      await repo.remindProAskLater();
      expect(repo.getProAskDismissCount(), 0);
      await repo.dismissProAsk();
      expect(repo.getProAskDismissCount(), 1);
    });

    test(
      'with Offers on, "Remind me later" hands the ask to a notification',
      () async {
        promptRepo
          ..proLaterAt = today.subtract(const Duration(days: 40))
          ..proAskedAt = today.subtract(const Duration(days: 40));
        expect(await rules(offersOn: true).shouldAsk(), isFalse);
        expect(await rules().shouldAsk(), isTrue);
      },
    );
  });
}
