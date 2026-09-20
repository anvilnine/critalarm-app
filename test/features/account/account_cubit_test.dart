import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/features/account/domain/entities/identity_provider.dart';
import 'package:critalarm/features/account/presentation/cubits/account_cubit.dart';
import 'package:critalarm/features/account/presentation/cubits/account_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_fakes.dart';

void main() {
  late FakeIdentityRepository identities;

  setUp(() => identities = FakeIdentityRepository());

  AccountCubit cubitFor(FakeAccountRepository account) =>
      AccountCubit(identities: identities, account: account);

  test('200 claimed goes straight to signed in, with no prompt', () async {
    final account = FakeAccountRepository(
      linkAnswers: const [AccountLinkResult.claimed(accountId: 'acc_1')],
    );
    final cubit = cubitFor(account);

    await cubit.signIn(IdentityProvider.google);

    expect(cubit.state.status, AccountStatus.signedIn);
    expect(cubit.state.choice, isNull);
    expect(cubit.state.identity?.accountId, 'acc_1');
    expect(identities.saved?.accountId, 'acc_1');
  });

  test('200 attached goes straight to signed in, with no prompt', () async {
    final account = FakeAccountRepository(
      linkAnswers: const [AccountLinkResult.attached(accountId: 'acc_9')],
    );
    final cubit = cubitFor(account);

    await cubit.signIn(IdentityProvider.apple);

    expect(cubit.state.status, AccountStatus.signedIn);
    expect(cubit.state.choice, isNull);
    expect(cubit.state.identity?.accountId, 'acc_9');
  });

  test('409 choose raises the prompt and does not sign in yet', () async {
    final account = FakeAccountRepository(
      linkAnswers: const [
        AccountLinkResult.choose(
          intoAccount: 'acc_9',
          topics: 3,
          incidents: 12,
        ),
      ],
    );
    final cubit = cubitFor(account);

    await cubit.signIn(IdentityProvider.google);

    expect(cubit.state.status, AccountStatus.choosing);
    expect(cubit.state.identity, isNull);
    expect(cubit.state.choice?.topics, 3);
    expect(cubit.state.choice?.incidents, 12);
    expect(cubit.state.choice?.intoAccount, 'acc_9');
    expect(identities.saved, isNull);
  });

  test(
    'a merge blocked by a live alarm leaves the person signed out',
    () async {
      final account =
          FakeAccountRepository(
              linkAnswers: const [
                AccountLinkResult.choose(
                  intoAccount: 'acc_9',
                  topics: 3,
                  incidents: 12,
                ),
              ],
            )
            ..mergeAnswer = const AccountMergeResult.liveIncident(
              incidentId: 'inc_7',
            );
      final cubit = cubitFor(account);
      await cubit.signIn(IdentityProvider.google);

      await cubit.keepBoth();

      expect(cubit.state.status, isNot(AccountStatus.signedIn));
      expect(cubit.state.identity, isNull);
      expect(cubit.state.liveIncidentId, 'inc_7');
      expect(identities.saved, isNull);

      // Acknowledging the alarm and trying again works with no restart.
      account.mergeAnswer = const AccountMergeResult.merged(
        accountId: 'acc_9',
        mergedFrom: 'acc_1',
      );
      await cubit.keepBoth();

      expect(cubit.state.status, AccountStatus.signedIn);
      expect(account.mergeCalls, 2);
    },
  );

  test('401 runs the provider flow once more, then gives up', () async {
    final account = FakeAccountRepository(
      linkAnswers: const [
        AccountLinkResult.unauthorized(),
        AccountLinkResult.unauthorized(),
      ],
    );
    final cubit = cubitFor(account);

    await cubit.signIn(IdentityProvider.google);

    expect(identities.signInCalls, 2);
    expect(account.linkTokens, ['session_1', 'session_2']);
    expect(identities.clearCalls, 1);
    expect(cubit.state.status, AccountStatus.signedOut);
    expect(cubit.state.errorMessage, isNotNull);
  });

  test('401 then a good session signs in without asking twice more', () async {
    final account = FakeAccountRepository(
      linkAnswers: const [
        AccountLinkResult.unauthorized(),
        AccountLinkResult.claimed(accountId: 'acc_1'),
      ],
    );
    final cubit = cubitFor(account);

    await cubit.signIn(IdentityProvider.google);

    expect(identities.signInCalls, 2);
    expect(cubit.state.status, AccountStatus.signedIn);
  });

  test(
    'a handset another identity owns refuses and points at sign out',
    () async {
      final account = FakeAccountRepository(
        linkAnswers: const [AccountLinkResult.accountHasAnotherIdentity()],
      );
      final cubit = cubitFor(account);

      await cubit.signIn(IdentityProvider.google);

      expect(cubit.state.status, AccountStatus.signedOut);
      expect(cubit.state.errorMessage, contains('Sign out'));
    },
  );

  test('already merged lands on the account screen with no error', () async {
    final account = FakeAccountRepository(
      linkAnswers: const [
        AccountLinkResult.choose(
          intoAccount: 'acc_9',
          topics: 3,
          incidents: 12,
        ),
      ],
    )..mergeAnswer = const AccountMergeResult.alreadyMerged();
    final cubit = cubitFor(account);
    await cubit.signIn(IdentityProvider.google);

    await cubit.keepBoth();

    expect(cubit.state.status, AccountStatus.signedIn);
    expect(cubit.state.errorMessage, isNull);
    expect(cubit.state.identity?.accountId, 'acc_9');
  });

  test('start fresh switches and signs in', () async {
    final account = FakeAccountRepository(
      linkAnswers: const [
        AccountLinkResult.choose(
          intoAccount: 'acc_9',
          topics: 3,
          incidents: 12,
        ),
      ],
    );
    final cubit = cubitFor(account);
    await cubit.signIn(IdentityProvider.google);

    await cubit.startFresh();

    expect(account.switchCalls, 1);
    expect(cubit.state.status, AccountStatus.signedIn);
    expect(cubit.state.identity?.accountId, 'acc_9');
  });

  test('signing out lands on the signed-out screen', () async {
    final account = FakeAccountRepository(
      linkAnswers: const [AccountLinkResult.claimed(accountId: 'acc_1')],
    );
    final cubit = cubitFor(account);
    await cubit.load();
    await cubit.signIn(IdentityProvider.google);

    await cubit.signOut();

    expect(account.signOutCalls, 1);
    expect(cubit.state.status, AccountStatus.signedOut);
    expect(cubit.state.identity, isNull);
    expect(cubit.state.mode, ServerMode.hosted);
  });

  test('a failed sign out leaves the person signed in and says so', () async {
    final account = FakeAccountRepository(
      linkAnswers: const [AccountLinkResult.claimed(accountId: 'acc_1')],
    )..signOutError = Exception('delete refused');
    final cubit = cubitFor(account);
    await cubit.signIn(IdentityProvider.google);

    await cubit.signOut();

    expect(cubit.state.status, AccountStatus.signedIn);
    expect(cubit.state.identity?.accountId, 'acc_1');
    expect(cubit.state.errorMessage, isNotNull);
  });

  test('dismissing the error drops the message and nothing else', () async {
    final account = FakeAccountRepository(
      linkAnswers: const [AccountLinkResult.claimed(accountId: 'acc_1')],
    )..signOutError = Exception('delete refused');
    final cubit = cubitFor(account);
    await cubit.signIn(IdentityProvider.google);
    await cubit.signOut();

    cubit.dismissError();

    expect(cubit.state.errorMessage, isNull);
    expect(cubit.state.status, AccountStatus.signedIn);
    expect(cubit.state.identity?.accountId, 'acc_1');
  });
}
