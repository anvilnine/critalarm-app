import 'dart:async';

import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/features/account/domain/entities/account_identity.dart';
import 'package:critalarm/features/account/domain/entities/identity_provider.dart';
import 'package:critalarm/features/account/domain/usecases/sign_in_restore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_fakes.dart';

/// Rule 2: the silent restore, on its own.
void main() {
  late FakeIdentityRepository identities;
  late FakeHeldSession held;
  late FakeAccountIdentities rows;

  setUp(() {
    identities = FakeIdentityRepository();
    held = FakeHeldSession('sess_keychain');
    rows = FakeAccountIdentities([
      identityRow(email: 'zed@gmail.com', current: true),
      identityRow(
        id: 'idn_2',
        provider: 'apple',
        emailHidden: true,
        linkedAt: 1763000500,
      ),
    ]);
  });

  SignInRestore restoreWith(FakeAccountRepository account) => SignInRestore(
    identities: identities,
    account: account,
    accountIdentities: rows,
    held: held,
  );

  test('rule 2: already_linked saves the identity the current row names, '
      'with no prompt', () async {
    final account = FakeAccountRepository(
      linkAnswers: const [AccountLinkResult.alreadyLinked(accountId: 'acc_1')],
    );

    final outcome = await restoreWith(account).run();

    expect(outcome, isA<SignInRestoreSignedIn>());
    final saved = identities.saved!;
    expect(saved.provider, IdentityProvider.google);
    expect(saved.email, 'zed@gmail.com');
    expect(saved.accountId, 'acc_1');
    expect(saved.providers, {IdentityProvider.google, IdentityProvider.apple});
    // The list was read with the session, so the rows came back unmasked.
    expect(rows.sentTokens, ['sess_keychain']);
  });

  test('rule 2: restore sends intent sign_in and nothing else', () async {
    final account = FakeAccountRepository(
      linkAnswers: const [AccountLinkResult.alreadyLinked(accountId: 'acc_1')],
    );

    await restoreWith(account).run();

    expect(account.linkTokens, ['sess_keychain']);
    expect(account.linkIntents, [AccountLinkIntent.signIn]);
    expect(account.calls, ['link']);
  });

  for (final answer in const [
    AccountLinkResult.accountHasAnotherIdentity(),
    AccountLinkResult.unauthorized(),
    AccountLinkResult.choose(intoAccount: 'acc_9', topics: 3, incidents: 1),
  ]) {
    test('rule 2: $answer falls to the identities list, token kept', () async {
      final account = FakeAccountRepository(linkAnswers: [answer]);

      final outcome = await restoreWith(account).run();

      expect(outcome, isA<SignInRestoreUnfinished>());
      expect(identities.saved, isNull);
      expect(identities.clearCalls, 0);
      expect(held.token, 'sess_keychain');
      expect(account.calls, ['link']);
    });
  }

  test('rule 2: no network falls to the list, token kept', () async {
    final account = FakeAccountRepository(linkAnswers: const [])
      ..linkError = Exception('offline');

    final outcome = await restoreWith(account).run();

    expect(outcome, isA<SignInRestoreUnfinished>());
    expect(held.token, 'sess_keychain');
    expect(identities.clearCalls, 0);
  });

  test('rule 2: already_linked with no current row restores nothing', () async {
    rows.rows = [identityRow()];
    final account = FakeAccountRepository(
      linkAnswers: const [AccountLinkResult.alreadyLinked(accountId: 'acc_1')],
    );

    final outcome = await restoreWith(account).run();

    expect(outcome, isA<SignInRestoreUnfinished>());
    expect(identities.saved, isNull);
    // The rows already read are used, not asked for twice.
    expect(rows.sentTokens, ['sess_keychain']);
  });

  test('rule 2: a saved identity is answered with no server call', () async {
    identities.saved = const AccountIdentity(
      provider: IdentityProvider.apple,
      accountId: 'acc_1',
    );
    final account = FakeAccountRepository(linkAnswers: const []);

    final outcome = await restoreWith(account).run();

    expect(outcome, isA<SignInRestoreSignedIn>());
    expect(account.calls, isEmpty);
    expect(rows.sentTokens, isEmpty);
  });

  test('rule 2: no server yet, or a server of the person own, asks '
      'nothing', () async {
    for (final mode in [null, ServerMode.selfhosted]) {
      final account = FakeAccountRepository(linkAnswers: const [])..mode = mode;

      final outcome = await restoreWith(account).run();

      expect(outcome, isA<SignInRestoreSignedOut>());
      expect(account.calls, isEmpty);
      expect(rows.sentTokens, isEmpty);
    }
  });

  test('rule 2: skipped for a moved phone, no session is sent', () async {
    final account = FakeAccountRepository(linkAnswers: const []);
    final restore = restoreWith(account)..skipLink();

    final outcome = await restore.run();

    expect(account.calls, isEmpty);
    // Which account it is on can still be said, masked.
    expect(outcome, isA<SignInRestoreUnfinished>());
  });

  test('rule 2: no token held reads the list with no session', () async {
    held.token = null;
    final account = FakeAccountRepository(linkAnswers: const []);

    final outcome = await restoreWith(account).run();

    expect(account.calls, isEmpty);
    expect(rows.sentTokens, [null]);
    expect(outcome, isA<SignInRestoreUnfinished>());
  });

  test('rule 3: an empty list is plain signed out', () async {
    held.token = null;
    rows.rows = const [];
    final account = FakeAccountRepository(linkAnswers: const []);

    expect(await restoreWith(account).run(), isA<SignInRestoreSignedOut>());
  });

  test(
    'rule 2: the launch and a screen asking at once share one run',
    () async {
      final account = FakeAccountRepository(
        linkAnswers: const [
          AccountLinkResult.alreadyLinked(accountId: 'acc_1'),
        ],
      )..linkGate = Completer<void>();
      final restore = restoreWith(account);

      final first = restore.run();
      final second = restore.run();
      account.linkGate!.complete();
      await Future.wait([first, second]);

      expect(account.linkTokens, hasLength(1));
    },
  );
}
