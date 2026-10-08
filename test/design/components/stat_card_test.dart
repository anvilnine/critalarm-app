import 'package:critalarm/design/components/stat_card.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter_test/flutter_test.dart';

AppStatDay _day({
  int alarms = 0,
  bool isToday = false,
  bool hasUnanswered = false,
}) => AppStatDay(
  letter: 'M',
  alarms: alarms,
  semanticsLabel: 'Monday',
  isToday: isToday,
  hasUnanswered: hasUnanswered,
);

void main() {
  group('statBarKind', () {
    test('a day with nothing is a quiet stub', () {
      expect(statBarKind(_day()), AppStatBarKind.quiet);
    });

    test('a day with answered alarms is busy', () {
      expect(statBarKind(_day(alarms: 2)), AppStatBarKind.busy);
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
    test('a stub for none, then 28, 40 and 52', () {
      expect(statBarHeight(0), 8);
      expect(statBarHeight(1), 28);
      expect(statBarHeight(2), 40);
      expect(statBarHeight(3), 52);
    });

    test('never taller than 52', () {
      expect(statBarHeight(9), 52);
      expect(statBarHeight(500), 52);
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

    test('a quiet stub is fainter than a busy bar', () {
      const colors = AppColors.light;
      expect(
        statBarColor(AppStatBarKind.quiet, colors).a,
        lessThan(statBarColor(AppStatBarKind.busy, colors).a),
      );
    });
  });
}
