import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/features/account/domain/entities/identity_provider.dart';
import 'package:critalarm/features/account/presentation/account_screen.dart';
import 'package:critalarm/features/account/presentation/cubits/account_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_fakes.dart';

void main() {
  Widget wrap(AccountCubit cubit) {
    return MaterialApp(
      theme: buildLightTheme(),
      home: BlocProvider<AccountCubit>.value(
        value: cubit,
        child: const AccountView(),
      ),
    );
  }

  /// A cubit parked on the merge-or-fresh prompt with the given counts.
  Future<(AccountCubit, FakeAccountRepository)> promptWith({
    required int topics,
    required int incidents,
  }) async {
    final account = FakeAccountRepository(
      linkAnswers: [
        AccountLinkResult.choose(
          intoAccount: 'acc_9',
          topics: topics,
          incidents: incidents,
        ),
      ],
    );
    final cubit = AccountCubit(
      identities: FakeIdentityRepository(),
      account: account,
    );
    await cubit.load();
    await cubit.signIn(IdentityProvider.google);
    return (cubit, account);
  }

  testWidgets('the prompt shows the counts the server sent', (tester) async {
    final (cubit, _) = await promptWith(topics: 3, incidents: 12);
    addTearDown(cubit.close);

    await tester.pumpWidget(wrap(cubit));
    await tester.pumpAndSettle();

    expect(find.textContaining('3 topics'), findsWidgets);
    expect(find.textContaining('12 past alerts'), findsOneWidget);
    expect(find.text('Keep both'), findsNWidgets(2));
    expect(find.text('Start fresh'), findsNWidgets(2));
  });

  testWidgets('a different count reads differently, so nothing is hardcoded', (
    tester,
  ) async {
    final (cubit, _) = await promptWith(topics: 1, incidents: 4);
    addTearDown(cubit.close);

    await tester.pumpWidget(wrap(cubit));
    await tester.pumpAndSettle();

    expect(find.textContaining('1 topic'), findsWidgets);
    expect(find.textContaining('4 past alerts'), findsOneWidget);
    expect(find.textContaining('3 topics'), findsNothing);
  });

  testWidgets('Start fresh says the tokens stop working before the call', (
    tester,
  ) async {
    final (cubit, account) = await promptWith(topics: 3, incidents: 12);
    addTearDown(cubit.close);

    await tester.pumpWidget(wrap(cubit));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('The webhook tokens for the 3 topics'),
      findsOneWidget,
    );
    expect(find.textContaining('stop working'), findsOneWidget);
    // On screen before anything is sent, not after.
    expect(account.switchCalls, 0);

    await tester.tap(find.text('Start fresh').last);
    await tester.pumpAndSettle();

    expect(account.switchCalls, 1);
  });

  testWidgets('a self-hosted server offers no sign-in at all', (tester) async {
    final account = FakeAccountRepository(linkAnswers: const [])
      ..mode = ServerMode.selfhosted;
    final cubit = AccountCubit(
      identities: FakeIdentityRepository(),
      account: account,
    );
    addTearDown(cubit.close);
    await cubit.load();

    await tester.pumpWidget(wrap(cubit));
    await tester.pumpAndSettle();

    expect(find.text('Sign in with Apple'), findsNothing);
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.text('Sign out'), findsNothing);
  });

  testWidgets('signed in shows the email, the account id and Sign out', (
    tester,
  ) async {
    final account = FakeAccountRepository(
      linkAnswers: const [AccountLinkResult.claimed(accountId: 'acc_1234')],
    );
    final cubit = AccountCubit(
      identities: FakeIdentityRepository(),
      account: account,
    );
    addTearDown(cubit.close);
    await cubit.load();
    await cubit.signIn(IdentityProvider.google);

    await tester.pumpWidget(wrap(cubit));
    await tester.pumpAndSettle();

    expect(find.text('someone@example.test'), findsOneWidget);
    expect(find.text('acc_1234'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
  });

  testWidgets('signed out on a hosted server offers both providers', (
    tester,
  ) async {
    final account = FakeAccountRepository(linkAnswers: const []);
    final cubit = AccountCubit(
      identities: FakeIdentityRepository(),
      account: account,
    );
    addTearDown(cubit.close);
    await cubit.load();

    await tester.pumpWidget(wrap(cubit));
    await tester.pumpAndSettle();

    expect(find.text('Sign in with Apple'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('Android is offered Google alone, never a dead Apple button', (
    tester,
  ) async {
    final identities = FakeIdentityRepository()
      ..available = {IdentityProvider.google};
    final cubit = AccountCubit(
      identities: identities,
      account: FakeAccountRepository(linkAnswers: const []),
    );
    addTearDown(cubit.close);
    await cubit.load();

    await tester.pumpWidget(wrap(cubit));
    await tester.pumpAndSettle();

    expect(find.text('Sign in with Apple'), findsNothing);
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}
