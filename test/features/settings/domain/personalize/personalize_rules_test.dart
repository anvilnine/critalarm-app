import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/bundled_sounds.dart';
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
    for (final id in [BundledSounds.fallbackId, 'a', 'b', 'c', 'd']) _sound(id),
  ];
  // Own sounds carry the id prefix the lock rule reads.
  final own = [
    _sound('user_1', AlarmSoundSource.user),
    _sound('user_2', AlarmSoundSource.user),
  ];

  SoundStrip strip({
    required String defaultId,
    bool locked = false,
    List<AlarmSound>? userSounds,
    List<AlarmSound> others = const [],
  }) => soundStripFor(
    builtIn: builtIn,
    userSounds: userSounds ?? const [],
    others: others,
    defaultId: defaultId,
    ownSoundsLocked: locked,
  );

  group('soundStripFor', () {
    test('leads with the saved default, then three other built-ins', () {
      final s = strip(defaultId: 'c');
      expect(s.current?.id, 'c');
      expect(s.builtIns.map((b) => b.id), [BundledSounds.fallbackId, 'a', 'b']);
      expect(s.yours, isNull);
      expect(s.currentIsOwn, isFalse);
    });

    test('open: an own sound saved as the default rings and leads', () {
      final s = strip(defaultId: 'user_1', userSounds: own);
      expect(s.current?.id, 'user_1');
      expect(s.currentIsOwn, isTrue);
      expect(s.builtIns.map((b) => b.id), [BundledSounds.fallbackId, 'a', 'b']);
      expect(s.yours?.id, 'user_1');
    });

    test('locked: a saved own sound does not ring. The tick is on the '
        'sound standing in for it, and the saved one is "Yours"', () {
      final s = strip(defaultId: 'user_1', userSounds: own, locked: true);
      expect(s.current?.id, BundledSounds.fallbackId);
      expect(s.currentIsOwn, isFalse);
      expect(s.yours?.id, 'user_1');
      expect(s.builtIns.map((b) => b.id), isNot(contains(s.current!.id)));
      expect(s.builtIns, hasLength(3));
    });

    test('locked with a built-in saved: nothing moves', () {
      final s = strip(defaultId: 'b', userSounds: own, locked: true);
      expect(s.current?.id, 'b');
      // "Yours" stands for the newest own sound.
      expect(s.yours?.id, 'user_2');
    });

    test('a pack sound can be the default', () {
      final s = strip(
        defaultId: 'p1',
        others: [_sound('p1', AlarmSoundSource.pack)],
      );
      expect(s.current?.id, 'p1');
      expect(s.currentIsOwn, isFalse);
    });

    test('a default that names no sound leaves no current chip', () {
      final s = strip(defaultId: 'gone');
      expect(s.current, isNull);
      expect(s.builtIns, hasLength(3));
    });
  });

  group('tryBarFor', () {
    const tried = PersonalizeTry(AppFeature.ownSounds, optionId: 'user_2');

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
        AppFeature.widgets: FeatureDecision.locked(Holding.pro),
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
}
