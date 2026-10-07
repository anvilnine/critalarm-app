import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_preview_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/history_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/limits_preview_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/pushes_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/topics_preview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('paywallPreviewSecond', () {
    test('a still preview rests on its own second, whatever the clock', () {
      for (final clock in [0.0, 1.6, 40.0]) {
        expect(
          paywallPreviewSecond(clock: clock, isStill: true, restAt: 9),
          9,
        );
        expect(
          paywallPreviewSecond(
            clock: clock,
            isStill: true,
            restAt: 9,
            playFrom: 2,
            turnStart: 3,
          ),
          9,
        );
      }
    });

    test('with no playFrom it follows the clock as it is', () {
      expect(paywallPreviewSecond(clock: 0, isStill: false, restAt: 9), 0);
      expect(paywallPreviewSecond(clock: 4.5, isStill: false, restAt: 9), 4.5);
      // A turn in a shared loop changes nothing until a layout asks.
      expect(
        paywallPreviewSecond(
          clock: 4.5,
          isStill: false,
          restAt: 9,
          turnStart: 3,
        ),
        4.5,
      );
    });

    test('with playFrom its loop starts at zero on that second', () {
      double at(double clock) => paywallPreviewSecond(
        clock: clock,
        isStill: false,
        restAt: 9,
        playFrom: 6,
      );

      expect(at(6), 0);
      expect(at(7.25), 1.25);
      // Before its scene it holds the first frame of its loop.
      expect(at(0), 0);
      expect(at(5.99), 0);
    });

    test('a preview with a turn plays that turn at once', () {
      double at(double clock) => paywallPreviewSecond(
        clock: clock,
        isStill: false,
        restAt: 0,
        playFrom: 6,
        turnStart: 3.2,
      );

      expect(at(2), 3.2);
      expect(at(6), 3.2);
      expect(at(7), closeTo(4.2, 1e-9));
    });
  });

  group('the limit previews, told when to play', () {
    const free = 3;
    const hosted = 90;

    test('each holds its resting picture until its scene', () {
      final topics = topicsPreviewFrameAt(TopicsPreviewTimes.reset);
      final topicsRest = topicsPreviewFrameAt(limitsPreviewRestAt);
      expect(topics.knob, topicsRest.knob);
      expect(topics.track, topicsRest.track);
      expect(topics.follower, topicsRest.follower);

      final pushes = pushesPreviewFrameAt(
        PushesPreviewTimes.drain,
        free: free,
        hosted: hosted,
      );
      final pushesRest = pushesPreviewFrameAt(
        limitsPreviewRestAt,
        free: free,
        hosted: hosted,
      );
      expect(pushes.count, pushesRest.count);
      expect(pushes.fill, pushesRest.fill);

      final history = historyPreviewFrameAt(
        HistoryPreviewTimes.rewind,
        free: free,
        hosted: hosted,
      );
      final historyRest = historyPreviewFrameAt(
        limitsPreviewRestAt,
        free: free,
        hosted: hosted,
      );
      expect(history.toLine, historyRest.toLine);
      expect(history.pastLine, historyRest.pastLine);
      expect(history.lift, historyRest.lift);
    });

    test('each moves within a tenth of a second of its scene', () {
      double second(double turnStart) => paywallPreviewSecond(
        clock: 10.1,
        isStill: false,
        restAt: limitsPreviewRestAt,
        playFrom: 10,
        turnStart: turnStart,
      );

      expect(
        topicsPreviewFrameAt(second(TopicsPreviewTimes.reset)),
        isNot(topicsPreviewFrameAt(limitsPreviewRestAt)),
      );
      expect(
        pushesPreviewFrameAt(
          second(PushesPreviewTimes.drain),
          free: free,
          hosted: hosted,
        ),
        isNot(
          pushesPreviewFrameAt(limitsPreviewRestAt, free: free, hosted: hosted),
        ),
      );
      expect(
        historyPreviewFrameAt(
          second(HistoryPreviewTimes.rewind),
          free: free,
          hosted: hosted,
        ),
        isNot(
          historyPreviewFrameAt(
            limitsPreviewRestAt,
            free: free,
            hosted: hosted,
          ),
        ),
      );
    });
  });
}
