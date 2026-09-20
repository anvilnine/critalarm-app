import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/features/topics/presentation/widgets/topic_tokens_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // The sheet used to spell this out on a topic's last token. It does not any
  // more: the missing Revoke button says it.
  const note =
      'A topic keeps at least one token. To replace this one, make a new '
      'token first, then revoke this one.';

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies(useMockApi: true);
  });

  setUp(() {
    getIt<MockServer>().seedCalm();
  });

  Widget buildTestApp() {
    return MaterialApp(
      theme: buildLightTheme(),
      home: const Scaffold(
        body: SingleChildScrollView(
          child: TopicTokensSection(topicName: 'prod-db'),
        ),
      ),
    );
  }

  group('TopicTokensSection', () {
    testWidgets('a row shows the token name, never its id', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Token 1'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.contains('tok_') ?? false),
        ),
        findsNothing,
      );
    });

    testWidgets('tapping a row opens the sheet and saving renames it', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Token 1'));
      await tester.pumpAndSettle();

      expect(find.text('Save'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'CI server');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('CI server'), findsOneWidget);
      expect(find.text('Token 1'), findsNothing);
      expect(
        getIt<MockServer>().getTopicTokens('prod-db').first.name,
        'CI server',
      );
    });

    testWidgets('the last token has no Revoke button and no explanation', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Token 1'));
      await tester.pumpAndSettle();

      expect(find.text('Revoke'), findsNothing);
      expect(find.text(note), findsNothing);
    });

    testWidgets('a second token brings the Revoke button back', (tester) async {
      getIt<MockServer>().createTopicToken('prod-db');

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Token 1'));
      await tester.pumpAndSettle();

      expect(find.text('Revoke'), findsOneWidget);
      expect(find.text(note), findsNothing);
    });

    testWidgets('a name another token already uses warns and still saves', (
      tester,
    ) async {
      getIt<MockServer>().createTopicToken('prod-db', tokenName: 'CI server');

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Token 1'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'CI server');
      await tester.pump();

      expect(
        find.text('This topic already has a token called CI server.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        getIt<MockServer>().getTopicTokens('prod-db').first.name,
        'CI server',
      );
    });

    testWidgets('a token keeping its own name does not warn', (tester) async {
      getIt<MockServer>().createTopicToken('prod-db', tokenName: 'CI server');

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Token 1'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Token 1');
      await tester.pump();

      expect(find.textContaining('already has a token called'), findsNothing);
    });

    testWidgets('a name nothing else uses does not warn', (tester) async {
      getIt<MockServer>().createTopicToken('prod-db', tokenName: 'CI server');

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Token 1'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Backup runner');
      await tester.pump();

      expect(find.textContaining('already has a token called'), findsNothing);
    });
  });
}
