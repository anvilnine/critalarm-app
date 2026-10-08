import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_look_scrim.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style_scope.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_styles.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/own_alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/standard_alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
import 'package:critalarm/features/incidents/presentation/widgets/ringing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alarm_style/synthetic_photos.dart';

/// Render checks for the ringing alarm screen, built straight from
/// [RingingScreen] with a state the test controls, in the look and the
/// theme the test names. No cubit and no incident: the screen only draws.
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies(useMockApi: true);
  });

  const ringing = CriticalAlarmState(
    status: CriticalAlarmStatus.ringing,
    topic: 'prod-db',
    word: 'CRITICAL',
    subtext: 'Ringing 2 min 14 s.',
    title: 'Primary database down',
    body: 'Connection pool exhausted (500/500 connections in use)',
    meta: '03:08 / critical, database',
    severityMode: SeverityMode.crit,
    faceState: FaceState.alarmed,
  );

  /// Pumps the ringing screen on a display of [size] logical pixels.
  Future<void> pumpOn(
    WidgetTester tester,
    Size size, {
    double textScale = 1,
    Brightness brightness = Brightness.light,
    AlarmStyle? style,
    CriticalAlarmState state = ringing,
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
        child: MaterialApp(
          theme: brightness == Brightness.dark
              ? buildDarkTheme()
              : buildLightTheme(),
          home: AlarmStyleStage(
            style: style ?? standardAlarmStyle,
            stage: AlarmStage.ringing,
            severity: state.severityMode,
            child: Builder(
              builder: (context) => RingingScreen(
                state: state,
                colors: context.appColors,
                ackButtonKey: GlobalKey(),
                onAcknowledge: () {},
                onSilence: () {},
                onReadMessage: () {},
                onSelectAlarm: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Lets a fling come to rest. The pulse rings never stop, so the test
  /// cannot wait for the screen to go still.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Finder button(String label) => find.widgetWithText(AppButton, label);
  Finder card() => find.ancestor(
    of: find.text(ringing.title),
    matching: find.byType(AppSheet),
  );

  group('the wide ringing screen', () {
    for (final brightness in Brightness.values) {
      for (final textScale in [1.0, 1.3, 2.0]) {
        // In the test font, at twice the text size, the card is taller
        // than the room. It then has to scroll clear, which is the same
        // promise once the page is at its end.
        final fits = textScale < 2;
        testWidgets('on a tablet the whole message card is above "I\'m up" '
            '${fits ? 'at rest' : 'once scrolled'}, ${brightness.name}, '
            'text $textScale', (tester) async {
          await pumpOn(
            tester,
            const Size(1024, 768),
            textScale: textScale,
            brightness: brightness,
          );

          expect(tester.takeException(), isNull);
          if (!fits) {
            await tester.dragFrom(
              const Offset(700, 200),
              const Offset(0, -9000),
            );
            await settle(tester);
          }
          final up = tester.getRect(button("I'm up"));
          expect(tester.getRect(card()).bottom, lessThanOrEqualTo(up.top));
          // The three buttons are whole and on the screen.
          expect(up.top, greaterThan(0));
          expect(
            tester.getRect(button('Read the full message')).bottom,
            lessThanOrEqualTo(768),
          );
          expect(
            find.byType(ShufflingRingingFace, skipOffstage: false),
            findsOneWidget,
          );
        });
      }
    }

    for (final textScale in [1.0, 1.3, 2.0]) {
      testWidgets('on a phone on its side nothing throws, "I\'m up" is on '
          'the screen and the card scrolls clear of it, text $textScale', (
        tester,
      ) async {
        await pumpOn(tester, const Size(844, 390), textScale: textScale);

        expect(tester.takeException(), isNull);
        final up = tester.getRect(button("I'm up"));
        expect(up.top, greaterThanOrEqualTo(0));
        expect(
          tester.getRect(button('Read the full message')).bottom,
          lessThanOrEqualTo(390),
        );

        await tester.dragFrom(const Offset(600, 60), const Offset(0, -3000));
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(card()).bottom,
          lessThanOrEqualTo(tester.getRect(button("I'm up")).top),
        );
      });
    }

    testWidgets('a message far longer than the screen scrolls clear of '
        '"I\'m up" on a tablet', (tester) async {
      await pumpOn(
        tester,
        const Size(1024, 768),
        textScale: 1.3,
        state: ringing.copyWith(body: List.filled(40, ringing.body).join(' ')),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getRect(button("I'm up")).top, greaterThan(0));
      await tester.dragFrom(const Offset(700, 200), const Offset(0, -9000));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(card()).bottom,
        lessThanOrEqualTo(tester.getRect(button("I'm up")).top),
      );
    });
  });

  group('the standard look in the dark theme', () {
    testWidgets('draws the yellow face, with its waves in the colour of '
        'the words', (tester) async {
      await pumpOn(
        tester,
        const Size(390, 844),
        brightness: Brightness.dark,
      );

      expect(tester.takeException(), isNull);
      final context = tester.element(find.byType(RingingScreen));
      expect(context.appColors.faceFill, AppColors.light.yellow);
      expect(context.appColors.faceInk, AppColors.light.faceInk);
      final face = tester.widget<ShufflingRingingFace>(
        find.byType(ShufflingRingingFace),
      );
      expect(face.canvasInkColor, context.appColors.onCanvas);
      // The head stays yellow whichever face is shuffled in.
      expect(
        RingingFaceFill.keepsFillOf(
          tester.element(find.byType(ShufflingRingingFace)),
        ),
        isTrue,
      );
    });

    testWidgets('gives Silence and Read the full message a thin edge, and '
        'leaves "I\'m up" alone', (tester) async {
      await pumpOn(
        tester,
        const Size(390, 844),
        brightness: Brightness.dark,
      );

      for (final label in ['Silence', 'Read the full message']) {
        expect(
          find.ancestor(
            of: button(label),
            matching: find.byKey(RingingScreen.quietButtonEdgeKey),
          ),
          findsOneWidget,
          reason: label,
        );
      }
      expect(
        find.ancestor(
          of: button("I'm up"),
          matching: find.byKey(RingingScreen.quietButtonEdgeKey),
        ),
        findsNothing,
      );
    });

    test('the edge stands off the canvas at 3 to 1 in every severity, and '
        'is fainter than the words', () {
      for (final severity in [
        SeverityMode.none,
        SeverityMode.high,
        SeverityMode.crit,
      ]) {
        final colors = standardAlarmStyle.colorsFor(
          AlarmStage.ringing,
          base: AppColors.dark,
          severity: severity,
          brightness: Brightness.dark,
        );
        final edge = standardAlarmStyle.ringing.quietButtonEdge!(
          colors,
          Brightness.dark,
        )!;
        final drawn = Color.alphaBlend(edge, colors.canvas);
        expect(
          ColorContrast.contrastRatio(drawn, colors.canvas),
          greaterThanOrEqualTo(3),
          reason: severity.name,
        );
        expect(
          ColorContrast.contrastRatio(drawn, colors.canvas),
          lessThan(ColorContrast.contrastRatio(colors.onCanvas, colors.canvas)),
          reason: severity.name,
        );
      }
    });
  });

  testWidgets('the standard look in the light theme has no edge on its '
      'quiet buttons', (tester) async {
    await pumpOn(tester, const Size(390, 844));

    expect(find.byKey(RingingScreen.quietButtonEdgeKey), findsNothing);
    expect(
      standardAlarmStyle.ringing.quietButtonEdge!(
        AppColors.light,
        Brightness.light,
      ),
      isNull,
    );
  });

  group('the own look', () {
    final photos = syntheticPhotos();
    AlarmStyle look(SyntheticPhoto photo) => buildOwnAlarmStyle(
      photo: OwnLookPhoto(null),
      measure: measureOwnPhoto(photo.rgba, photo.width, photo.height),
      accent: ownLookAccents.first,
    );

    test('the face outline and the waves read at 3 to 1 on everything the '
        'scrim leaves of any photo', () {
      for (final photo in photos) {
        final style = look(photo);
        final scrim = ownLookScrimOf(
          measureOwnPhoto(photo.rgba, photo.width, photo.height),
        );
        for (final brightness in Brightness.values) {
          final colors = style.colorsFor(
            AlarmStage.ringing,
            base: brightness == Brightness.dark
                ? AppColors.dark
                : AppColors.light,
            severity: SeverityMode.crit,
            brightness: brightness,
          );
          final outline = style.ringing.faceOutline!;
          for (final behind in ownLookBackdropTones(colors, scrim)) {
            for (final line in [outline, colors.onCanvas]) {
              expect(
                ColorContrast.contrastRatio(line, behind),
                greaterThanOrEqualTo(3),
                reason: '${photo.name} ${brightness.name} on $behind',
              );
            }
          }
        }
      }
    });

    testWidgets('hands the face its light outline and waves', (tester) async {
      await pumpOn(tester, const Size(390, 844), style: look(photos[1]));

      expect(tester.takeException(), isNull);
      final face = tester.widget<ShufflingRingingFace>(
        find.byType(ShufflingRingingFace),
      );
      expect(face.strokeColor, ownLookWords);
      expect(face.canvasInkColor, ownLookWords);
    });
  });

  group('the disc behind the face', () {
    testWidgets('is on the canvas exactly when the face is drawn', (
      tester,
    ) async {
      final drawn = <bool>{};
      for (final size in const [
        Size(390, 844),
        Size(375, 667),
        Size(320, 568),
        Size(1024, 768),
        Size(844, 390),
      ]) {
        for (final textScale in [1.0, 1.3, 2.0]) {
          await pumpOn(tester, size, textScale: textScale);
          expect(tester.takeException(), isNull);

          final context = tester.element(find.byType(RingingScreen));
          final look = standardAlarmStyle.ringing;
          final drawsFace = RingingScreen.drawsFace(
            context,
            state: ringing,
            look: look,
          );
          final reason = '$size at $textScale';
          expect(
            find.byType(ShufflingRingingFace).evaluate().isNotEmpty,
            drawsFace,
            reason: reason,
          );
          drawn.add(drawsFace);

          final whole = look.ambient(AppColors.light, Brightness.light);
          final profile = look.ambientFor(
            AppColors.light,
            Brightness.light,
            drawsFace: drawsFace,
          );
          expect(profile.shapes, hasLength(3), reason: reason);
          if (drawsFace) {
            expect(profile, whole, reason: reason);
          } else {
            expect(profile.shapes.first.opacity, 0, reason: reason);
            expect(profile.shapes.sublist(1), whole.shapes.sublist(1));
            expect(profile.canvas, whole.canvas);
          }
        }
      }
      // Both cases were met, so neither half of the check ran on nothing.
      expect(drawn, {true, false});
    });

    test('only the standard look has one', () {
      for (final style in alarmStyles) {
        expect(
          style.ringing.faceShape,
          style == standardAlarmStyle ? 0 : isNull,
          reason: style.id.id,
        );
      }
    });
  });
}
