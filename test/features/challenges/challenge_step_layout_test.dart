import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/challenges/domain/challenge_incident.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/challenges/domain/challenge_rule.dart';
import 'package:critalarm/features/challenges/presentation/challenge.dart';
import 'package:critalarm/features/challenges/presentation/challenge_step.dart';
import 'package:critalarm/features/challenges/presentation/hold_to_skip_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The challenge step on a small phone at a large text size, with the
/// keyboard up: what is under the field has to stay above the way out.
void main() {
  const longTitle =
      'Replication lag above 300 seconds on the primary database in '
      'eu-west-1 after the nightly vacuum job started late';

  /// The step for [kind] as the alarm route draws it. [keyboard] is the
  /// keyboard's height in points, 0 for none. [isPicture] draws the still
  /// first frame, which needs no sensor.
  Future<void> open(
    WidgetTester tester,
    ChallengeKind kind, {
    Size size = const Size(375, 667),
    double scale = 1.3,
    double keyboard = 260,
    bool isPicture = false,
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    tester.view.padding = const FakeViewPadding(top: 40);
    tester.view.viewPadding = tester.view.padding;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 2);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: SeverityScope(
          mode: SeverityMode.ack,
          child: Builder(
            builder: (context) => Material(
              color: context.appColors.canvas,
              child: AmbientScope(
                child: ChallengeStep(
                  challenge: challengeOf(kind)!,
                  incident: const ChallengeIncident(
                    topic: 'prod-db',
                    alertTitle: longTitle,
                  ),
                  wayOut: ChallengeWayOut.hold,
                  isPicture: isPicture,
                  onPassed: () {},
                  onSkip: () {},
                  onLeave: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // The field takes focus and is brought into view over the keyboard.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  double wayOutTop(WidgetTester tester) =>
      tester.getRect(find.byType(HoldToSkipButton)).top;

  testWidgets('type the alert title: one instruction, and the line under '
      'the field is whole above the way out', (tester) async {
    await open(tester, ChallengeKind.typeAlertTitle);

    // The prompt is the instruction. Nothing under the field says it again.
    expect(find.text('Type the bold words'), findsOneWidget);
    expect(find.textContaining('bold words'), findsOneWidget);

    final note = find.text('Capitals do not matter.');
    expect(note, findsOneWidget);
    expect(
      tester.getRect(note).bottom,
      lessThanOrEqualTo(wayOutTop(tester)),
      reason: 'the line under the field is cut by the way out',
    );
    expect(
      tester.getRect(find.byType(TextField)).bottom,
      lessThan(tester.getRect(note).top),
    );
  });

  testWidgets('ops math: the field is clear of the way out, and so is the '
      'line after a wrong answer', (tester) async {
    await open(tester, ChallengeKind.opsMath);

    // A number pad needs no line that says numbers only.
    expect(find.text('Numbers only.'), findsNothing);
    expect(
      tester.getRect(find.byType(TextField)).bottom,
      lessThanOrEqualTo(wayOutTop(tester)),
      reason: 'the field runs under the way out',
    );

    // No answer is one digit long, so this is wrong once it is sent.
    await tester.enterText(find.byType(TextField), '1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    final wrong = find.text('Try the same question again.');
    expect(wrong, findsOneWidget);
    expect(
      tester.getRect(wrong).bottom,
      lessThanOrEqualTo(wayOutTop(tester)),
      reason: 'the wrong answer line is cut by the way out',
    );
  });

  testWidgets('scratch card: the prompt is the only instruction on the '
      'covered card', (tester) async {
    await open(tester, ChallengeKind.scratchCard, keyboard: 0);

    expect(find.text('Scratch, then type the code'), findsOneWidget);
    expect(find.textContaining('Rub the card'), findsNothing);
    expect(find.textContaining('Type the 4 digits'), findsNothing);
  });

  testWidgets('shake: the prompt says what to do, and one line says how a '
      'shake is counted', (tester) async {
    await open(tester, ChallengeKind.shake, keyboard: 0, isPicture: true);

    expect(find.text('30 shakes or taps'), findsOneWidget);
    expect(find.text('Out and back counts as one.'), findsOneWidget);
    expect(find.textContaining('Shake the phone'), findsNothing);
  });
}
