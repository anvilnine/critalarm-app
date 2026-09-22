import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/prompts/data/repositories/shared_prefs_home_prompt_repository.dart';
import 'package:critalarm/features/prompts/domain/pro_prompt_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_home_prompt_repository.dart';

class FakeAccountRepository implements AccountRepository {
  bool isPaid = false;
  ServerMode? serverMode = ServerMode.hosted;

  @override
  Future<bool> readIsPaid() async => isPaid;

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

  group('ProPromptRules.decide', () {
    test('asks a free hosted user who has never been asked', () {
      expect(
        ProPromptRules.decide(
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
      bool askAfter(Duration since) => ProPromptRules.decide(
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
        ProPromptRules.decide(
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
        ProPromptRules.decide(
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
        ProPromptRules.decide(
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

    test('never asks before onboarding and the tour are done', () {
      expect(
        ProPromptRules.decide(
          isPaid: false,
          isSelfHosted: false,
          dismissCount: 0,
          lastAskedAt: null,
          now: today,
          isSetupDone: false,
        ),
        isFalse,
      );
    });
  });

  group('ProPromptRules.shouldAsk', () {
    late FakeHomePromptRepository promptRepo;
    late FakeAccountRepository accountRepo;
    late DateTime clock;

    ProPromptRules buildRules() => ProPromptRules(
      homePromptRepository: promptRepo,
      accountRepository: accountRepo,
      now: () => clock,
    );

    setUp(() {
      promptRepo = FakeHomePromptRepository()..now = () => clock;
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
      await promptRepo.markProPromptAsked();

      final rules = buildRules();
      clock = today.add(const Duration(days: 2));
      expect(await rules.shouldAsk(), isFalse);

      clock = today.add(const Duration(days: 31));
      expect(await rules.shouldAsk(), isTrue);
    });

    test('goes quiet for 30 days after one "Not now", then asks again',
        () async {
      await promptRepo.dismissProPrompt();

      final rules = buildRules();
      clock = today.add(const Duration(days: 29));
      expect(await rules.shouldAsk(), isFalse);

      clock = today.add(const Duration(days: 31));
      expect(await rules.shouldAsk(), isTrue);
    });

    test('stays quiet for good after a second "Not now"', () async {
      await promptRepo.dismissProPrompt();
      await promptRepo.dismissProPrompt();

      final rules = buildRules();
      clock = today.add(const Duration(days: 400));
      expect(await rules.shouldAsk(), isFalse);
    });

    test('never asks a paid user', () async {
      accountRepo.isPaid = true;
      expect(await buildRules().shouldAsk(), isFalse);
    });

    test('never asks in self hosted mode', () async {
      accountRepo.serverMode = ServerMode.selfhosted;
      expect(await buildRules().shouldAsk(), isFalse);
    });

    test('waits 24 hours after the consent sheet or the review popup',
        () async {
      promptRepo.consentAskedAt = today.subtract(const Duration(hours: 23));
      expect(await buildRules().shouldAsk(), isFalse);

      promptRepo
        ..consentAskedAt = null
        ..reviewAskedAt = today.subtract(const Duration(hours: 2));
      expect(await buildRules().shouldAsk(), isFalse);

      promptRepo.reviewAskedAt = today.subtract(const Duration(hours: 24));
      expect(await buildRules().shouldAsk(), isTrue);
    });

    test('dismissProPrompt records the time and adds one to the count',
        () async {
      await promptRepo.dismissProPrompt();
      expect(promptRepo.getProPromptDismissCount(), 1);
      expect(promptRepo.getProPromptDismissedAt(), isNotNull);
      expect(promptRepo.getProPromptAskedAt(), isNotNull);
    });
  });

  group('reminders', () {
    late FakeHomePromptRepository promptRepo;
    late FakeAccountRepository accountRepo;

    setUp(() {
      promptRepo = FakeHomePromptRepository()..now = () => today;
      accountRepo = FakeAccountRepository();
    });

    ProPromptRules rules({bool offersOn = false}) => ProPromptRules(
      homePromptRepository: promptRepo,
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
      final repo = SharedPrefsHomePromptRepository(prefs);

      await repo.remindProPromptLater();
      await repo.remindProPromptLater();
      expect(repo.getProPromptDismissCount(), 0);
      await repo.dismissProPrompt();
      expect(repo.getProPromptDismissCount(), 1);
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
