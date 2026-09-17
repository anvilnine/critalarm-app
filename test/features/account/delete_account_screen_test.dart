import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/design/components/switches.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/features/account/domain/entities/account_identity.dart';
import 'package:critalarm/features/account/domain/entities/identity_provider.dart';
import 'package:critalarm/features/account/presentation/account_screen.dart';
import 'package:critalarm/features/account/presentation/cubits/account_cubit.dart';
import 'package:critalarm/features/account/presentation/delete_account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_fakes.dart';

void main() {
  late FakeIdentityRepository identities;

  setUp(() => identities = FakeIdentityRepository());

  Widget wrapConfirm(
    AccountCubit cubit, {
    required Future<void> Function() onManage,
  }) {
    return MaterialApp(
      theme: buildLightTheme(),
      home: BlocProvider<AccountCubit>.value(
        value: cubit,
        child: DeleteAccountView(onManageSubscription: onManage),
      ),
    );
  }

  Widget wrapAccount(AccountCubit cubit) {
    return MaterialApp(
      theme: buildLightTheme(),
      home: BlocProvider<AccountCubit>.value(
        value: cubit,
        child: const AccountView(),
      ),
    );
  }

  /// A loaded cubit over a repository the test can look at afterwards.
  Future<(AccountCubit, FakeAccountRepository)> loaded({
    bool isPaid = false,
    bool signedIn = false,
    ServerMode mode = ServerMode.hosted,
    List<AccountDeleteResult> deleteAnswers = const [
      AccountDeleteResult.deleted(),
    ],
  }) async {
    final account = FakeAccountRepository(linkAnswers: const [])
      ..isPaid = isPaid
      ..mode = mode
      ..deleteAnswers = deleteAnswers;
    if (signedIn) {
      identities
        ..saved = const AccountIdentity(
          provider: IdentityProvider.google,
          accountId: 'acc_1',
          email: 'someone@example.test',
        )
        ..session = const IdentitySession(
          token: 'session_live',
          provider: IdentityProvider.google,
        );
    }
    final cubit = AccountCubit(identities: identities, account: account);
    await cubit.load();
    return (cubit, account);
  }

  testWidgets('a paid tier reads the billing warning and can act on it', (
    tester,
  ) async {
    final (cubit, _) = await loaded(isPaid: true);
    addTearDown(cubit.close);
    var manageTaps = 0;

    await tester.pumpWidget(
      wrapConfirm(cubit, onManage: () async => manageTaps++),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your subscription keeps billing'), findsOneWidget);
    expect(
      find.textContaining('does not cancel it'),
      findsOneWidget,
    );
    expect(find.text('Manage subscription'), findsOneWidget);

    await tester.tap(find.text('Manage subscription'));
    await tester.pumpAndSettle();

    expect(manageTaps, 1);
  });

  testWidgets('the free tier is not offered a subscription to manage', (
    tester,
  ) async {
    final (cubit, _) = await loaded();
    addTearDown(cubit.close);

    await tester.pumpWidget(wrapConfirm(cubit, onManage: () async {}));
    await tester.pumpAndSettle();

    expect(find.text('Manage subscription'), findsNothing);
    expect(find.text('Your subscription keeps billing'), findsNothing);
    // The rest of the warning list is there either way.
    expect(find.text('This cannot be undone.'), findsOneWidget);
  });

  testWidgets('nothing is sent until the second deliberate action', (
    tester,
  ) async {
    // A 409 rather than a 204, so the screen stays put instead of leaving for
    // a route this test has no router for.
    final (cubit, account) = await loaded(
      deleteAnswers: const [
        AccountDeleteResult.liveIncident(incidentId: 'inc_42'),
      ],
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(wrapConfirm(cubit, onManage: () async {}));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();

    expect(account.deleteIdentityTokens, isEmpty);

    await tester.tap(find.byType(AppSwitch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();

    expect(account.deleteIdentityTokens.length, 1);
    expect(find.text('An alarm is still ringing'), findsOneWidget);
    expect(find.text('Acknowledge it, then delete.'), findsOneWidget);
  });

  testWidgets('the way out is on the account screen signed out', (
    tester,
  ) async {
    final (cubit, _) = await loaded();
    addTearDown(cubit.close);

    await tester.pumpWidget(wrapAccount(cubit));
    await tester.pumpAndSettle();

    // An account exists from the first registration, so nobody has to sign in
    // before they can leave.
    expect(find.text('Delete account'), findsOneWidget);
  });

  testWidgets('and on the account screen signed in', (tester) async {
    final (cubit, _) = await loaded(signedIn: true);
    addTearDown(cubit.close);

    await tester.pumpWidget(wrapAccount(cubit));
    await tester.pumpAndSettle();

    expect(find.text('Delete account'), findsOneWidget);
  });

  testWidgets('a selfhosted server offers no delete anywhere', (tester) async {
    final (cubit, _) = await loaded(mode: ServerMode.selfhosted);
    addTearDown(cubit.close);

    await tester.pumpWidget(wrapAccount(cubit));
    await tester.pumpAndSettle();
    expect(find.text('Delete account'), findsNothing);

    await tester.pumpWidget(wrapConfirm(cubit, onManage: () async {}));
    await tester.pumpAndSettle();
    expect(find.text('Delete my account'), findsNothing);
    expect(find.byType(AppSwitch), findsNothing);
  });
}
