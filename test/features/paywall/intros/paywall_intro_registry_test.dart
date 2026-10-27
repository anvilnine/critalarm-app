import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tile.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _nothing(BuildContext context, PaywallIntroScope scope) =>
    const SizedBox.shrink();

void main() {
  group('the registry', () {
    test('no intro has no line and always counts as built', () {
      expect(paywallIntroBuilders.containsKey(PaywallIntroId.none), isFalse);
      expect(paywallIntroIsBuilt(PaywallIntroId.none), isTrue);
    });

    test('every intro but none is registered', () {
      for (final intro in PaywallIntroId.values) {
        expect(paywallIntroIsBuilt(intro), isTrue, reason: intro.key);
      }
      expect(paywallIntroBuilders, hasLength(PaywallIntroId.values.length - 1));
    });

    test('every intro leaves on the mascot and says when it is heard', () {
      for (final MapEntry(key: id, value: intro)
          in paywallIntroBuilders.entries) {
        expect(intro.tag, isNotNull, reason: id.key);
        expect(intro.beats, isNotEmpty, reason: id.key);
        // Few enough that none is a run: nothing here rings or buzzes.
        expect(intro.beats.length, lessThanOrEqualTo(4), reason: id.key);
        for (final beat in intro.beats) {
          expect(beat.at, inInclusiveRange(0, intro.handover), reason: id.key);
        }
      }
    });

    test('every intro is short, and hands over before it ends', () {
      for (final MapEntry(key: id, value: intro)
          in paywallIntroBuilders.entries) {
        expect(intro.isSound, isTrue, reason: id.key);
        expect(intro.seconds, inInclusiveRange(1, 3), reason: id.key);
        expect(intro.skipTo, lessThanOrEqualTo(intro.handover), reason: id.key);
        expect(intro.handover, lessThan(intro.seconds), reason: id.key);
      }
    });
  });

  group('the names in the picker', () {
    test('every intro and every layout has a name of its own', () {
      final intros = {
        for (final intro in PaywallIntroId.values) paywallIntroNameKey(intro),
      };
      final layouts = {
        for (final layout in PaywallLayoutId.values)
          paywallLayoutNameKey(layout),
      };
      expect(intros, hasLength(PaywallIntroId.values.length));
      expect(layouts, hasLength(PaywallLayoutId.values.length));
    });
  });

  group('beats', () {
    const intro = PaywallIntro(
      seconds: 2,
      handover: 1.6,
      skipTo: 1.2,
      beats: [
        PaywallIntroBeat(0, PaywallCue.tick),
        PaywallIntroBeat(0.5, PaywallCue.tick),
        PaywallIntroBeat(1.2, PaywallCue.pop),
      ],
      builder: _nothing,
    );

    test('a beat plays once, as the clock passes it', () {
      expect(paywallIntroBeatsBetween(intro, -1, 0), hasLength(1));
      expect(paywallIntroBeatsBetween(intro, 0, 0.49), isEmpty);
      expect(paywallIntroBeatsBetween(intro, 0.49, 0.5), hasLength(1));
      expect(paywallIntroBeatsBetween(intro, 0.5, 0.6), isEmpty);
      expect(paywallIntroBeatsBetween(intro, 0.6, 3), hasLength(1));
    });

    test('a tap plays only the beat it lands on', () {
      final to = paywallIntroSkip(intro, 0.2);
      final played = paywallIntroBeatsBetween(intro, to - 1e-6, to);
      expect(played.single.at, 1.2);
    });

    test('beats out of order, or after the end, are not sound', () {
      const backwards = PaywallIntro(
        seconds: 2,
        handover: 1.6,
        beats: [
          PaywallIntroBeat(1, PaywallCue.tick),
          PaywallIntroBeat(0.5, PaywallCue.tick),
        ],
        builder: _nothing,
      );
      const late = PaywallIntro(
        seconds: 2,
        handover: 1.6,
        beats: [PaywallIntroBeat(2.5, PaywallCue.tick)],
        builder: _nothing,
      );
      expect(intro.isSound, isTrue);
      expect(backwards.isSound, isFalse);
      expect(late.isSound, isFalse);
    });
  });

  group('the hand over', () {
    const from = Rect.fromLTWH(100, 200, 200, 200);
    const landing = Rect.fromLTWH(20, 80, 120, 120);

    test('the mascot starts where the intro had it', () {
      expect(
        paywallIntroLeaveBox(from: from, landing: landing, leave: 0),
        from,
      );
    });

    test('it ends as nothing at the foot of the layout mascot', () {
      final end = paywallIntroLeaveBox(from: from, landing: landing, leave: 1);
      expect(end.width, 0);
      expect(end.height, 0);
      expect(end.center, landing.bottomCenter);
    });

    test('it only gets smaller on the way', () {
      var last = from.width;
      for (var leave = 0.1; leave <= 1.0001; leave += 0.1) {
        final width = paywallIntroLeaveBox(
          from: from,
          landing: landing,
          leave: leave,
        ).width;
        expect(width, lessThanOrEqualTo(last));
        last = width;
      }
    });

    test('with no mascot in the layout it goes down to its own foot', () {
      final end = paywallIntroLeaveBox(from: from, landing: null, leave: 1);
      expect(end.center, from.bottomCenter);
      expect(end.width, 0);
    });

    test('the tag comes after the hand over and goes by itself', () {
      expect(paywallIntroTagPresence(0), 0);
      expect(paywallIntroTagPresence(0.05), 0);
      expect(paywallIntroTagPresence(1), 1);
      expect(
        paywallIntroTagPresence(paywallIntroTagSeconds - 0.1),
        lessThan(1),
      );
      expect(paywallIntroTagPresence(paywallIntroTagSeconds), 0);
      expect(paywallIntroTagPresence(paywallIntroTagSeconds + 5), 0);
    });
  });

  group('the contract', () {
    test('a tap skips to the way out and does nothing after it', () {
      const intro = PaywallIntro(
        seconds: 2,
        handover: 1.6,
        skipTo: 1.2,
        builder: _nothing,
      );
      expect(paywallIntroSkip(intro, 0), 1.2);
      expect(paywallIntroSkip(intro, 1.19), 1.2);
      expect(paywallIntroSkip(intro, 1.2), 1.2);
      expect(paywallIntroSkip(intro, 1.7), 1.7);
    });

    test('with no skip second a tap goes to the hand over', () {
      const intro = PaywallIntro(seconds: 2, handover: 1.6, builder: _nothing);
      expect(intro.skipTo, 1.6);
      expect(intro.isSound, isTrue);
    });

    test('times out of order, or too long, are not sound', () {
      const late = PaywallIntro(
        seconds: 2,
        handover: 1.2,
        skipTo: 1.5,
        builder: _nothing,
      );
      const noWayOut = PaywallIntro(
        seconds: 1.5,
        handover: 1.5,
        builder: _nothing,
      );
      const long = PaywallIntro(seconds: 4, handover: 3, builder: _nothing);
      expect(late.isSound, isFalse);
      expect(noWayOut.isSound, isFalse);
      expect(long.isSound, isFalse);
    });
  });
}
