import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/design/design.dart';
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

  testWidgets('signed out shows the Terms and the Privacy Policy as taps', (
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

    final terms = find.text('Terms');
    final privacy = find.text('Privacy Policy');
    expect(terms, findsOneWidget);
    expect(privacy, findsOneWidget);
    expect(
      find.ancestor(of: terms, matching: find.byType(GestureDetector)),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: privacy, matching: find.byType(GestureDetector)),
      findsOneWidget,
    );
  });

  testWidgets(
    'a sentence with Privacy Policy before Terms still taps both, in order',
    (tester) async {
      final spans = buildLegalFooterSpans(
        'Read the Privacy Policy and the Terms before you sign in.',
        termsLabel: 'Terms',
        privacyLabel: 'Privacy Policy',
        termsUrl: 'https://example.test/terms',
        privacyUrl: 'https://example.test/privacy',
        textStyle: const TextStyle(),
        linkStyle: const TextStyle(decoration: TextDecoration.underline),
        onTapTerms: () {},
        onTapPrivacy: () {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Wrap(children: spans)),
        ),
      );

      final terms = find.text('Terms');
      final privacy = find.text('Privacy Policy');
      expect(terms, findsOneWidget);
      expect(privacy, findsOneWidget);
      expect(
        find.ancestor(of: terms, matching: find.byType(GestureDetector)),
        findsOneWidget,
      );
      expect(
        find.ancestor(of: privacy, matching: find.byType(GestureDetector)),
        findsOneWidget,
      );

      // The sentence put Privacy Policy first, so the rendered order
      // follows it. Nothing here assumes Terms always comes first.
      final order = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data)
          .toList();
      expect(
        order.indexOf('Privacy Policy'),
        lessThan(order.indexOf('Terms')),
      );
    },
  );

  testWidgets('signed in hides the legal footer, it already agreed', (
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

    expect(find.text('Terms'), findsNothing);
    expect(find.text('Privacy Policy'), findsNothing);
  });

  testWidgets('self-hosted has no sign-in buttons and no legal footer', (
    tester,
  ) async {
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
    expect(find.text('Terms'), findsNothing);
    expect(find.text('Privacy Policy'), findsNothing);
  });

  testWidgets('renders the calm mascot face at the top when available', (
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

    final face = tester.widget<FaceWidget>(find.byType(FaceWidget));
    expect(face.state, FaceState.calm);
    expect(face.size, 96);
  });

  testWidgets(
    'offers GitHub in disabled coming-soon state and Google with brand icon',
    (tester) async {
      final account = FakeAccountRepository(linkAnswers: const []);
      final cubit = AccountCubit(
        identities: FakeIdentityRepository(),
        account: account,
      );
      addTearDown(cubit.close);
      await cubit.load();

      await tester.pumpWidget(wrap(cubit));
      await tester.pumpAndSettle();

      expect(find.text('Continue with GitHub'), findsOneWidget);
      expect(find.text('Coming soon'), findsOneWidget);
      expect(find.byType(BrandIcon), findsWidgets);

      // GitHub button should be disabled (onPressed == null)
      final buttons = tester.widgetList<AppButton>(find.byType(AppButton));
      final githubBtn = buttons.firstWhere(
        (b) => b.label == 'Continue with GitHub',
      );
      expect(githubBtn.onPressed, isNull);
    },
  );

  testWidgets('delete account is placed outside the main auth sheet', (
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

    expect(find.text('Delete account'), findsOneWidget);
    // Delete account should NOT be inside AppSheet
    expect(
      find.descendant(
        of: find.byType(AppSheet),
        matching: find.text('Delete account'),
      ),
      findsNothing,
    );
    // But Google sign in IS inside AppSheet
    expect(
      find.descendant(
        of: find.byType(AppSheet),
        matching: find.text('Continue with Google'),
      ),
      findsOneWidget,
    );
  });
}
