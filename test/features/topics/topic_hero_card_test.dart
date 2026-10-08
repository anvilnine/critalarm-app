import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/features/topics/domain/topic_hero_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TopicHeroCard card({
    bool critical = false,
    bool canEdit = true,
    RingClaim claim = RingClaim.alarm,
    bool isLoading = false,
  }) => topicHeroCardFor(
    critical: critical,
    canEditCritical: canEdit,
    claim: claim,
    isLoading: isLoading,
  );

  group('Critical delivery card', () {
    test('a topic that was not switched on reads Off with a plain push', () {
      final off = card();
      expect(off.isOn, isFalse);
      expect(off.foot, TopicHeroFoot.normalPush);
      expect(off.canSwitch, isTrue);
      expect(off.hasQuietDisc, isTrue);
    });

    test('on rings through silent where the phone can', () {
      final on = card(critical: true);
      expect(on.isOn, isTrue);
      expect(on.foot, TopicHeroFoot.ringsThroughSilent);
      expect(on.hasQuietDisc, isFalse);
    });

    test('on an iPhone before iOS 26 the foot never claims silent mode', () {
      final on = card(critical: true, claim: RingClaim.timeSensitive);
      expect(on.foot, TopicHeroFoot.timeSensitive);
      expect(on.foot, isNot(TopicHeroFoot.ringsThroughSilent));
    });

    test('without alarm access the switch is still and the foot says why', () {
      final off = card(canEdit: false);
      expect(off.canSwitch, isFalse);
      expect(off.foot, TopicHeroFoot.needsAlarm);
      final on = card(critical: true, canEdit: false);
      expect(on.canSwitch, isFalse);
      expect(on.foot, TopicHeroFoot.needsAlarm);
    });

    test('while loading there is no foot and the switch is still', () {
      final loading = card(isLoading: true, critical: true);
      expect(loading.isLoading, isTrue);
      expect(loading.canSwitch, isFalse);
      expect(loading.foot, isNull);
      expect(loading.isOn, isFalse);
    });
  });
}
