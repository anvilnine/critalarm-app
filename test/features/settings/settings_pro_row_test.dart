import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/features/settings/presentation/settings_pro_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpRow(
    WidgetTester tester,
    HoldingState state, {
    double width = 390,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = Size(width * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 844),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: SettingsProRow(state: state, onSee: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('SettingsProRow', () {
    testWidgets('owned: the word and an owned mark, no line, no button', (
      tester,
    ) async {
      await pumpRow(tester, HoldingState.held);

      expect(find.text('Pro'), findsOneWidget);
      expect(find.bySemanticsLabel('You have Pro'), findsOneWidget);
      expect(find.text('See Pro'), findsNothing);
      expect(
        find.text('Alarm looks, own sounds, widgets.'),
        findsNothing,
      );
    });

    testWidgets('checking: the word and a checking mark, no button', (
      tester,
    ) async {
      await pumpRow(tester, HoldingState.pending);

      expect(find.text('Pro'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Checking your Pro purchase'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('You have Pro'), findsNothing);
      expect(find.text('See Pro'), findsNothing);
    });

    testWidgets('not owned: the word, one line and the button, no mark', (
      tester,
    ) async {
      await pumpRow(tester, HoldingState.notHeld);

      expect(find.text('Pro'), findsOneWidget);
      expect(
        find.text('Alarm looks, own sounds, widgets.'),
        findsOneWidget,
      );
      expect(find.text('See Pro'), findsOneWidget);
      expect(find.bySemanticsLabel('You have Pro'), findsNothing);
      expect(find.bySemanticsLabel('Checking your Pro purchase'), findsNothing);
    });

    testWidgets('unknown: the word with no mark, and the button', (
      tester,
    ) async {
      await pumpRow(tester, HoldingState.unknown);

      expect(find.text('Pro'), findsOneWidget);
      expect(find.text('See Pro'), findsOneWidget);
      expect(find.bySemanticsLabel('You have Pro'), findsNothing);
      expect(find.bySemanticsLabel('Checking your Pro purchase'), findsNothing);
    });

    testWidgets('the button reports a tap', (tester) async {
      var taps = 0;
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: SettingsProRow(
              state: HoldingState.notHeld,
              onSee: () => taps++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('See Pro'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('the button stays on screen at 320 wide and text scale 2', (
      tester,
    ) async {
      await pumpRow(
        tester,
        HoldingState.notHeld,
        width: 320,
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      final button = tester.getRect(find.text('See Pro'));
      expect(button.right, lessThanOrEqualTo(320));
      expect(button.left, greaterThanOrEqualTo(0));
    });
  });
}
