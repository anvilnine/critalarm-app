import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/features/paywall/domain/entities/hosted_benefit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/history_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/limits_preview_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/pushes_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/topics_preview.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The phases one loop passes through, in order, each named once per visit.
List<T> _phasesOver<T>(T Function(double t) phaseAt, {double from = 0}) {
  final seen = <T>[];
  for (var ms = 0; ms < limitsPreviewPeriod * 1000; ms += 10) {
    final phase = phaseAt(from + ms / 1000);
    if (seen.isEmpty || seen.last != phase) seen.add(phase);
  }
  return seen;
}

/// Every hundredth of a second of one loop.
Iterable<double> get _loop sync* {
  for (var ms = 0; ms <= limitsPreviewPeriod * 1000; ms += 10) {
    yield ms / 1000;
  }
}

void main() {
  const freePushes = 50;
  const hostedPushes = 1000;
  const freeDays = 7;
  const hostedDays = 90;

  PushesPreviewFrame pushes(double t) =>
      pushesPreviewFrameAt(t, free: freePushes, hosted: hostedPushes);
  HistoryPreviewFrame history(double t) =>
      historyPreviewFrameAt(t, free: freeDays, hosted: hostedDays);

  test('the three previews are registered', () {
    for (final id in [
      PaywallPreviewId.topics,
      PaywallPreviewId.pushes,
      PaywallPreviewId.history,
    ]) {
      expect(paywallPreviewBuilders[id], isNotNull, reason: id.name);
    }
  });

  test('the previews take turns: one moves at a time', () {
    for (final t in _loop) {
      final moving = [
        topicsPreviewFrameAt(t) != topicsPreviewFrameAt(limitsPreviewRestAt),
        pushes(t) != pushes(limitsPreviewRestAt),
        history(t) != history(limitsPreviewRestAt),
      ].where((isMoving) => isMoving).length;
      expect(moving, lessThanOrEqualTo(1), reason: 'at $t');
    }
  });

  test('limitsKeyframes joins its points with straight lines', () {
    const points = [(1.0, 0.0), (2.0, 10.0), (4.0, 0.0)];
    expect(limitsKeyframes(0, points), 0);
    expect(limitsKeyframes(1.5, points), 5);
    expect(limitsKeyframes(2, points), 10);
    expect(limitsKeyframes(3, points), 5);
    expect(limitsKeyframes(9, points), 0);
  });

  group('topics', () {
    test('the switch is refused before it goes on', () {
      expect(_phasesOver(topicsPreviewPhaseAt), [
        TopicsPreviewPhase.on,
        TopicsPreviewPhase.resetting,
        TopicsPreviewPhase.off,
        TopicsPreviewPhase.refusing,
        TopicsPreviewPhase.refused,
        TopicsPreviewPhase.turningOn,
        TopicsPreviewPhase.on,
      ]);
    });

    test('it rests switched on, straight, with no tap mark', () {
      final rest = topicsPreviewFrameAt(limitsPreviewRestAt);
      expect(rest.phase, TopicsPreviewPhase.on);
      expect(rest.knob, 1);
      expect(rest.track, 1);
      expect(rest.shake, 0);
      expect(rest.tapOpacity, 0);
      expect(rest.follower, 1);
      expect(rest.isOn, isTrue);
      expect(rest.isRefused, isFalse);
    });

    test('the loop ends on the frame it starts on', () {
      expect(
        topicsPreviewFrameAt(limitsPreviewPeriod - 0.001),
        topicsPreviewFrameAt(0),
      );
      expect(
        topicsPreviewFrameAt(limitsPreviewPeriod * 3),
        topicsPreviewFrameAt(0),
      );
    });

    test('the refusal shakes and never switches on', () {
      var shook = false;
      for (final t in _loop) {
        final frame = topicsPreviewFrameAt(t);
        if (frame.phase != TopicsPreviewPhase.refusing) {
          expect(frame.shake, 0, reason: 'at $t');
          continue;
        }
        shook = shook || frame.shake.abs() > 0.5;
        expect(frame.knob, lessThanOrEqualTo(0.6), reason: 'at $t');
        expect(frame.track, 0, reason: 'at $t');
      }
      expect(shook, isTrue);
      final settled = topicsPreviewFrameAt(TopicsPreviewTimes.refused);
      expect(settled.knob, 0);
      expect(settled.shake, 0);
    });

    test('each tap is marked', () {
      expect(
        topicsPreviewFrameAt(TopicsPreviewTimes.firstTap).tapOpacity,
        closeTo(1, 0.01),
      );
      expect(
        topicsPreviewFrameAt(TopicsPreviewTimes.secondTap).tapOpacity,
        closeTo(1, 0.01),
      );
    });

    test('a scene lists topics, with names once they fit', () {
      final medium = topicsPreviewLayoutFor(const Size.square(120));
      expect(medium.rows, 3);
      expect(medium.showsNames, isFalse);

      final large = topicsPreviewLayoutFor(const Size.square(200));
      expect(large.rows, 3);
      expect(large.showsNames, isTrue);
      expect(large.rows * large.rowHeight, lessThanOrEqualTo(200));

      expect(topicsPreviewLayoutFor(const Size(350, 110)).rows, 1);
      expect(topicsPreviewLayoutFor(const Size(170, 230)).rows, 4);
    });

    test('the tapped topic is the third, or the last of a shorter list', () {
      expect(topicsPreviewNames(1), ['nas-backup']);
      expect(topicsPreviewNames(2).last, 'nas-backup');
      expect(topicsPreviewNames(3).last, 'nas-backup');
      expect(topicsPreviewNames(4)[2], 'nas-backup');
      for (final size in const [
        Size(350, 110),
        Size.square(120),
        Size.square(200),
        Size(170, 230),
      ]) {
        final layout = topicsPreviewLayoutFor(size);
        expect(
          topicsPreviewNames(layout.rows)[layout.tappedRow],
          'nas-backup',
        );
      }
    });
  });

  group('pushes', () {
    test('the count stops at the free allowance before it runs on', () {
      expect(_phasesOver(pushesPreviewPhaseAt), [
        PushesPreviewPhase.full,
        PushesPreviewPhase.draining,
        PushesPreviewPhase.filling,
        PushesPreviewPhase.stalled,
        PushesPreviewPhase.running,
        PushesPreviewPhase.landing,
        PushesPreviewPhase.full,
      ]);
    });

    test('it rests on the full bar and the Hosted number', () {
      final rest = pushes(limitsPreviewRestAt);
      expect(rest.phase, PushesPreviewPhase.full);
      expect(rest.count, hostedPushes);
      expect(rest.fill, 1);
      expect(rest.stop, 0);
      expect(rest.pop, 1);
      expect(pushes(limitsPreviewPeriod - 0.001), rest);
    });

    test('the bar is to scale while stopped', () {
      final stalled = pushes(PushesPreviewTimes.stall + 0.2);
      expect(stalled.phase, PushesPreviewPhase.stalled);
      expect(stalled.count, freePushes);
      expect(stalled.fill, closeTo(freePushes / hostedPushes, 1e-9));
      expect(stalled.stop, 1);
    });

    test('the count only climbs from empty to full', () {
      var last = 0;
      for (final t in _loop) {
        final frame = pushes(t);
        if (t < PushesPreviewTimes.fill) continue;
        expect(frame.count, greaterThanOrEqualTo(last), reason: 'at $t');
        expect(frame.count, inInclusiveRange(0, hostedPushes));
        last = frame.count;
      }
      expect(last, hostedPushes);
    });

    test('it reads the allowances the app already has', () {
      expect(AccountCaps.free.p4Daily, isNotNull);
      expect(AccountCaps.free.p4Daily, lessThan(hostedP4Daily));
    });

    test('numbers get a comma every three digits', () {
      expect(pushesPreviewNumber(0), '0');
      expect(pushesPreviewNumber(50), '50');
      expect(pushesPreviewNumber(999), '999');
      expect(pushesPreviewNumber(1000), '1,000');
      expect(pushesPreviewNumber(1234567), '1,234,567');
    });

    test('every scene has the number, a large one the scale too', () {
      final medium = pushesPreviewLayoutFor(
        const Size.square(120),
        numberAspect: 2.4,
      );
      expect(medium.numberSize, greaterThan(0));
      expect(medium.showsScale, isFalse);

      for (final size in const [
        Size.square(200),
        Size(350, 110),
        Size(350, 300),
      ]) {
        final layout = pushesPreviewLayoutFor(size, numberAspect: 2.4);
        expect(layout.showsScale, isTrue, reason: '$size');
        // The number fits the width, and everything fits the height.
        expect(
          layout.numberSize * 2.4,
          lessThanOrEqualTo(size.width - 2 * layout.padding + 1e-9),
        );
        final stack =
            layout.numberSize +
            layout.gap +
            layout.barHeight +
            layout.gap * 0.6 +
            layout.scaleSize * 1.3;
        expect(stack, lessThan(size.height - 2 * layout.padding));
      }
    });
  });

  group('history', () {
    test('the list stops at the line before it opens', () {
      expect(_phasesOver(historyPreviewPhaseAt), [
        HistoryPreviewPhase.rest,
        HistoryPreviewPhase.rewinding,
        HistoryPreviewPhase.top,
        HistoryPreviewPhase.scrolling,
        HistoryPreviewPhase.stopped,
        HistoryPreviewPhase.lifting,
        HistoryPreviewPhase.rest,
      ]);
    });

    test('it rests past the line, open, with the Hosted window', () {
      final rest = history(limitsPreviewRestAt);
      expect(rest.phase, HistoryPreviewPhase.rest);
      expect(rest.toLine, 1);
      expect(rest.pastLine, 1);
      expect(rest.tug, 0);
      expect(rest.lift, 1);
      expect(rest.window, hostedDays);
      expect(history(limitsPreviewPeriod - 0.001), rest);
    });

    test('stopped, the line is shut and the window is the free one', () {
      final stopped = history(HistoryPreviewTimes.stop + 0.14);
      expect(stopped.phase, HistoryPreviewPhase.stopped);
      expect(stopped.toLine, 1);
      expect(stopped.pastLine, 0);
      expect(stopped.lift, 0);
      expect(stopped.window, freeDays);
      expect(stopped.tug, closeTo(1, 1e-9));
      expect(history(HistoryPreviewTimes.lift - 0.01).tug, 0);
    });

    test('the rows under the line fill in nearest first, all by the end', () {
      expect(historyPreviewReveal(0, 0), 0);
      expect(
        historyPreviewReveal(0, 0.3),
        greaterThan(historyPreviewReveal(1, 0.3)),
      );
      expect(
        historyPreviewReveal(1, 0.5),
        greaterThan(historyPreviewReveal(3, 0.5)),
      );
      for (var i = 0; i < 9; i++) {
        expect(historyPreviewReveal(i, 1), 1);
      }
    });

    test('ages sit on their own side of the line', () {
      final inside = historyPreviewAgesInside(freeDays);
      final beyond = historyPreviewAgesBeyond(freeDays, hostedDays);
      expect(inside, [0, 1, 2, 3, 4, 5, 6]);
      expect(beyond.every((age) => age > freeDays), isTrue);
      expect(beyond.last, hostedDays);
      expect([...beyond]..sort(), beyond);
      expect(beyond.toSet().length, beyond.length);

      expect(historyPreviewAgesInside(30).length, 7);
      expect(historyPreviewAgesInside(30).last, 29);
      expect(historyPreviewAgesInside(0), isEmpty);
      expect(historyPreviewAgesBeyond(7, 7), isEmpty);
      expect(historyPreviewAgesBeyond(7, 9), [8, 9]);
    });

    test('it reads the windows the app already has', () {
      expect(AccountCaps.free.historyDays, isNotNull);
      expect(AccountCaps.free.historyDays, lessThan(hostedHistoryDays));
    });

    test('at rest there are rows on both sides of the line', () {
      for (final size in const [
        Size.square(120),
        Size.square(200),
        Size(350, 110),
        Size(350, 300),
      ]) {
        final layout = historyPreviewLayoutFor(size);
        const inside = 7;
        final scroll = layout.scrollFor(history(limitsPreviewRestAt), inside);
        final lineTop = layout.lineTop(inside) - scroll;
        final lineBottom = lineTop + layout.lineSlot;
        expect(
          lineTop,
          greaterThanOrEqualTo(layout.rowHeight * 0.9),
          reason: '$size',
        );
        expect(
          size.height - lineBottom,
          greaterThanOrEqualTo(layout.rowHeight * 0.9),
          reason: '$size',
        );
        // The list really moves: top, the line, then past it.
        final stopped = layout.scrollFor(
          history(HistoryPreviewTimes.lift - 0.01),
          inside,
        );
        expect(stopped, greaterThan(0), reason: '$size');
        expect(scroll, greaterThan(stopped), reason: '$size');
      }
    });

    test('a medium scene draws bars, a large one names and ages', () {
      final medium = historyPreviewLayoutFor(const Size.square(120));
      expect(medium.showsTags, isTrue);
      expect(medium.showsText, isFalse);

      final large = historyPreviewLayoutFor(const Size.square(200));
      expect(large.showsText, isTrue);
      expect(large.showsTags, isTrue);
    });
  });
}
