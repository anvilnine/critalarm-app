import 'dart:async';

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

  String? deviceAccountId;

  SignInRestore restoreWith(FakeAccountRepository account) => SignInRestore(
    identities: identities,
    account: account,
    accountIdentities: rows,
    held: held,
    readDeviceAccountId: () async => deviceAccountId,
  );

  setUp(() => deviceAccountId = 'acc_1');

  test('rule 2: a current row saves the identity it names, on this '
      'phone account, with no prompt', () async {
    final account = FakeAccountRepository(linkAnswers: const []);

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

  test('rule 2: the restore only reads, it makes no POST', () async {
    final account = FakeAccountRepository(linkAnswers: const []);

    await restoreWith(account).run();
    // And again with nothing current, the path that falls through.
    rows.rows = [identityRow()];
    identities.saved = null;
    await restoreWith(account).run();

    expect(account.calls, isEmpty);
    expect(account.linkTokens, isEmpty);
  });

  test('rule 2: no current row restores nothing and keeps the token', () async {
    rows.rows = [identityRow()];
    final account = FakeAccountRepository(linkAnswers: const []);

    final outcome = await restoreWith(account).run();

    expect(outcome, isA<SignInRestoreUnfinished>());
    expect(identities.saved, isNull);
    expect(identities.clearCalls, 0);
    expect(held.token, 'sess_keychain');
    // The rows already read are used, not asked for twice.
    expect(rows.sentTokens, ['sess_keychain']);
  });

  test('rule 2: no account id on the phone restores nothing', () async {
    deviceAccountId = null;
    final account = FakeAccountRepository(linkAnswers: const []);

    final outcome = await restoreWith(account).run();

    expect(outcome, isA<SignInRestoreUnfinished>());
    expect(identities.saved, isNull);
  });

  test('rule 2: a failed read is plain signed out, token kept', () async {
    rows.error = Exception('offline');
    final account = FakeAccountRepository(linkAnswers: const []);

    final outcome = await restoreWith(account).run();

    expect(outcome, isA<SignInRestoreSignedOut>());
    expect(held.token, 'sess_keychain');
    expect(identities.clearCalls, 0);
    expect(account.calls, isEmpty);
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
    expect(rows.sentTokens, [null]);
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
      final account = FakeAccountRepository(linkAnswers: const []);
      rows.gate = Completer<void>();
      final restore = restoreWith(account);

      final first = restore.run();
      final second = restore.run();
      rows.gate!.complete();
      await Future.wait([first, second]);

      expect(rows.sentTokens, hasLength(1));
    },
  );
}
