import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/features/account/domain/entities/account_identity.dart';
import 'package:critalarm/features/account/domain/entities/identity_provider.dart';
import 'package:critalarm/features/account/presentation/cubits/account_cubit.dart';
import 'package:critalarm/features/account/presentation/cubits/account_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_fakes.dart';

/// A21: adding a second way to sign in, and minting a join code.
void main() {
  late FakeIdentityRepository identities;

  setUp(() => identities = FakeIdentityRepository());

  AccountCubit cubitFor(FakeAccountRepository account) =>
      AccountCubit(identities: identities, account: account);

  /// Signs in with Google first, because linking only exists on an account
  /// that already holds an identity.
  Future<AccountCubit> signedInWithGoogle(
    List<AccountLinkResult> afterSignIn,
  ) async {
    final account = FakeAccountRepository(
      linkAnswers: [
        const AccountLinkResult.claimed(accountId: 'acc_1'),
        ...afterSignIn,
      ],
    );
    final cubit = cubitFor(account);
    await cubit.signIn(IdentityProvider.google);
    return cubit;
  }

  group('which rows the account screen offers', () {
    test('an account with one provider can add the other', () async {
      final cubit = await signedInWithGoogle(const []);

      expect(cubit.addableProviders, [IdentityProvider.apple]);
    });

    test('Android never offers Apple, adding or signing in', () async {
      identities.available = {IdentityProvider.google};
      final cubit = await signedInWithGoogle(const []);

      expect(cubit.addableProviders, isEmpty);
      expect(cubit.supports(IdentityProvider.apple), isFalse);
    });

    test('an account holding both offers nothing to add', () async {
      final cubit = await signedInWithGoogle(const [
        AccountLinkResult.linked(accountId: 'acc_1'),
      ]);

      await cubit.addProvider(IdentityProvider.apple);

      expect(cubit.addableProviders, isEmpty);
    });

    test('nobody signed in has nothing to add to', () {
      final cubit = cubitFor(FakeAccountRepository(linkAnswers: const []));

      expect(cubit.addableProviders, isEmpty);
    });
  });

  group('adding another way to sign in', () {
    test('a linked provider joins the account and both show', () async {
      final cubit = await signedInWithGoogle(const [
        AccountLinkResult.linked(accountId: 'acc_1'),
      ]);

      await cubit.addProvider(IdentityProvider.apple);

      expect(cubit.state.status, AccountStatus.signedIn);
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.identity?.accountId, 'acc_1');
      expect(cubit.state.identity?.providers, {
        IdentityProvider.google,
        IdentityProvider.apple,
      });
      expect(identities.saved?.providers, {
        IdentityProvider.google,
        IdentityProvider.apple,
      });
    });

    test('the add call says intent link, the sign-in call does not', () async {
      final account = FakeAccountRepository(
        linkAnswers: const [
          AccountLinkResult.claimed(accountId: 'acc_1'),
          AccountLinkResult.linked(accountId: 'acc_1'),
        ],
      );
      final cubit = cubitFor(account);
      await cubit.signIn(IdentityProvider.google);

      await cubit.addProvider(IdentityProvider.apple);

      expect(account.linkIntents, [
        AccountLinkIntent.signIn,
        AccountLinkIntent.link,
      ]);
    });

    test('already_linked looks like success, with no error', () async {
      final cubit = await signedInWithGoogle(const [
        AccountLinkResult.alreadyLinked(accountId: 'acc_1'),
      ]);

      await cubit.addProvider(IdentityProvider.apple);

      expect(cubit.state.status, AccountStatus.signedIn);
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.identity?.providers, {
        IdentityProvider.google,
        IdentityProvider.apple,
      });
    });

    test('409 identity has another account says what happened', () async {
      final cubit = await signedInWithGoogle(const [
        AccountLinkResult.identityHasAnotherAccount(),
      ]);

      await cubit.addProvider(IdentityProvider.apple);

      expect(cubit.state.status, AccountStatus.signedIn);
      expect(cubit.state.errorMessage, contains('another account'));
      // Nothing was added, so the row is still there to try again.
      expect(cubit.state.identity?.providers, {IdentityProvider.google});
    });

    test('backing out of the sheet says nothing and adds nothing', () async {
      final cubit = await signedInWithGoogle(const []);
      identities.cancelNextSignIn = true;

      await cubit.addProvider(IdentityProvider.apple);

      expect(cubit.state.status, AccountStatus.signedIn);
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.linkingProvider, isNull);
      expect(cubit.state.identity?.providers, {IdentityProvider.google});
    });

    test('a dead session runs the sheet once more, then gives up', () async {
      final cubit = await signedInWithGoogle(const [
        AccountLinkResult.unauthorized(),
        AccountLinkResult.unauthorized(),
      ]);

      await cubit.addProvider(IdentityProvider.apple);

      // One sign-in for Google, then two for the add: the first try and the
      // single retry.
      expect(identities.signInCalls, 3);
      expect(cubit.state.status, AccountStatus.signedIn);
      expect(cubit.state.errorMessage, isNotNull);
    });
  });

  group('the sign-in screen after 1.14.0', () {
    test('already_linked signs the person in, the same as claimed', () async {
      // S30 made a plain sign-in with no intent answer `already_linked`
      // whenever the identity already points at this phone's own account.
      // Before 1.14.0 the same request answered `claimed`.
      final account = FakeAccountRepository(
        linkAnswers: const [
          AccountLinkResult.alreadyLinked(accountId: 'acc_1'),
        ],
      );
      final cubit = cubitFor(account);

      await cubit.signIn(IdentityProvider.google);

      expect(account.linkIntents, [AccountLinkIntent.signIn]);
      expect(cubit.state.status, AccountStatus.signedIn);
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.identity?.accountId, 'acc_1');
      expect(identities.saved?.accountId, 'acc_1');
    });

    test('linked on a sign-in also signs the person in', () async {
      final account = FakeAccountRepository(
        linkAnswers: const [AccountLinkResult.linked(accountId: 'acc_1')],
      );
      final cubit = cubitFor(account);

      await cubit.signIn(IdentityProvider.apple);

      expect(cubit.state.status, AccountStatus.signedIn);
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.identity?.accountId, 'acc_1');
    });

    test('identity has another account is worded, not generic', () async {
      final account = FakeAccountRepository(
        linkAnswers: const [
          AccountLinkResult.identityHasAnotherAccount(),
        ],
      );
      final cubit = cubitFor(account);

      await cubit.signIn(IdentityProvider.google);

      expect(cubit.state.status, AccountStatus.signedOut);
      expect(cubit.state.errorMessage, contains('another account'));
    });
  });

  group('the join code', () {
    test('a minted code is held for the screen to show once', () async {
      final account = FakeAccountRepository(linkAnswers: const [])
        ..joinTokenAnswers = const [
          AccountJoinTokenResult.minted(joinToken: 'aj_abc'),
        ];
      final cubit = cubitFor(account);

      await cubit.mintJoinToken();

      expect(cubit.state.joinToken, 'aj_abc');
      expect(cubit.state.joinTokenMints, 1);
      expect(cubit.state.isMintingJoinToken, isFalse);
      expect(cubit.state.joinTokenError, isNull);
      // Nothing has been retired yet, so the screen says nothing about it.
      expect(cubit.state.hasRetiredAJoinToken, isFalse);
    });

    test('minting twice flags that the first code stopped working', () async {
      final account = FakeAccountRepository(linkAnswers: const [])
        ..joinTokenAnswers = const [
          AccountJoinTokenResult.minted(joinToken: 'aj_first'),
          AccountJoinTokenResult.minted(joinToken: 'aj_second'),
        ];
      final cubit = cubitFor(account);

      await cubit.mintJoinToken();
      await cubit.mintJoinToken();

      expect(cubit.state.joinToken, 'aj_second');
      expect(cubit.state.joinTokenMints, 2);
      expect(cubit.state.hasRetiredAJoinToken, isTrue);
    });

    test('taking the code off the screen leaves the count alone', () async {
      final account = FakeAccountRepository(linkAnswers: const []);
      final cubit = cubitFor(account);
      await cubit.mintJoinToken();

      cubit.dismissJoinToken();

      expect(cubit.state.joinToken, isNull);
      expect(cubit.state.joinTokenMints, 1);
    });

    test('a 401 says so and shows no code', () async {
      final account = FakeAccountRepository(linkAnswers: const [])
        ..joinTokenAnswers = const [AccountJoinTokenResult.unauthorized()];
      final cubit = cubitFor(account);

      await cubit.mintJoinToken();

      expect(cubit.state.joinToken, isNull);
      expect(cubit.state.joinTokenMints, 0);
      expect(cubit.state.joinTokenError, isNotNull);
    });

    test('being offline says so and shows no code', () async {
      final account = FakeAccountRepository(linkAnswers: const [])
        ..joinTokenError = Exception('offline');
      final cubit = cubitFor(account);

      await cubit.mintJoinToken();

      expect(cubit.state.joinToken, isNull);
      expect(cubit.state.joinTokenError, isNotNull);
      expect(cubit.state.isMintingJoinToken, isFalse);
    });
  });

  group('what an account remembers about its providers', () {
    test('an identity saved before linking reads as one provider', () {
      const identity = AccountIdentity(
        provider: IdentityProvider.google,
        accountId: 'acc_1',
      );

      expect(identity.providers, {IdentityProvider.google});
      expect(identity.holds(IdentityProvider.google), isTrue);
      expect(identity.holds(IdentityProvider.apple), isFalse);
    });
  });
}
