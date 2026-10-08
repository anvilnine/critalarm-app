import 'package:critalarm/design/components/readiness_pips.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pipTones', () {
    test('lists fine first, then look, broken and open', () {
      expect(pipTones(fine: 2, look: 1, broken: 1, open: 1), [
        AppPipTone.fine,
        AppPipTone.fine,
        AppPipTone.look,
        AppPipTone.broken,
        AppPipTone.open,
      ]);
    });

    test('draws nothing for no checks', () {
      expect(pipTones(fine: 0), isEmpty);
    });
  });

  group('AppPipTone.color', () {
    for (final colors in [AppColors.light, AppColors.dark]) {
      test('each tone has its own colour', () {
        final all = AppPipTone.values.map((t) => t.color(colors)).toSet();
        expect(all.length, AppPipTone.values.length);
      });
    }

    test('fine is yellow, look is orange and broken is red', () {
      const colors = AppColors.light;
      expect(AppPipTone.fine.color(colors), colors.yellow);
      expect(AppPipTone.look.color(colors), colors.high);
      expect(AppPipTone.broken.color(colors), colors.crit);
    });

    test('open is see-through, so the card shows through', () {
      expect(AppPipTone.open.color(AppColors.light).a, lessThan(0.5));
    });
  });

  group('pipLayout', () {
    test('keeps the full gap while there is room', () {
      final layout = pipLayout(260, 9);
      expect(layout.gap, kPipGap);
      expect(layout.pip, greaterThanOrEqualTo(kPipMinWidth));
    });

    test('nine pips stay 10 points wide on a 140 point card', () {
      final layout = pipLayout(140, 9);
      expect(layout.pip, greaterThanOrEqualTo(kPipMinWidth));
      expect(layout.pip * 9 + layout.gap * 8, closeTo(140, 0.001));
    });

    test('shrinks the gap before the pips', () {
      final tight = pipLayout(120, 9);
      expect(tight.gap, lessThan(kPipGap));
    });

    test('one pip takes the whole width', () {
      expect(pipLayout(80, 1), (pip: 80.0, gap: 0.0));
    });

    test('no pips is nothing', () {
      expect(pipLayout(80, 0), (pip: 0.0, gap: 0.0));
    });
  });
}
