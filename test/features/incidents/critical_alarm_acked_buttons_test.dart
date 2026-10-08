import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/design/components/buttons.dart';
import 'package:critalarm/design/components/sheets.dart';
import 'package:critalarm/design/faces/face_widget.dart';
import 'package:critalarm/design/theme/severity.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style_scope.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/standard_alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/critical_alarm_screen.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small render checks for A25's "At my desk" button, built straight from
/// [AcknowledgedScreen] with a state the test controls. Going through the
/// real screen and its cubit would also start the after-ack reminders timer,
/// which is a different feature's job to test.
void main() {
  // The value of the Source row, as the mock alarm has it.
  const sourceLine = '03:08 / critical, database';

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies(useMockApi: true);
  });

  CriticalAlarmState stateFor(CriticalAlarmStatus status) {
    final now = DateTime.now();
    return CriticalAlarmState(
      status: status,
      meta: sourceLine,
      incident: Incident(
        id: 'inc_1',
        topic: 'prod-db',
        openedAt: now.subtract(const Duration(minutes: 3)),
        ackedAt: now,
      ),
      topic: 'prod-db',
      isAcknowledged: true,
    );
  }

  Widget buildTestApp(
    CriticalAlarmStatus status, {
    Brightness brightness = Brightness.light,
  }) {
    return BlocProvider<TopicsCubit>.value(
      value: getIt<TopicsCubit>(),
      child: MaterialApp(
        theme: brightness == Brightness.dark
            ? buildDarkTheme()
            : buildLightTheme(),
        home: Builder(
          builder: (context) => AcknowledgedScreen(
            state: stateFor(status),
            colors: context.appColors,
          ),
        ),
      ),
    );
  }

  List<String> buttonLabels(WidgetTester tester) => tester
      .widgetList<AppButton>(find.byType(AppButton))
      .map((button) => button.label)
      .toList();

  group('the acked screen bottom bar', () {
    testWidgets('acked state renders At my desk over Back to topics', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp(CriticalAlarmStatus.acknowledged));
      await tester.pump();

      expect(buttonLabels(tester), ['At my desk', 'Back to topics']);
    });

    testWidgets('closed state leaves the one way out', (tester) async {
      await tester.pumpWidget(buildTestApp(CriticalAlarmStatus.closed));
      await tester.pump();

      expect(buttonLabels(tester), ['Back to topics']);
    });

    testWidgets('Back to topics is the paper button in both states', (
      tester,
    ) async {
      for (final status in [
        CriticalAlarmStatus.acknowledged,
        CriticalAlarmStatus.closed,
      ]) {
        await tester.pumpWidget(buildTestApp(status));
        await tester.pump();

        final buttons = tester
            .widgetList<AppButton>(find.byType(AppButton))
            .toList();
        expect(buttons.length, lessThanOrEqualTo(2));
        expect(buttons.last.label, 'Back to topics');
        expect(buttons.last.variant, AppButtonVariant.paper);
      }
    });

    testWidgets('the topic is reached by its pill, once, in both states', (
      tester,
    ) async {
      for (final status in [
        CriticalAlarmStatus.acknowledged,
        CriticalAlarmStatus.closed,
      ]) {
        await tester.pumpWidget(buildTestApp(status));
        await tester.pump();

        expect(find.bySemanticsLabel('Open prod-db'), findsOneWidget);
        expect(find.text('prod-db'), findsOneWidget);
      }
    });
  });

  group('the acked screen layout', () {
    /// Pumps the screen on a display of [size] logical pixels.
    Future<void> pumpOn(
      WidgetTester tester,
      Size size, {
      double textScale = 1,
      CriticalAlarmStatus status = CriticalAlarmStatus.acknowledged,
      Brightness brightness = Brightness.light,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: buildTestApp(status, brightness: brightness),
        ),
      );
      await tester.pumpAndSettle();
    }

    // The title, not the row of the same name in the details card.
    Finder title() => find.text('Acknowledged').first;

    testWidgets('on a 375 pt phone the title is one line and the whole '
        'details card is above the pinned hint, with nothing scrolled', (
      tester,
    ) async {
      await pumpOn(tester, const Size(375, 667));

      expect(tester.takeException(), isNull);
      // One line: no taller than one line of the display type.
      final titleStyle = tester.widget<Text>(title()).style!;
      expect(
        tester.getSize(title()).height,
        lessThan(titleStyle.fontSize! * 1.3),
      );
      expect(tester.getSize(title()).width, lessThanOrEqualTo(375));

      final card = tester.getRect(find.text('Source'));
      final hint = tester.getRect(
        find.text('Rings again in 10 min unless you tap At my desk.'),
      );
      expect(card.bottom, lessThan(hint.top));
      // And the hint has its own space above the first button.
      final desk = tester.getRect(find.widgetWithText(AppButton, 'At my desk'));
      expect(hint.bottom, lessThanOrEqualTo(desk.top));
    });

    testWidgets('on a 360 dp phone the title still fits one line', (
      tester,
    ) async {
      await pumpOn(tester, const Size(360, 780));

      expect(tester.takeException(), isNull);
      final titleStyle = tester.widget<Text>(title()).style!;
      expect(
        tester.getSize(title()).height,
        lessThan(titleStyle.fontSize! * 1.3),
      );
      expect(tester.getSize(title()).width, lessThanOrEqualTo(360 - 40));
    });

    testWidgets('at a large text size nothing overflows and the details '
        'scroll clear of the pinned buttons', (tester) async {
      await pumpOn(tester, const Size(375, 667), textScale: 2);

      expect(tester.takeException(), isNull);
      expect(buttonLabels(tester), ['At my desk', 'Back to topics']);

      // The hint is too long to pin at this size: it is in the list.
      // Scrolled to the end, the card and the hint are both above the
      // pinned buttons.
      await tester.dragFrom(const Offset(187, 120), const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final card = tester.getRect(find.text('Source'));
      final hint = tester.getRect(
        find.text('Rings again in 10 min unless you tap At my desk.'),
      );
      final desk = tester.getRect(find.widgetWithText(AppButton, 'At my desk'));
      expect(card.bottom, lessThan(hint.top));
      expect(hint.bottom, lessThanOrEqualTo(desk.top));
      // The pinned block leaves most of the screen to the list.
      expect(desk.top, greaterThan(667 / 2));
    });

    testWidgets('on a small phone at 1.3 the Source row, value and all, '
        'scrolls clear of the pinned hint', (tester) async {
      await pumpOn(tester, const Size(375, 667), textScale: 1.3);

      expect(tester.takeException(), isNull);
      // The hint is still pinned at this size.
      final hint = find.text(
        'Rings again in 10 min unless you tap At my desk.',
      );
      final desk = find.widgetWithText(AppButton, 'At my desk');
      expect(
        tester.getRect(hint).bottom,
        lessThanOrEqualTo(
          tester.getRect(desk).top,
        ),
      );

      await tester.dragFrom(const Offset(187, 120), const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.text(sourceLine)).bottom,
        lessThan(tester.getRect(hint).top),
      );
      // The whole card, with its padding, is above the hint too.
      final card = find.ancestor(
        of: find.text('Source'),
        matching: find.byType(AppSheet),
      );
      expect(
        tester.getRect(card).bottom,
        lessThanOrEqualTo(tester.getRect(hint).top),
      );
    });

    for (final brightness in Brightness.values) {
      for (final textScale in [1.0, 1.3, 2.0]) {
        testWidgets('on a tablet the wide layout draws the face, the title, '
            'the topic and the details above the pinned buttons, '
            '${brightness.name}, text $textScale', (tester) async {
          await pumpOn(
            tester,
            const Size(1024, 768),
            textScale: textScale,
            brightness: brightness,
          );

          // The wide layout used to throw here and draw only the buttons.
          expect(tester.takeException(), isNull);
          expect(find.byType(FaceWidget), findsOneWidget);
          expect(title(), findsOneWidget);
          expect(find.text('prod-db'), findsOneWidget);
          for (final label in ['Started', 'Source']) {
            expect(find.text(label), findsOneWidget, reason: label);
          }
          expect(find.text(sourceLine), findsOneWidget);
          expect(buttonLabels(tester), ['At my desk', 'Back to topics']);

          // In the test font, at twice the text size, the column is taller
          // than the room and has to scroll clear instead.
          if (textScale >= 2) {
            await tester.dragFrom(
              const Offset(700, 200),
              const Offset(0, -3000),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          } else {
            expect(tester.getRect(title()).top, greaterThanOrEqualTo(0));
          }
          final desk = tester.getRect(
            find.widgetWithText(AppButton, 'At my desk'),
          );
          final back = tester.getRect(
            find.widgetWithText(AppButton, 'Back to topics'),
          );
          expect(desk.top, greaterThan(0));
          expect(back.bottom, lessThanOrEqualTo(768));
          final card = find.ancestor(
            of: find.text('Source'),
            matching: find.byType(AppSheet),
          );
          expect(tester.getRect(card).bottom, lessThanOrEqualTo(desk.top));
        });
      }
    }

    for (final textScale in [1.0, 1.3, 2.0]) {
      for (final status in [
        CriticalAlarmStatus.acknowledged,
        CriticalAlarmStatus.closed,
      ]) {
        testWidgets('on a phone on its side nothing throws, the buttons are '
            'on the screen and the details scroll clear of them, '
            '${status.name}, text $textScale', (tester) async {
          await pumpOn(
            tester,
            const Size(844, 390),
            textScale: textScale,
            status: status,
          );

          expect(tester.takeException(), isNull);
          final isClosed = status == CriticalAlarmStatus.closed;
          expect(buttonLabels(tester), [
            if (!isClosed) 'At my desk',
            'Back to topics',
          ]);
          final first = find.byType(AppButton).first;
          expect(tester.getRect(first).top, greaterThanOrEqualTo(0));
          expect(
            tester.getRect(find.byType(AppButton).last).bottom,
            lessThanOrEqualTo(390),
          );
          expect(title(), findsOneWidget);

          await tester.dragFrom(const Offset(600, 60), const Offset(0, -3000));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final card = find.ancestor(
            of: find.text('Source'),
            matching: find.byType(AppSheet),
          );
          expect(
            tester.getRect(card).bottom,
            lessThanOrEqualTo(tester.getRect(first).top),
          );
        });
      }
    }

    testWidgets('the face is the yellow one, dark outline and features, in '
        'the dark theme too', (tester) async {
      await tester.pumpWidget(
        BlocProvider<TopicsCubit>.value(
          value: getIt<TopicsCubit>(),
          child: MaterialApp(
            theme: buildDarkTheme(),
            home: AlarmStyleStage(
              style: standardAlarmStyle,
              stage: AlarmStage.acknowledged,
              severity: SeverityMode.crit,
              child: Builder(
                builder: (context) => AcknowledgedScreen(
                  state: stateFor(CriticalAlarmStatus.acknowledged),
                  colors: context.appColors,
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final face = tester.widget<FaceWidget>(find.byType(FaceWidget));
      expect(face.overrideStrokeColor, AppColors.light.faceStroke);
      expect(face.overrideInkColor, AppColors.light.faceInk);
      expect(
        tester.element(find.byType(FaceWidget)).appColors.faceFill,
        AppColors.light.yellow,
      );
    });

    testWidgets('the acknowledged colours stay after At my desk', (
      tester,
    ) async {
      await pumpOn(
        tester,
        const Size(375, 667),
        status: CriticalAlarmStatus.closed,
      );

      expect(tester.takeException(), isNull);
      final titleColor = tester.widget<Text>(title()).style!.color;
      final topicColor = tester.widget<Text>(find.text('prod-db')).style!.color;
      expect(titleColor, topicColor);
    });

    testWidgets('the face keeps its dark outline and features on the '
        'acknowledged canvas', (tester) async {
      for (final status in [
        CriticalAlarmStatus.acknowledged,
        CriticalAlarmStatus.closed,
      ]) {
        await tester.pumpWidget(
          BlocProvider<TopicsCubit>.value(
            value: getIt<TopicsCubit>(),
            child: MaterialApp(
              theme: buildLightTheme(),
              home: SeverityScope(
                mode: SeverityMode.ack,
                child: Builder(
                  builder: (context) => AcknowledgedScreen(
                    state: stateFor(status),
                    colors: context.appColors,
                  ),
                ),
              ),
            ),
          ),
        );

        final face = tester.widget<FaceWidget>(find.byType(FaceWidget));
        expect(face.overrideStrokeColor, AppColors.light.faceStroke);
        expect(face.overrideInkColor, AppColors.light.faceInk);
      }
    });
  });
}
