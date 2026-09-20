import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/prompts/domain/pro_prompt_rules.dart';
import 'package:critalarm/features/prompts/domain/repositories/home_prompt_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeHomePromptRepository implements HomePromptRepository {
  DateTime? proAskedAt;
  DateTime? proDismissedAt;
  int proDismissCount = 0;

  @override
  DateTime? getProPromptAskedAt() => proAskedAt;

  @override
  Future<void> markProPromptAsked() async {
    proAskedAt = DateTime.now();
  }

  @override
  DateTime? getProPromptDismissedAt() => proDismissedAt;

  @override
  int getProPromptDismissCount() => proDismissCount;

  @override
  Future<void> dismissProPrompt() async {
    proDismissCount++;
    proDismissedAt = DateTime.now();
    proAskedAt = proDismissedAt;
  }

  @override
  DateTime? getAccountPromptDismissedAt() => null;

  @override
  Future<void> dismissAccountPrompt() async {}

  @override
  DateTime? getLastBannerResolvedOrDismissedAt() => null;

  @override
  Future<void> markBannerResolvedOrDismissed() async {}
}

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
      promptRepo = FakeHomePromptRepository();
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

    test('dismissProPrompt records the time and adds one to the count',
        () async {
      await promptRepo.dismissProPrompt();
      expect(promptRepo.getProPromptDismissCount(), 1);
      expect(promptRepo.getProPromptDismissedAt(), isNotNull);
      expect(promptRepo.getProPromptAskedAt(), isNotNull);
    });
  });
}
