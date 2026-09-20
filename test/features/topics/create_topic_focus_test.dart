import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/design/theme/theme.dart';
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

  // Motion is left on. Under reduce motion the step swap runs at
  // Duration.zero, and RenderAnimatedSize asserts when it is laid out with a
  // zero duration. That assert predates this test and has nothing to do with
  // focus, so the reduce motion case is not covered here.
  Widget buildTestApp() {
    return BlocProvider<TopicsCubit>.value(
      value: getIt<TopicsCubit>(),
      child: MaterialApp(
        theme: buildLightTheme(),
        home: const CreateTopicScreen(),
      ),
    );
  }

  /// The one field on the step that is showing. Both steps use the same
  /// widget, so the placeholder is what tells them apart.
  Finder fieldWithHint(String hint) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.hintText == hint,
  );

  final nameField = fieldWithHint('prod-db');
  final tokenNameField = fieldWithHint('CI server');

  /// pumpAndSettle never returns on this screen: the ambient canvas behind
  /// the card animates forever. Pump past the step swap instead.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  bool hasFocus(WidgetTester tester, Finder field) =>
      tester.widget<TextField>(field).focusNode?.hasFocus ?? false;

  group('CreateTopicScreen focus', () {
    testWidgets('the topic name field has focus when the screen opens', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());
      await settle(tester);

      expect(hasFocus(tester, nameField), isTrue);
    });

    testWidgets(
      'Next with a valid name moves to step 2 and the token field holds focus',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await settle(tester);

        await tester.enterText(nameField, 'release-bot');
        await settle(tester);

        await tester.tap(find.text('Next'));
        await settle(tester);

        expect(tokenNameField, findsOneWidget);
        expect(hasFocus(tester, tokenNameField), isTrue);
      },
    );

    testWidgets(
      'Back from step 2 returns to step 1 and the topic name field holds '
      'focus',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await settle(tester);

        await tester.enterText(nameField, 'release-bot');
        await settle(tester);
        await tester.tap(find.text('Next'));
        await settle(tester);

        await tester.tap(find.bySemanticsLabel('Back'));
        await settle(tester);

        expect(nameField, findsOneWidget);
        expect(hasFocus(tester, nameField), isTrue);
        // The caret sits after the name, so typing carries on from the end.
        expect(
          tester.widget<TextField>(nameField).controller?.selection,
          const TextSelection.collapsed(offset: 'release-bot'.length),
        );
      },
    );

    testWidgets(
      'Next with an empty name shows the error and the topic name field has '
      'focus',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await settle(tester);

        // The user put the keyboard away by hand before pressing Next.
        tester.binding.focusManager.primaryFocus?.unfocus();
        await settle(tester);
        expect(hasFocus(tester, nameField), isFalse);

        await tester.tap(find.text('Next'));
        await settle(tester);

        expect(find.text('Give the topic a name.'), findsOneWidget);
        expect(hasFocus(tester, nameField), isTrue);
      },
    );

    testWidgets(
      'Next with a name already in the topic list shows the error and the '
      'topic name field has focus',
      (tester) async {
        await getIt<TopicsCubit>().refresh();

        await tester.pumpWidget(buildTestApp());
        await settle(tester);

        await tester.enterText(nameField, 'prod-db');
        await settle(tester);

        // A name the app already holds turns the Next button off, so the only
        // way to ask for step 2 is the keyboard's done key.
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await settle(tester);

        expect(
          find.text('A topic with that name already exists.'),
          findsOneWidget,
        );
        expect(nameField, findsOneWidget);
        expect(hasFocus(tester, nameField), isTrue);
      },
    );

    testWidgets('Create topic dismisses the keyboard', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await settle(tester);

      await tester.enterText(nameField, 'release-bot');
      await settle(tester);
      await tester.tap(find.text('Next'));
      await settle(tester);
      expect(hasFocus(tester, tokenNameField), isTrue);

      // Held on to because a successful create takes the field off the step.
      final tokenFocus = tester.widget<TextField>(tokenNameField).focusNode!;

      await tester.tap(find.text('Create topic'));
      await tester.pump();

      expect(tokenFocus.hasFocus, isFalse);

      await settle(tester);
      expect(find.text('Endpoint and token'), findsOneWidget);
    });
  });
}
