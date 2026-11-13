import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/features/account/domain/entities/identity_provider.dart';
import 'package:critalarm/features/account/domain/usecases/sign_in_restore.dart';
import 'package:critalarm/features/account/presentation/cubits/account_cubit.dart';
import 'package:critalarm/features/account/presentation/cubits/account_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_fakes.dart';

/// Rules 2, 3 and 4 through the account cubit: a phone back on its old
/// account after a reinstall, and another identity signing in on it.
void main() {
  late FakeIdentityRepository identities;
  late FakeHeldSession held;
  late FakeAccountIdentities rows;
  late int topics;
  late String? liveIncident;

  setUp(() {
    identities = FakeIdentityRepository();
    held = FakeHeldSession();
    rows = FakeAccountIdentities();
    topics = 3;
    liveIncident = null;
  });

  AccountCubit cubitFor(FakeAccountRepository account) => AccountCubit(
    identities: identities,
    account: account,
    restore: SignInRestore(
      identities: identities,
      account: account,
      accountIdentities: rows,
      held: held,
      readDeviceAccountId: () async => 'acc_1',
    ),
    held: held,
    readTopicCount: () async => topics,
    readLiveIncidentId: () async => liveIncident,
  );

  /// Every state the cubit emits, so a test can say what was never shown.
  List<AccountState> record(AccountCubit cubit) {
    final seen = <AccountState>[];
    cubit.stream.listen(seen.add);
    return seen;
  }

  group('rule 2: silent restore', () {
    test('token held, no saved identity, a current row: signed in with the '
        'email from that row, nothing shown', () async {
      held.token = 'sess_keychain';
      rows.rows = [identityRow(email: 'zed@gmail.com', current: true)];
      final account = FakeAccountRepository(linkAnswers: const []);
      final cubit = cubitFor(account);
      final seen = record(cubit);

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.status, AccountStatus.signedIn);
      expect(cubit.state.identity?.email, 'zed@gmail.com');
      expect(cubit.state.identity?.accountId, 'acc_1');
      expect(cubit.state.identity?.provider, IdentityProvider.google);
      expect(identities.saved?.email, 'zed@gmail.com');
      expect(seen, isNotEmpty);
      for (final state in seen) {
        expect(state.errorMessage, isNull);
        expect(state.status, isNot(AccountStatus.choosing));
        expect(state.choice, isNull);
        expect(state.leave, isNull);
        expect(state.unfinished, isNull);
      }
      // Read only: nothing was posted to the server.
      expect(account.calls, isEmpty);
    });

    test('token held, no current row: Finish signing in, no error, token '
        'still held, nothing posted', () async {
      held.token = 'sess_keychain';
      rows.rows = [identityRow()];
      final account = FakeAccountRepository(linkAnswers: const []);
      final cubit = cubitFor(account);
      final seen = record(cubit);

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.status, AccountStatus.unfinished);
      expect(cubit.state.unfinished, isNotNull);
      expect(cubit.state.errorMessage, isNull);
      expect(seen.every((s) => s.errorMessage == null), isTrue);
      expect(held.token, 'sess_keychain');
      expect(identities.clearCalls, 0);
      expect(seen.every((s) => s.leave == null), isTrue);
      expect(account.calls, isEmpty);
    });

    test('token held, the read fails: plain signed out, no error, token '
        'still held', () async {
      held.token = 'sess_keychain';
      rows.error = Exception('offline');
      final account = FakeAccountRepository(linkAnswers: const []);
      final cubit = cubitFor(account);

      await cubit.load();

      expect(cubit.state.status, AccountStatus.signedOut);
      expect(cubit.state.errorMessage, isNull);
      expect(held.token, 'sess_keychain');
      expect(account.calls, isEmpty);
    });
  });

  group('rule 3: Finish signing in', () {
    test('no token, one Google row: the hint and the topic count', () async {
      rows.rows = [identityRow()];
      final cubit = cubitFor(FakeAccountRepository(linkAnswers: const []));

      await cubit.load();

      expect(cubit.state.status, AccountStatus.unfinished);
      expect(cubit.state.identity, isNull);
      expect(
        cubit.state.unfinished,
        const UnfinishedSignIn(
          provider: IdentityProvider.google,
          offered: true,
          emailHint: 'z•••@gmail.com',
          others: 0,
          topics: 3,
        ),
      );
    });

    test('no token, one Apple row with the email hidden', () async {
      rows.rows = [identityRow(provider: 'apple', emailHidden: true)];
      final cubit = cubitFor(FakeAccountRepository(linkAnswers: const []));

      await cubit.load();

      final unfinished = cubit.state.unfinished!;
      expect(unfinished.provider, IdentityProvider.apple);
      expect(unfinished.emailHidden, isTrue);
      expect(unfinished.emailHint, isNull);
      expect(unfinished.topics, 3);
    });

    test('no token, list empty: plain signed out, as before', () async {
      final cubit = cubitFor(FakeAccountRepository(linkAnswers: const []));

      await cubit.load();

      expect(cubit.state.status, AccountStatus.signedOut);
      expect(cubit.state.unfinished, isNull);
      expect(cubit.state.identity, isNull);
      expect(cubit.state.errorMessage, isNull);
    });

    test('more than one row: the oldest, and a count of the others', () async {
      rows.rows = [
        identityRow(emailHint: 'o•••@gmail.com'),
        identityRow(id: 'idn_2', provider: 'apple', linkedAt: 1763000900),
        identityRow(id: 'idn_3', linkedAt: 1763000990),
      ];
      final cubit = cubitFor(FakeAccountRepository(linkAnswers: const []));

      await cubit.load();

      expect(cubit.state.unfinished?.emailHint, 'o•••@gmail.com');
      expect(cubit.state.unfinished?.others, 2);
    });

    test('a provider this phone cannot offer: the one way is another '
        'account', () async {
      identities.available = {IdentityProvider.google};
      rows.rows = [identityRow(provider: 'apple', emailHidden: true)];
      final cubit = cubitFor(FakeAccountRepository(linkAnswers: const []));

      await cubit.load();

      expect(cubit.state.unfinished?.offered, isFalse);
    });

    test('the ring line picks its words from RingClaim', () async {
      rows.rows = [identityRow()];
      final account = FakeAccountRepository(linkAnswers: const []);
      final cubit = AccountCubit(
        identities: identities,
        account: account,
        restore: SignInRestore(
          identities: identities,
          account: account,
          accountIdentities: rows,
          held: held,
          readDeviceAccountId: () async => 'acc_1',
        ),
        readRingClaim: () async => RingClaim.timeSensitive,
      );

      await cubit.load();

      expect(cubit.state.ringClaim, RingClaim.timeSensitive);
    });

    test('Finish signing in runs the ordinary sign-in and lands signed '
        'in', () async {
      rows.rows = [identityRow()];
      final account = FakeAccountRepository(
        linkAnswers: const [
          AccountLinkResult.alreadyLinked(accountId: 'acc_1'),
        ],
      );
      final cubit = cubitFor(account);
      await cubit.load();

      await cubit.signIn(cubit.state.unfinished!.provider!);

      expect(identities.signInCalls, 1);
      expect(cubit.state.status, AccountStatus.signedIn);
      expect(cubit.state.unfinished, isNull);
    });

    test('backing out of the sheet goes back to the same card', () async {
      rows.rows = [identityRow()];
      final cubit = cubitFor(FakeAccountRepository(linkAnswers: const []));
      await cubit.load();
      identities.cancelNextSignIn = true;

      await cubit.signIn(IdentityProvider.google);

      expect(cubit.state.status, AccountStatus.unfinished);
      expect(cubit.state.unfinished, isNotNull);
    });
  });

  group('rule 4: leave panel', () {
    FakeAccountRepository refusedThenClaimed() => FakeAccountRepository(
      linkAnswers: const [
        AccountLinkResult.accountHasAnotherIdentity(),
        AccountLinkResult.claimed(accountId: 'acc_fresh'),
      ],
    );

    test('409 account has another identity with 3 topics shows the panel, '
        'not the error dialog', () async {
      final account = refusedThenClaimed();
      final cubit = cubitFor(account);
      await cubit.load();

      await cubit.signIn(IdentityProvider.google);

      expect(cubit.state.status, AccountStatus.choosing);
      expect(cubit.state.leave, const LeaveOffer(topics: 3));
      expect(cubit.state.choice, isNull);
      expect(cubit.state.errorMessage, isNull);
    });

    test('Leave and sign in: signOutDevice once, then link, then signed '
        'in', () async {
      final account = refusedThenClaimed();
      final cubit = cubitFor(account);
      await cubit.load();
      await cubit.signIn(IdentityProvider.google);

      await cubit.leaveAndSignIn();

      expect(account.calls, ['link', 'signOut', 'link']);
      expect(account.signOutCalls, 1);
      // The same identity the person just signed in with, sent again.
      expect(account.linkTokens, ['session_1', 'session_1']);
      expect(account.linkIntents.last, AccountLinkIntent.signIn);
      expect(cubit.state.status, AccountStatus.signedIn);
      expect(cubit.state.identity?.accountId, 'acc_fresh');
      expect(cubit.state.leave, isNull);
      // Signing out dropped the stored session, so it was put back.
      expect(held.kept.single.token, 'session_1');
      expect(identities.signInCalls, 1);
    });

    test('Stay on this account changes nothing on the server', () async {
      final account = refusedThenClaimed();
      final cubit = cubitFor(account);
      await cubit.load();
      await cubit.signIn(IdentityProvider.google);

      cubit.stayOnThisAccount();

      expect(account.calls, ['link']);
      expect(account.signOutCalls, 0);
      expect(cubit.state.status, AccountStatus.signedOut);
      expect(cubit.state.leave, isNull);
      expect(cubit.state.errorMessage, isNull);
    });

    test('Stay from the Finish signing in card goes back to that '
        'card', () async {
      rows.rows = [identityRow()];
      final account = refusedThenClaimed();
      final cubit = cubitFor(account);
      await cubit.load();
      await cubit.signIn(IdentityProvider.google);

      cubit.stayOnThisAccount();

      expect(cubit.state.status, AccountStatus.unfinished);
      expect(cubit.state.unfinished, isNotNull);
    });

    test('refused while an alarm is active', () async {
      final account = refusedThenClaimed();
      final cubit = cubitFor(account);
      await cubit.load();
      await cubit.signIn(IdentityProvider.google);
      liveIncident = 'inc_7';

      await cubit.leaveAndSignIn();

      expect(account.signOutCalls, 0);
      expect(cubit.state.status, AccountStatus.choosing);
      expect(cubit.state.liveIncidentId, 'inc_7');
      expect(cubit.state.leave, isNotNull);
      expect(cubit.state.identity, isNull);

      // Acknowledged, then tried again with no restart.
      liveIncident = null;
      await cubit.leaveAndSignIn();

      expect(account.signOutCalls, 1);
      expect(cubit.state.status, AccountStatus.signedIn);
    });

    test('0 topics: no panel state, the phone leaves directly', () async {
      topics = 0;
      final account = refusedThenClaimed();
      final cubit = cubitFor(account);
      await cubit.load();
      final seen = record(cubit);

      await cubit.signIn(IdentityProvider.google);
      await Future<void>.delayed(Duration.zero);

      expect(seen.where((s) => s.leave != null), isEmpty);
      expect(seen.where((s) => s.status == AccountStatus.choosing), isEmpty);
      expect(account.calls, ['link', 'signOut', 'link']);
      expect(cubit.state.status, AccountStatus.signedIn);
    });

    test('left, then the second link fails: the ordinary failure and the '
        'signed-out card', () async {
      rows.rows = [identityRow()];
      final account = FakeAccountRepository(
        linkAnswers: const [
          AccountLinkResult.accountHasAnotherIdentity(),
          AccountLinkResult.unauthorized(),
        ],
      );
      final cubit = cubitFor(account);
      await cubit.load();
      await cubit.signIn(IdentityProvider.google);

      await cubit.leaveAndSignIn();

      expect(account.signOutCalls, 1);
      expect(cubit.state.status, AccountStatus.signedOut);
      expect(cubit.state.identity, isNull);
      // The phone is on a fresh anonymous account now, not the old one.
      expect(cubit.state.unfinished, isNull);
      expect(cubit.state.leave, isNull);
      expect(
        cubit.state.errorMessage,
        'Sign-in did not go through. Try again.',
      );
    });

    test('a sign-out that fails stays on the panel and says so', () async {
      final account = refusedThenClaimed()
        ..signOutError = Exception('delete refused');
      final cubit = cubitFor(account);
      await cubit.load();
      await cubit.signIn(IdentityProvider.google);

      await cubit.leaveAndSignIn();

      expect(cubit.state.status, AccountStatus.choosing);
      expect(cubit.state.leave, isNotNull);
      expect(cubit.state.errorMessage, isNotNull);
      expect(account.calls, ['link', 'signOut']);
    });

    test('Use a different account opens the panel, and leaving lands on the '
        'sign-in buttons', () async {
      rows.rows = [identityRow()];
      final account = FakeAccountRepository(linkAnswers: const []);
      final cubit = cubitFor(account);
      await cubit.load();

      await cubit.useDifferentAccount();

      expect(cubit.state.status, AccountStatus.choosing);
      expect(cubit.state.leave, const LeaveOffer(topics: 3));

      await cubit.leaveAndSignIn();

      expect(account.calls, ['signOut']);
      expect(cubit.state.status, AccountStatus.signedOut);
      expect(cubit.state.unfinished, isNull);
      expect(cubit.state.errorMessage, isNull);
    });
  });
}
