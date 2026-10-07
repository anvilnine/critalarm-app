import 'package:critalarm/features/paywall/domain/entities/paywall_preview_id.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_arrangement.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const own = HeroScript(
    seconds: 2,
    beats: [
      HeroBeat(0, HeroFace.keen),
      HeroBeat(1, HeroFace.proud, isReaction: true),
    ],
    props: {HeroProp.crown: 0.5},
  );

  group('a table of turns a layout wrote', () {
    final loop = HeroLoop.turns(const [
      HeroTurn(own),
      HeroTurn(own, preview: PaywallPreviewId.widgets),
    ]);

    test('plays in order and wraps', () {
      expect(loop.period, 4);
      expect(loop.scenes[0].preview, isNull);
      expect(loop.frameAt(heroEntranceSeconds + 0.5).activeIndex, 0);
      expect(loop.frameAt(heroEntranceSeconds + 2.5).activeIndex, 1);
      expect(loop.frameAt(heroEntranceSeconds + 4.5).activeIndex, 0);
    });

    test('follows its own faces and props', () {
      final frame = loop.frameAt(heroEntranceSeconds + 1.5);
      expect(frame.face, HeroFace.proud);
      expect(frame.props[HeroProp.crown], 1);
    });

    test('answers the hand like the approved loop', () {
      const t = heroEntranceSeconds + 0.5;
      final hand = loop.touch(t, step: 1)!;
      expect(hand.index, 1);
      expect(loop.resumesAt(hand), t + 2 + heroHandHoldSeconds);
      expect(loop.frameAt(t + 3, hand: hand).isHeld, isTrue);
    });
  });

  test('a script a layout wrote replaces the approved one', () {
    final loop = HeroLoop(
      const [PaywallPreviewId.topics, PaywallPreviewId.pushes],
      scripts: const {PaywallPreviewId.topics: own},
    );
    expect(loop.scenes[0].script, same(own));
    expect(
      loop.scenes[1].script,
      same(heroDefaultScripts[PaywallPreviewId.pushes]),
    );
  });

  group('a beat a layout plays before the entrance', () {
    final plain = HeroLoop(const [PaywallPreviewId.topics]);
    final late = HeroLoop(const [PaywallPreviewId.topics], prelude: 2);

    test('the stage draws nothing until the beat ends', () {
      expect(late.entranceEnd, 2 + heroEntranceSeconds);
      expect(late.frameAt(1.9).entrance, 0);
      expect(late.frameAt(2.5).entrance, 0.5);
    });

    test('everything after it is the same loop, that much later', () {
      final a = plain.frameAt(heroEntranceSeconds + 1.2);
      final b = late.frameAt(2 + heroEntranceSeconds + 1.2);
      expect(b.face, a.face);
      expect(b.sceneSeconds, closeTo(a.sceneSeconds, 1e-9));
      expect(b.playFrom, closeTo(a.playFrom + 2, 1e-9));
    });

    test('a touch during it waits for the entrance to end', () {
      expect(late.touch(0.4, index: 0)!.since, late.entranceEnd);
      expect(
        const HeroWait().down(0.4, entranceEnd: late.entranceEnd).downAt,
        late.entranceEnd,
      );
    });
  });

  group('the height a stage gets', () {
    test('what the words leave, in whole points', () {
      final room = heroStageRoomFor(
        height: 500,
        words: 180.5,
        gap: 12,
        bottomGap: 20,
      );
      expect(room.stage, 287);
      expect(room.gap, 12);
      expect(room.stage + room.gap + 180.5 + room.under, 500);
    });

    test('past its largest, most of the spare height is air', () {
      final room = heroStageRoomFor(
        height: 700,
        words: 200,
        gap: 12,
        bottomGap: 20,
      );
      // 468 left, 88 spare.
      expect(room.stage, (heroStageMax + 88 * 0.4).floorToDouble());
      expect(room.gap, closeTo(12 + 88 * 0.3, 1e-9));
    });

    test('no room is a stage of zero', () {
      final room = heroStageRoomFor(
        height: 300,
        words: 400,
        gap: 12,
        bottomGap: 20,
      );
      expect(room.stage, 0);
      expect(room.under, 0);
    });
  });
}
