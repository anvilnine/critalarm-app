import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/challenges/presentation/challenge.dart';
import 'package:critalarm/features/challenges/presentation/challenge_step.dart';
import 'package:critalarm/features/challenges/presentation/challenge_try.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style_scope.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_styles.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/standard_alarm_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The try of a challenge is drawn in the look the alarm would be, through
/// the same stage the alarm route uses.
void main() {
  Future<void> open(WidgetTester tester, {AlarmStyle? style}) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: ChallengeTryPage(
          challenge: challengeOf(ChallengeKind.typeTopicName)!,
          style: style,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  BuildContext stepContext(WidgetTester tester) =>
      tester.element(find.byType(ChallengeStep));

  testWidgets('a try takes the look it is given, colours and all', (
    tester,
  ) async {
    final terminal = alarmStyleOf(AlarmStyleId.terminal);
    expect(terminal, isNot(same(standardAlarmStyle)));
    await open(tester, style: terminal);

    final context = stepContext(tester);
    expect(AlarmStyleScope.of(context), same(terminal));
    final expected = terminal.colorsFor(
      AlarmStage.acknowledged,
      base: buildLightTheme().extension<AppColors>()!,
      severity: SeverityMode.ack,
      brightness: Brightness.light,
    );
    expect(context.appColors.canvas, expected.canvas);
    expect(context.appColors.onCanvas, expected.onCanvas);
  });

  testWidgets('with no look to be had it draws the standard one', (
    tester,
  ) async {
    // Nothing is registered, so the saved look cannot be asked for.
    await getIt.reset();
    await open(tester);

    expect(tester.takeException(), isNull);
    expect(AlarmStyleScope.of(stepContext(tester)), same(standardAlarmStyle));
  });
}
