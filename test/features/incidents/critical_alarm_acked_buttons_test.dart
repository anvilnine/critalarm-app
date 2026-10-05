import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/design/components/buttons.dart';
import 'package:critalarm/design/faces/face_widget.dart';
import 'package:critalarm/design/theme/severity.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
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
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies(useMockApi: true);
  });

  CriticalAlarmState stateFor(CriticalAlarmStatus status) {
    final now = DateTime.now();
    return CriticalAlarmState(
      status: status,
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

  Widget buildTestApp(CriticalAlarmStatus status) {
    return BlocProvider<TopicsCubit>.value(
      value: getIt<TopicsCubit>(),
      child: MaterialApp(
        theme: buildLightTheme(),
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
          child: buildTestApp(status),
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
