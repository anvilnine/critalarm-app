import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/features/settings/domain/personalize/personalize_rules.dart';
import 'package:flutter_test/flutter_test.dart';

AlarmSound _sound(
  String id, [
  AlarmSoundSource source = AlarmSoundSource.bundled,
]) => AlarmSound(
  id: id,
  name: id,
  source: source,
  path: id,
  duration: const Duration(seconds: 3),
);

void main() {
  final builtIn = [
    for (final id in ['a', 'b', 'c', 'd', 'e']) _sound(id),
  ];
  final own = [
    _sound('u1', AlarmSoundSource.user),
    _sound('u2', AlarmSoundSource.user),
  ];

  group('soundStripFor', () {
    test('leads with the saved default, then three other built-ins', () {
      final strip = soundStripFor(
        builtIn: builtIn,
        userSounds: const [],
        defaultId: 'c',
      );
      expect(strip.current?.id, 'c');
      expect(strip.builtIns.map((s) => s.id), ['a', 'b', 'd']);
      expect(strip.newestOwn, isNull);
      expect(strip.currentIsOwn, isFalse);
    });

    test('an own sound saved as the default is what leads', () {
      final strip = soundStripFor(
        builtIn: builtIn,
        userSounds: own,
        defaultId: 'u1',
      );
      expect(strip.current?.id, 'u1');
      expect(strip.currentIsOwn, isTrue);
      expect(strip.builtIns.map((s) => s.id), ['a', 'b', 'c']);
      expect(strip.newestOwn?.id, 'u2');
    });

    test('a pack sound can be the default', () {
      final strip = soundStripFor(
        builtIn: builtIn,
        userSounds: const [],
        others: [_sound('p1', AlarmSoundSource.pack)],
        defaultId: 'p1',
      );
      expect(strip.current?.id, 'p1');
      expect(strip.currentIsOwn, isFalse);
    });

    test('a default that names no sound leaves no current chip', () {
      final strip = soundStripFor(
        builtIn: builtIn,
        userSounds: const [],
        defaultId: 'gone',
      );
      expect(strip.current, isNull);
      expect(strip.builtIns, hasLength(3));
    });
  });

  group('yoursTapFor', () {
    test('picks the newest own sound when a built-in rings', () {
      final strip = soundStripFor(
        builtIn: builtIn,
        userSounds: own,
        defaultId: 'a',
      );
      expect(yoursTapFor(strip), YoursTap.pickNewest);
    });

    test('opens the picker with no own sound', () {
      final strip = soundStripFor(
        builtIn: builtIn,
        userSounds: const [],
        defaultId: 'a',
      );
      expect(yoursTapFor(strip), YoursTap.openPicker);
    });

    test('opens the picker when an own sound already rings', () {
      final strip = soundStripFor(
        builtIn: builtIn,
        userSounds: own,
        defaultId: 'u2',
      );
      expect(yoursTapFor(strip), YoursTap.openPicker);
    });
  });

  group('tryBarFor', () {
    const tried = PersonalizeTry(AppFeature.ownSounds, optionId: 'u2');

    test('nothing tried and nothing confirming: no bar', () {
      expect(
        tryBarFor(
          tried: null,
          decisions: const {
            AppFeature.ownSounds: FeatureDecision.locked(Holding.pro),
            AppFeature.widgets: FeatureDecision.open(),
          },
        ),
        const TryBarHidden(),
      );
    });

    test('a locked option being tried sells the plan that unlocks it', () {
      expect(
        tryBarFor(
          tried: tried,
          decisions: const {
            AppFeature.ownSounds: FeatureDecision.locked(Holding.pro),
          },
        ),
        const TryBarSell(AppFeature.ownSounds, Holding.pro),
      );
    });

    test('a purchase being confirmed is one line, with or without a try', () {
      const decisions = {
        AppFeature.ownSounds: FeatureDecision.confirming(Holding.pro),
        AppFeature.widgets: FeatureDecision.locked(Holding.hosted),
      };
      expect(
        tryBarFor(tried: tried, decisions: decisions),
        const TryBarConfirming(Holding.pro),
      );
      expect(
        tryBarFor(tried: null, decisions: decisions),
        const TryBarConfirming(Holding.pro),
      );
    });

    test('a plan that could not be read never sells', () {
      expect(
        tryBarFor(
          tried: tried,
          decisions: const {
            AppFeature.ownSounds: FeatureDecision.unread(Holding.pro),
          },
        ),
        const TryBarHidden(),
      );
    });

    test('a try whose option opened has nothing to sell', () {
      const decisions = {AppFeature.ownSounds: FeatureDecision.open()};
      expect(
        tryBarFor(tried: tried, decisions: decisions),
        const TryBarHidden(),
      );
      expect(tryStillStands(tried, decisions), isFalse);
    });

    test('a try stands only while its feature is locked', () {
      expect(
        tryStillStands(tried, const {
          AppFeature.ownSounds: FeatureDecision.locked(Holding.pro),
        }),
        isTrue,
      );
      expect(
        tryStillStands(tried, const {
          AppFeature.ownSounds: FeatureDecision.unread(Holding.pro),
        }),
        isFalse,
      );
      expect(tryStillStands(null, const {}), isFalse);
    });
  });

  group('layout', () {
    test('the preview is a third of the screen, a quarter at large text', () {
      expect(
        personalizePreviewHeight(viewportHeight: 840, textScale: 1),
        280,
      );
      expect(
        personalizePreviewHeight(viewportHeight: 840, textScale: 1.3),
        210,
      );
    });

    test('wide is a tablet or a phone on its side', () {
      bool wide(double w, double h) =>
          personalizeIsWide(width: w, height: h, mediumMinWidth: 600);
      expect(wide(390, 844), isFalse);
      expect(wide(844, 390), isTrue);
      expect(wide(1024, 768), isTrue);
      expect(wide(768, 1024), isFalse);
      expect(wide(568, 320), isFalse);
    });
  });
}
