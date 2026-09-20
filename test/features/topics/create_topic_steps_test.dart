import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/design/components/switches.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/features/topics/presentation/create_topic_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_translations.dart';

void main() {
  setUpAll(() async {
    await loadTestTranslations();
    await configureDependencies(useMockApi: true);
  });

  setUp(() {
    getIt<MockServer>().seedCalm();
  });

  /// The screen sits on a pushed route, the way it does in the app, so a back
  /// intent has somewhere to go back to.
  Widget buildTestApp() {
    return BlocProvider<TopicsCubit>.value(
      value: getIt<TopicsCubit>(),
      child: MaterialApp(
        theme: buildLightTheme(),
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CreateTopicScreen(),
                ),
              ),
              child: const Text('launcher'),
            ),
          ),
        ),
      ),
    );
  }

  /// pumpAndSettle never returns on this screen: the ambient canvas behind
  /// the card animates forever. Pump past the route push and the step swap
  /// instead.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  Finder fieldWithHint(String hint) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.hintText == hint,
  );

  final nameField = fieldWithHint('prod-db');
  final tokenNameField = fieldWithHint('CI server');

  Future<void> openScreen(WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp());
    await settle(tester);
    await tester.tap(find.text('launcher'));
    await settle(tester);
  }

  group('CreateTopicScreen system back', () {
    testWidgets(
      'on step 2 it returns to step 1 and keeps what was typed',
      (tester) async {
        await openScreen(tester);

        await tester.enterText(nameField, 'release-bot');
        await settle(tester);
        await tester.tap(find.byType(AppSwitch));
        await settle(tester);
        expect(tester.widget<AppSwitch>(find.byType(AppSwitch)).value, isTrue);

        await tester.tap(find.text('Next'));
        await settle(tester);
        await tester.enterText(tokenNameField, 'CI box');
        await settle(tester);

        await tester.binding.handlePopRoute();
        await settle(tester);

        // Still on the screen, back on step 1, with both answers intact.
        expect(find.text('launcher'), findsNothing);
        expect(find.text('Step 1 of 2'), findsOneWidget);
        expect(
          tester.widget<TextField>(nameField).controller?.text,
          'release-bot',
        );
        expect(tester.widget<AppSwitch>(find.byType(AppSwitch)).value, isTrue);

        // The token name survived the trip as well.
        await tester.tap(find.text('Next'));
        await settle(tester);
        expect(
          tester.widget<TextField>(tokenNameField).controller?.text,
          'CI box',
        );
      },
    );

    testWidgets('on step 1 it leaves the screen', (tester) async {
      await openScreen(tester);

      await tester.enterText(nameField, 'release-bot');
      await settle(tester);

      await tester.binding.handlePopRoute();
      await settle(tester);

      expect(find.text('launcher'), findsOneWidget);
      expect(find.text('Step 1 of 2'), findsNothing);
    });

    testWidgets('after the topic is created it leaves the screen', (
      tester,
    ) async {
      await openScreen(tester);

      await tester.enterText(nameField, 'release-bot');
      await settle(tester);
      await tester.tap(find.text('Next'));
      await settle(tester);
      await tester.tap(find.text('Create topic'));
      await settle(tester);
      expect(find.text('Endpoint and token'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await settle(tester);

      expect(find.text('launcher'), findsOneWidget);
    });
  });

  group('CreateTopicScreen step 2 recap', () {
    testWidgets('names the topic the token belongs to, in mono', (
      tester,
    ) async {
      await openScreen(tester);

      await tester.enterText(nameField, 'release-bot');
      await settle(tester);
      await tester.tap(find.text('Next'));
      await settle(tester);

      expect(find.text('Token for'), findsOneWidget);
      final name = tester.widget<Text>(find.text('release-bot'));
      expect(name.style?.fontFamily, AppTypography.fontMono);
    });

    testWidgets('a long name stays on one line', (tester) async {
      // 64 characters, the longest a topic name can be.
      final longName = 'a' * 64;

      await openScreen(tester);

      await tester.enterText(nameField, longName);
      await settle(tester);
      await tester.tap(find.text('Next'));
      await settle(tester);

      final name = tester.widget<Text>(find.text(longName));
      expect(name.maxLines, 1);
      expect(name.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });

    testWidgets('critical delivery is called out only when it is on', (
      tester,
    ) async {
      await openScreen(tester);

      await tester.enterText(nameField, 'release-bot');
      await settle(tester);
      await tester.tap(find.text('Next'));
      await settle(tester);

      // Off is the default, so the recap says nothing about it.
      expect(find.text('Critical delivery on'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Back'));
      await settle(tester);
      await tester.tap(find.byType(AppSwitch));
      await settle(tester);
      await tester.tap(find.text('Next'));
      await settle(tester);

      expect(find.text('Critical delivery on'), findsOneWidget);
    });
  });
}
