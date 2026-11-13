import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/features/account/domain/entities/account_identity.dart';
import 'package:critalarm/features/account/domain/entities/identity_provider.dart';
import 'package:critalarm/features/account/presentation/cubits/sign_in_methods_cubit.dart';
import 'package:critalarm/features/account/presentation/cubits/sign_in_methods_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_translations.dart';
import 'account_fakes.dart';

/// The "Ways to sign in" page: list, add and remove.
void main() {
  setUpAll(loadTestTranslations);

  late FakeIdentityRepository identities;
  late FakeHeldSession held;
  late FakeAccountIdentities rows;

  const signedIn = AccountIdentity(
    provider: IdentityProvider.google,
    accountId: 'acc_1',
    email: 'zed@gmail.com',
  );

  setUp(() {
    identities = FakeIdentityRepository()..saved = signedIn;
    held = FakeHeldSession('sess_held')
      ..provider = IdentityProvider.google
      ..email = 'zed@gmail.com';
    identities.onSignedIn = held.overwrite;
    rows = FakeAccountIdentities([
      identityRow(email: 'zed@gmail.com', current: true),
    ]);
  });

  SignInMethodsCubit cubitFor(FakeAccountRepository account) =>
      SignInMethodsCubit(
        identities: identities,
        account: account,
        accountIdentities: rows,
        held: held,
      );

  AccountIdentityRow row(
    String id, {
    String provider = 'google',
    String? email,
    bool hidden = false,
    int linkedAt = 1763000000,
    bool current = false,
  }) => identityRow(
    id: id,
    provider: provider,
    email: email,
    emailHint: null,
    emailHidden: hidden,
    linkedAt: linkedAt,
    current: current,
  );

  group('rule 3: one row per sign-in', () {
    test(
      'rows come from the server list, oldest first, with the This phone '
      'marker on the current one, read with the held session',
      () async {
        rows.rows = [
          row('idn_1', email: 'zed@gmail.com', current: true),
          row('idn_2', provider: 'apple', hidden: true, linkedAt: 1763000500),
        ];
        final cubit = cubitFor(FakeAccountRepository(linkAnswers: const []));

        await cubit.load();

        expect(cubit.state.status, SignInMethodsStatus.ready);
        expect(rows.sentTokens, ['sess_held']);
        final list = cubit.state.rows;
        expect(list.map((r) => r.id), ['idn_1', 'idn_2']);
        expect(list.first.current, isTrue);
        expect(list.first.email, 'zed@gmail.com');
        expect(list.last.provider, IdentityProvider.apple);
        expect(list.last.emailHidden, isTrue);
        expect(list.any((r) => r.showsDate), isFalse);
      },
    );

    test('two rows that would read the same get the date', () async {
      rows.rows = [
        row('idn_1', provider: 'apple', hidden: true, current: true),
        row('idn_2', provider: 'apple', hidden: true, linkedAt: 1763090000),
        row('idn_3', email: 'zed@gmail.com', linkedAt: 1763099999),
      ];
      final cubit = cubitFor(FakeAccountRepository(linkAnswers: const []));

      await cubit.load();

      expect(cubit.state.rows.map((r) => r.showsDate), [true, true, false]);
    });

    test(
      'one row gives no remove action, six rows give no add action',
      () async {
        final cubit = cubitFor(FakeAccountRepository(linkAnswers: const []));
        await cubit.load();
        expect(cubit.state.canRemove, isFalse);
        expect(cubit.state.addable, isNotEmpty);

        rows.rows = [
          for (var i = 0; i < 6; i++)
            row(
              'idn_$i',
              email: 'p$i@example.com',
              linkedAt: 1763000000 + i,
              current: i == 0,
            ),
        ];
        await cubit.load();
        expect(cubit.state.canRemove, isTrue);
        expect(cubit.state.addable, isEmpty);
      },
    );

    test('a session that is not current on the account reads as signed '
        'out, and the page has nothing to show', () async {
      rows.rows = [row('idn_1', email: 'zed@gmail.com')];
      final cubit = cubitFor(FakeAccountRepository(linkAnswers: const []));

      await cubit.load();

      expect(cubit.state.status, SignInMethodsStatus.signedOut);
    });
  });

  group('rule 4: the adds', () {
    test(
      'Apple and Google, always, even for a provider the account holds',
      () async {
        final cubit = cubitFor(FakeAccountRepository(linkAnswers: const []));
        await cubit.load();

        expect(cubit.state.addable, [
          IdentityProvider.apple,
          IdentityProvider.google,
        ]);
      },
    );

    test('Android offers no Add Apple and still lists and removes an Apple '
        'row', () async {
      identities.available = {IdentityProvider.google};
      rows
        ..rows = [
          row('idn_1', email: 'zed@gmail.com', current: true),
          row('idn_2', provider: 'apple', hidden: true, linkedAt: 1763000500),
        ]
        ..rowsAfterRemove = [
          row('idn_1', email: 'zed@gmail.com', current: true),
        ];
      final cubit = cubitFor(FakeAccountRepository(linkAnswers: const []));
      await cubit.load();

      expect(cubit.state.addable, [IdentityProvider.google]);
      expect(cubit.state.rows.last.provider, IdentityProvider.apple);

      await cubit.remove('idn_2');

      expect(rows.removes.single.id, 'idn_2');
      expect(cubit.state.rows.map((r) => r.id), ['idn_1']);
    });
  });

  group('rule 5: add', () {
    test('every link with intent link carries the held session as '
        'proof_token', () async {
      final account = FakeAccountRepository(
        linkAnswers: const [AccountLinkResult.linked(accountId: 'acc_1')],
      );
      final cubit = cubitFor(account);
      await cubit.load();

      await cubit.add(IdentityProvider.apple);

      expect(account.linkIntents, [AccountLinkIntent.link]);
      expect(account.proofTokens, ['sess_held']);
      expect(account.linkTokens, ['session_1']);
    });

    test(
      'adding a second Google ends with two Google rows, the This phone '
      'marker on the first, and the held session unchanged',
      () async {
        rows.rowsAfterRemove = null;
        final account = FakeAccountRepository(
          linkAnswers: const [AccountLinkResult.linked(accountId: 'acc_1')],
        );
        final cubit = cubitFor(account);
        await cubit.load();
        // What the server lists once the add went through.
        account.onLink = () => rows.rows = [
          row('idn_1', email: 'zed@gmail.com', current: true),
          row('idn_2', email: 'home@gmail.com', linkedAt: 1763000500),
        ];

        await cubit.add(IdentityProvider.google);

        final list = cubit.state.rows;
        expect(list.map((r) => r.provider), [
          IdentityProvider.google,
          IdentityProvider.google,
        ]);
        expect(list.first.current, isTrue);
        expect(list.last.current, isFalse);
        expect(held.token, 'sess_held');
        expect(held.provider, IdentityProvider.google);
        expect(held.email, 'zed@gmail.com');
        expect(rows.sentTokens.last, 'sess_held');
        expect(cubit.state.errorMessage, isNull);
        expect(identities.saved?.providers, {IdentityProvider.google});
      },
    );

    test('already_linked refreshes the list with no error', () async {
      final account = FakeAccountRepository(
        linkAnswers: const [
          AccountLinkResult.alreadyLinked(accountId: 'acc_1'),
        ],
      );
      final cubit = cubitFor(account);
      await cubit.load();

      await cubit.add(IdentityProvider.google);

      expect(rows.sentTokens, ['sess_held', 'sess_held']);
      expect(cubit.state.errorMessage, isNull);
      expect(held.token, 'sess_held');
    });

    test('identity has another account keeps its message', () async {
      final cubit = cubitFor(
        FakeAccountRepository(
          linkAnswers: const [AccountLinkResult.identityHasAnotherAccount()],
        ),
      );
      await cubit.load();

      await cubit.add(IdentityProvider.google);

      expect(
        cubit.state.errorMessage,
        'That email already belongs to another account.',
      );
      expect(held.token, 'sess_held');
    });

    test('409 proof required signs in the current identity once and tries '
        'again', () async {
      final account = FakeAccountRepository(
        linkAnswers: const [
          AccountLinkResult.proofRequired(),
          AccountLinkResult.linked(accountId: 'acc_1'),
        ],
      );
      final cubit = cubitFor(account);
      await cubit.load();

      await cubit.add(IdentityProvider.apple);

      // The Apple sheet, then the current identity's Google sheet.
      expect(identities.signInCalls, 2);
      expect(account.linkTokens, ['session_1', 'session_1']);
      expect(account.proofTokens, ['sess_held', 'session_2']);
      expect(identities.clearCalls, 0);
      // The fresh session is of the identity the phone signed in with.
      expect(held.token, 'session_2');
      expect(held.provider, IdentityProvider.google);
      expect(cubit.state.errorMessage, isNull);
    });

    test('a 409 proof required never clears the held session, and a second '
        'one fails plainly', () async {
      final account = FakeAccountRepository(
        linkAnswers: const [
          AccountLinkResult.proofRequired(),
          AccountLinkResult.proofRequired(),
        ],
      );
      final cubit = cubitFor(account);
      await cubit.load();

      await cubit.add(IdentityProvider.apple);

      expect(account.linkTokens, hasLength(2));
      expect(identities.clearCalls, 0);
      expect(held.token, 'sess_held');
      expect(held.provider, IdentityProvider.google);
      expect(
        cubit.state.errorMessage,
        'Sign-in did not go through. Try again.',
      );
    });

    test('409 cap identities says the account is full', () async {
      final cubit = cubitFor(
        FakeAccountRepository(
          linkAnswers: const [AccountLinkResult.capIdentities()],
        ),
      );
      await cubit.load();

      await cubit.add(IdentityProvider.google);

      expect(cubit.state.errorMessage, isNotNull);
      expect(
        cubit.state.errorMessage,
        isNot('Sign-in did not go through. Try again.'),
      );
      expect(held.token, 'sess_held');
    });

    test(
      'backing out of the sheet says nothing and puts the session back',
      () async {
        identities.cancelNextSignIn = true;
        final account = FakeAccountRepository(linkAnswers: const []);
        final cubit = cubitFor(account);
        await cubit.load();

        await cubit.add(IdentityProvider.google);

        expect(account.calls, isEmpty);
        expect(cubit.state.errorMessage, isNull);
        expect(cubit.state.status, SignInMethodsStatus.ready);
        expect(held.token, 'sess_held');
      },
    );
  });

  group('rule 6: remove', () {
    setUp(() {
      rows
        ..rows = [
          row('idn_1', email: 'zed@gmail.com', current: true),
          row('idn_2', email: 'home@gmail.com', linkedAt: 1763000500),
        ]
        ..rowsAfterRemove = [
          row('idn_1', email: 'zed@gmail.com', current: true),
        ];
    });

    test('sends the delete with the held session and refreshes', () async {
      final cubit = cubitFor(FakeAccountRepository(linkAnswers: const []));
      await cubit.load();

      await cubit.remove('idn_2');

      expect(rows.removes.single, (id: 'idn_2', token: 'sess_held'));
      expect(cubit.state.rows, hasLength(1));
      expect(cubit.state.status, SignInMethodsStatus.ready);
      expect(identities.saved?.accountId, 'acc_1');
      expect(identities.clearCalls, 0);
    });

    test('a session older than 300 seconds runs one provider sign-in and '
        'one retry, never a loop', () async {
      rows.removeAnswers = const [
        AccountIdentityRemoveResult.recentSignInRequired(),
        AccountIdentityRemoveResult.recentSignInRequired(),
      ];
      final cubit = cubitFor(FakeAccountRepository(linkAnswers: const []));
      await cubit.load();

      await cubit.remove('idn_2');

      expect(identities.signInCalls, 1);
      expect(rows.removes.map((r) => r.token), ['sess_held', 'session_1']);
      expect(cubit.state.errorMessage, isNotNull);
    });

    test('after a retry that worked the phone holds the new session and '
        'stays signed in from the current row', () async {
      rows.removeAnswers = const [
        AccountIdentityRemoveResult.recentSignInRequired(),
        AccountIdentityRemoveResult.removed(),
      ];
      final cubit = cubitFor(FakeAccountRepository(linkAnswers: const []));
      await cubit.load();

      await cubit.remove('idn_2');

      expect(held.token, 'session_1');
      expect(rows.sentTokens.last, 'session_1');
      expect(cubit.state.status, SignInMethodsStatus.ready);
      expect(identities.saved?.email, 'zed@gmail.com');
      expect(identities.saved?.provider, IdentityProvider.google);
      expect(cubit.state.errorMessage, isNull);
    });

    test('the re-sign-in runs the current row provider first', () async {
      identities.saved = const AccountIdentity(
        provider: IdentityProvider.apple,
        accountId: 'acc_1',
      );
      rows
        ..rows = [
          row('idn_1', email: 'zed@gmail.com'),
          row(
            'idn_2',
            provider: 'apple',
            hidden: true,
            current: true,
            linkedAt: 1763000500,
          ),
        ]
        ..removeAnswers = const [
          AccountIdentityRemoveResult.recentSignInRequired(),
          AccountIdentityRemoveResult.removed(),
        ];
      final cubit = cubitFor(FakeAccountRepository(linkAnswers: const []));
      await cubit.load();

      await cubit.remove('idn_1');

      expect(identities.signedInProviders, [IdentityProvider.apple]);
    });

    test('removing the current row ends on Finish signing in with the phone '
        'still on the account', () async {
      rows.rowsAfterRemove = [row('idn_2', linkedAt: 1763000500)];
      final account = FakeAccountRepository(linkAnswers: const []);
      final cubit = cubitFor(account);
      await cubit.load();

      await cubit.remove('idn_1');

      expect(cubit.state.status, SignInMethodsStatus.signedOut);
      expect(identities.clearCalls, 1);
      expect(identities.saved, isNull);
      // Never a sign-out of the device: it stays on the account.
      expect(account.signOutCalls, 0);
      expect(account.calls, isEmpty);
    });

    test('a 401 on the read after a remove also drops the session', () async {
      final cubit = cubitFor(FakeAccountRepository(linkAnswers: const []));
      await cubit.load();
      rows
        ..removeAnswers = const [AccountIdentityRemoveResult.removed()]
        ..listErrorAfterRemove = true;
      await cubit.remove('idn_2');

      expect(cubit.state.status, SignInMethodsStatus.signedOut);
      expect(identities.clearCalls, 1);
    });

    test('live incident reuses the live incident message', () async {
      rows.removeAnswers = const [
        AccountIdentityRemoveResult.liveIncident(incidentId: 'inc_7'),
      ];
      final cubit = cubitFor(FakeAccountRepository(linkAnswers: const []));
      await cubit.load();

      await cubit.remove('idn_2');

      expect(cubit.state.liveIncidentId, 'inc_7');
      expect(cubit.state.rows, hasLength(2));
    });

    test('last identity and not found refresh the list', () async {
      for (final answer in const [
        AccountIdentityRemoveResult.lastIdentity(),
        AccountIdentityRemoveResult.notFound(),
      ]) {
        rows
          ..removes.clear()
          ..sentTokens.clear()
          ..removeAnswers = [answer];
        final cubit = cubitFor(FakeAccountRepository(linkAnswers: const []));
        await cubit.load();

        await cubit.remove('idn_2');

        expect(rows.sentTokens, ['sess_held', 'sess_held']);
        expect(cubit.state.errorMessage, isNull);
      }
    });
  });
}
