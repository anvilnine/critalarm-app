import 'package:critalarm/features/account/domain/entities/account_identity.dart';
import 'package:critalarm/features/account/domain/entities/identity_provider.dart';
import 'package:critalarm/features/account/domain/usecases/sign_in_restore.dart';
import 'package:critalarm/features/account/presentation/cubits/account_cubit.dart';
import 'package:critalarm/features/account/presentation/cubits/account_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_fakes.dart';

/// Rules 2 and 7: the "Ways to sign in" row on the account card.
void main() {
  late FakeIdentityRepository identities;
  late FakeHeldSession held;
  late FakeAccountIdentities rows;

  setUp(() {
    identities = FakeIdentityRepository();
    held = FakeHeldSession('sess_held');
    rows = FakeAccountIdentities();
  });

  AccountCubit cubit() {
    final account = FakeAccountRepository(linkAnswers: const []);
    return AccountCubit(
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
      accountIdentities: rows,
    );
  }

  test(
    'rule 2: signed in with a live session, the row carries the count',
    () async {
      identities.saved = const AccountIdentity(
        provider: IdentityProvider.google,
        accountId: 'acc_1',
      );
      rows.rows = [
        identityRow(current: true),
        identityRow(id: 'idn_2', linkedAt: 1763000500),
        identityRow(id: 'idn_3', provider: 'apple', linkedAt: 1763000900),
      ];
      final c = cubit();

      await c.load();

      expect(c.state.status, AccountStatus.signedIn);
      expect(c.state.signInWays, 3);
      expect(rows.sentTokens.last, 'sess_held');
    },
  );

  test('rule 2: signed in on paper with a session the server no longer '
      'takes, no row', () async {
    identities.saved = const AccountIdentity(
      provider: IdentityProvider.google,
      accountId: 'acc_1',
    );
    rows.rows = [identityRow()];
    final c = cubit();

    await c.load();

    expect(c.state.signInWays, isNull);
  });

  test('rule 2: hidden in the Finish signing in state', () async {
    held.token = null;
    rows.rows = [identityRow()];
    final c = cubit();

    await c.load();

    expect(c.state.status, AccountStatus.unfinished);
    expect(c.state.signInWays, isNull);
  });

  test('rule 2: the list failing hides the row and keeps the person signed '
      'in', () async {
    identities.saved = const AccountIdentity(
      provider: IdentityProvider.google,
      accountId: 'acc_1',
    );
    rows.error = Exception('offline');
    final c = cubit();

    await c.load();

    expect(c.state.status, AccountStatus.signedIn);
    expect(c.state.signInWays, isNull);
  });
}
