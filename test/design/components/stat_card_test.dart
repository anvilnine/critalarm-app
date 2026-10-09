import 'package:critalarm/design/components/stat_card.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter_test/flutter_test.dart';

AppStatDay _day({
  int alarms = 0,
  bool isToday = false,
  bool hasUnanswered = false,
  bool isHidden = false,
}) => AppStatDay(
  letter: 'M',
  alarms: alarms,
  semanticsLabel: 'Monday',
  isToday: isToday,
  hasUnanswered: hasUnanswered,
  isHidden: isHidden,
);

void main() {
  group('statBarKind', () {
    test('a day with nothing is a quiet stub', () {
      expect(statBarKind(_day()), AppStatBarKind.quiet);
    });

    test('a day with answered alarms is busy', () {
      expect(statBarKind(_day(alarms: 2)), AppStatBarKind.busy);
    });

    test('a day the plan does not reach has no bar', () {
      expect(statBarKind(_day(isHidden: true)), AppStatBarKind.hidden);
      expect(
        statBarKind(_day(alarms: 2, isToday: true, isHidden: true)),
        AppStatBarKind.hidden,
      );
    });

    test('today is yellow', () {
      expect(statBarKind(_day(isToday: true)), AppStatBarKind.today);
      expect(statBarKind(_day(alarms: 3, isToday: true)), AppStatBarKind.today);
    });

    test('an unanswered alarm is red, even today', () {
      expect(
        statBarKind(_day(alarms: 1, hasUnanswered: true)),
        AppStatBarKind.unanswered,
      );
      expect(
        statBarKind(_day(alarms: 1, isToday: true, hasUnanswered: true)),
        AppStatBarKind.unanswered,
      );
    });
  });

  group('statBarHeight', () {
    test('a stub for none, then 36, 62 and 88', () {
      expect(statBarHeight(0), 8);
      expect(statBarHeight(1), 36);
      expect(statBarHeight(2), 62);
      expect(statBarHeight(3), 88);
    });

    test('never taller than the maximum', () {
      expect(statBarHeight(9), kStatBarMaxHeight);
      expect(statBarHeight(500), kStatBarMaxHeight);
    });

    test('a negative count is a stub', () {
      expect(statBarHeight(-1), 8);
    });
  });

  group('statBarColor', () {
    test('today is yellow and unanswered is red', () {
      const colors = AppColors.light;
      expect(statBarColor(AppStatBarKind.today, colors), colors.yellow);
      expect(statBarColor(AppStatBarKind.unanswered, colors), colors.crit);
    });

    test('a hidden day draws nothing', () {
      const colors = AppColors.light;
      expect(statBarColor(AppStatBarKind.hidden, colors).a, 0);
    });

    test('a quiet stub is fainter than a busy bar', () {
      const colors = AppColors.light;
      expect(
        statBarColor(AppStatBarKind.quiet, colors).a,
        lessThan(statBarColor(AppStatBarKind.busy, colors).a),
      );
    });
  });
}
