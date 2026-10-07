import 'package:critalarm/core/app_icon/app_icon.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/app_icons_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/extras_preview_stage.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/weekly_check_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/widgets_preview.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every hundredth of a second across [loop], twice round.
Iterable<double> _seconds(double loop) sync* {
  for (var i = 0; i <= loop * 200; i++) {
    yield i / 100;
  }
}

/// [values] with repeats next to each other folded into one.
List<T> _runs<T>(Iterable<T> values) {
  final out = <T>[];
  for (final value in values) {
    if (out.isEmpty || out.last != value) out.add(value);
  }
  return out;
}

void main() {
  group('press and tap', () {
    test('a press is at rest before and after, and fully down in between', () {
      expect(pressAt(0.9, 1), 0);
      expect(pressAt(1.03, 1), 1);
      expect(pressAt(1.4, 1), 0);
    });

    test('the finger shows only around its tap, and is whole as it lands', () {
      expect(tapAt(0.7, 1).opacity, 0);
      expect(tapAt(1, 1), (size: 1.0, opacity: 1.0));
      expect(tapAt(1.3, 1).opacity, 0);
    });
  });

  group('widgets preview', () {
    test('plays ringing, awake, quiet, in that order, and loops', () {
      final states = _runs(
        _seconds(widgetsPreviewLoop).map((t) => widgetsPreviewFrameAt(t).state),
      );
      expect(states, [
        WidgetsPreviewState.ringing,
        WidgetsPreviewState.awake,
        WidgetsPreviewState.quiet,
        WidgetsPreviewState.ringing,
        WidgetsPreviewState.awake,
        WidgetsPreviewState.quiet,
        WidgetsPreviewState.ringing,
      ]);
    });

    test('rests on the ringing widget, whole and upright', () {
      final rest = widgetsPreviewFrameAt(widgetsPreviewRestAt);
      expect(rest.state, WidgetsPreviewState.ringing);
      expect(rest.enter, 1);
      expect(rest.tilt, 0);
      expect(rest.pulse, 0);
      expect(rest.press, 0);
      expect(rest.tap.opacity, 0);
    });

    test('the button is pressed just before each change of state', () {
      for (final (i, at) in widgetsPreviewTaps.indexed) {
        final next = widgetsPreviewPhases[i + 1];
        expect(widgetsPreviewFrameAt(at).state, widgetsPreviewPhases[i].$1);
        expect(widgetsPreviewFrameAt(at).tap.opacity, 1);
        expect(widgetsPreviewFrameAt(at + 0.03).press, 1);
        expect(next.$2, closeTo(at + 0.1, 1e-9));
      }
    });

    test('the shake stays within three degrees and only while ringing', () {
      var widest = 0.0;
      for (final t in _seconds(widgetsPreviewLoop)) {
        final frame = widgetsPreviewFrameAt(t);
        expect(frame.tilt.abs(), lessThanOrEqualTo(widgetsPreviewShake));
        if (frame.state != WidgetsPreviewState.ringing) {
          expect(frame.tilt, 0, reason: 'tilted at $t');
          expect(frame.pulse, 0, reason: 'pulsing at $t');
        }
        if (frame.tilt.abs() > widest) widest = frame.tilt.abs();
      }
      expect(widest, greaterThan(widgetsPreviewShake * 0.9));
    });

    test('the face is upright when the finger lands and the ring ends', () {
      expect(widgetsPreviewFrameAt(widgetsPreviewTaps.first).tilt, 0);
      expect(widgetsPreviewFrameAt(2.59).tilt, 0);
      expect(widgetsPreviewFrameAt(0).tilt, 0);
    });

    test('the running time counts while it rings, then holds', () {
      expect(widgetsPreviewFrameAt(0.5).seconds, 42);
      expect(widgetsPreviewFrameAt(1.5).seconds, 43);
      expect(widgetsPreviewFrameAt(2.4).seconds, 44);
      expect(widgetsPreviewFrameAt(4).seconds, 44);
    });
  });

  group('app icons preview', () {
    test('wears every icon the app ships, in order, standard first', () {
      final icons = _runs(
        _seconds(
          appIconsPreviewLoop,
        ).map((t) => appIconsPreviewFrameAt(t).icon),
      );
      expect(icons, [...AppIcon.values, ...AppIcon.values, AppIcon.standard]);
    });

    test('rests on an extra icon, with nothing squeezed or on its way', () {
      final rest = appIconsPreviewFrameAt(appIconsPreviewRestAt);
      expect(rest.icon.isPro, isTrue);
      expect(rest.icon, AppIcon.shadesCrown);
      expect(rest.press, 0);
      expect(rest.slot, AppIcon.values.indexOf(rest.icon));
    });

    test('the tile is squeezed at each swap and at rest between them', () {
      final step = appIconsPreviewStep;
      for (var i = 0; i < AppIcon.values.length; i++) {
        expect(appIconsPreviewFrameAt(i * step + 0.03).press, closeTo(1, 0.01));
        expect(appIconsPreviewFrameAt(i * step + step / 2).press, 0);
      }
    });

    test('the pick mark ends on the icon in use', () {
      final step = appIconsPreviewStep;
      for (final (i, icon) in AppIcon.values.indexed) {
        final frame = appIconsPreviewFrameAt(i * step + step / 2);
        expect(frame.icon, icon);
        expect(frame.slot, i);
      }
    });
  });

  group('weekly check preview', () {
    test('plays its steps in order and loops', () {
      final steps = _runs(
        _seconds(
          weeklyCheckPreviewLoop,
        ).map((t) => weeklyCheckPreviewFrameAt(t).phase),
      );
      expect(steps, [
        ...WeeklyCheckPreviewPhase.values,
        ...WeeklyCheckPreviewPhase.values,
        WeeklyCheckPreviewPhase.clearing,
      ]);
      expect(
        weeklyCheckPreviewPhases.map((entry) => entry.$1),
        WeeklyCheckPreviewPhase.values,
      );
    });

    test('rests on the full strip with its tick, and no push in the air', () {
      final rest = weeklyCheckPreviewFrameAt(weeklyCheckPreviewRestAt);
      expect(rest.phase, WeeklyCheckPreviewPhase.hold);
      expect(rest.weeks, List<double>.filled(weeklyCheckPreviewWeeks, 1));
      expect(rest.tickFill, 1);
      expect(rest.tickDraw, 1);
      expect(rest.pushOpacity, 0);
      expect(rest.opacity, 1);
    });

    test('the weeks pass oldest first, and this week last', () {
      for (final t in _seconds(weeklyCheckPreviewLoop)) {
        final frame = weeklyCheckPreviewFrameAt(t);
        if (frame.phase == WeeklyCheckPreviewPhase.clearing) continue;
        for (var week = 1; week < weeklyCheckPreviewWeeks; week++) {
          expect(
            frame.weeks[week],
            lessThanOrEqualTo(frame.weeks[week - 1]),
            reason: 'week $week ahead of week ${week - 1} at $t',
          );
        }
      }
    });

    test('the tick waits for the push to land', () {
      final lands = weeklyCheckPreviewStart(WeeklyCheckPreviewPhase.tick);
      for (final t in _seconds(weeklyCheckPreviewLoop / 2)) {
        final frame = weeklyCheckPreviewFrameAt(t);
        if (frame.phase == WeeklyCheckPreviewPhase.clearing) continue;
        if (t < lands) {
          expect(frame.tickFill, 0, reason: 'ticked early at $t');
        }
        if (frame.pushOpacity > 0) expect(frame.tickDraw, 0);
      }
      expect(weeklyCheckPreviewFrameAt(lands - 0.2).pushOpacity, 1);
      expect(weeklyCheckPreviewFrameAt(lands).push, 1);
    });

    test('the strip is four weeks, never the seven days of one', () {
      expect(weeklyCheckPreviewWeeks, 4);
      expect(weeklyCheckPreviewFrameAt(0).weeks, hasLength(4));
    });

    test('only this week is checked: the earlier ones pass before it', () {
      final leaves = weeklyCheckPreviewStart(
        WeeklyCheckPreviewPhase.pushTravels,
      );
      final frame = weeklyCheckPreviewFrameAt(leaves);
      expect(frame.weeks.take(weeklyCheckPreviewWeeks - 1), [1, 1, 1]);
      expect(frame.tickFill, 0);
    });
  });
}
