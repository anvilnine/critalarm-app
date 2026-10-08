import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/sound/bundled_sounds.dart';
import 'package:critalarm/core/sound/own_sound_rule.dart';
import 'package:critalarm/core/sound/sound_assignments.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const own = 'user_1700000000000000';
  const otherOwn = 'user_1700000000000001';
  const builtIn = 'pager_beep';
  const pack = 'pack_library_boxing_bell';

  String rings(
    SoundAssignments saved, {
    required bool locked,
    String? topic,
  }) => OwnSoundRule.ringingSoundId(
    saved: saved,
    ownSoundsLocked: locked,
    topicName: topic,
  );

  group('which decision locks', () {
    test('only a sure locked does', () {
      expect(
        ownSoundsLockedBy(const FeatureDecision.locked(Holding.pro)),
        isTrue,
      );
      expect(ownSoundsLockedBy(const FeatureDecision.open()), isFalse);
      expect(
        ownSoundsLockedBy(const FeatureDecision.confirming(Holding.pro)),
        isFalse,
      );
      expect(
        ownSoundsLockedBy(const FeatureDecision.unread(Holding.pro)),
        isFalse,
      );
    });
  });

  group('own sound on the topic, built-in default', () {
    const saved = SoundAssignments(
      defaultSoundId: builtIn,
      perTopic: {'prod': own},
    );

    test('open: the own sound rings', () {
      expect(rings(saved, locked: false, topic: 'prod'), own);
    });

    test('locked: the default rings', () {
      expect(rings(saved, locked: true, topic: 'prod'), builtIn);
    });

    test('unread: the own sound rings', () {
      final locked = ownSoundsLockedBy(
        const FeatureDecision.unread(Holding.pro),
      );
      expect(rings(saved, locked: locked, topic: 'prod'), own);
    });

    test('a topic with no choice rings the default either way', () {
      expect(rings(saved, locked: false, topic: 'staging'), builtIn);
      expect(rings(saved, locked: true, topic: 'staging'), builtIn);
    });
  });

  group('own sound as the default', () {
    const saved = SoundAssignments(
      defaultSoundId: own,
      perTopic: {'prod': builtIn},
    );

    test('open: the own sound rings for the default', () {
      expect(rings(saved, locked: false), own);
      expect(rings(saved, locked: false, topic: 'staging'), own);
    });

    test('locked: the classic siren rings for the default', () {
      expect(rings(saved, locked: true), BundledSounds.fallbackId);
      expect(rings(saved, locked: true, topic: 'staging'), 'classic_siren');
    });

    test('a topic on a built-in sound keeps it either way', () {
      expect(rings(saved, locked: false, topic: 'prod'), builtIn);
      expect(rings(saved, locked: true, topic: 'prod'), builtIn);
    });

    test('unread: the own sound rings', () {
      final locked = ownSoundsLockedBy(
        const FeatureDecision.unread(Holding.pro),
      );
      expect(rings(saved, locked: locked), own);
    });
  });

  group('own sound on the topic and as the default', () {
    const saved = SoundAssignments(
      defaultSoundId: otherOwn,
      perTopic: {'prod': own},
    );

    test('open: each rings its own', () {
      expect(rings(saved, locked: false, topic: 'prod'), own);
      expect(rings(saved, locked: false), otherOwn);
    });

    test('locked: the classic siren rings for both', () {
      expect(rings(saved, locked: true, topic: 'prod'), 'classic_siren');
      expect(rings(saved, locked: true), 'classic_siren');
    });
  });

  group('no own sound anywhere', () {
    const saved = SoundAssignments(
      defaultSoundId: builtIn,
      perTopic: {'prod': pack},
    );

    test('nothing changes, locked or open', () {
      for (final locked in [true, false]) {
        expect(rings(saved, locked: locked, topic: 'prod'), pack);
        expect(rings(saved, locked: locked), builtIn);
        expect(rings(saved, locked: locked, topic: 'staging'), builtIn);
      }
    });
  });

  group('a store pack sound is free', () {
    test('a locked own topic sound falls to a pack default', () {
      const saved = SoundAssignments(
        defaultSoundId: pack,
        perTopic: {'prod': own},
      );
      expect(rings(saved, locked: true, topic: 'prod'), pack);
    });
  });

  group('the whole set as it rings', () {
    const saved = SoundAssignments(
      defaultSoundId: own,
      perTopic: {'prod': otherOwn, 'staging': builtIn},
    );

    test('locked: no own sound is left, and the saved value is untouched', () {
      final ringing = OwnSoundRule.ringing(saved: saved, ownSoundsLocked: true);
      expect(
        ringing,
        const SoundAssignments(
          defaultSoundId: 'classic_siren',
          perTopic: {'prod': 'classic_siren', 'staging': builtIn},
        ),
      );
      expect(saved.defaultSoundId, own);
      expect(saved.perTopic, {'prod': otherOwn, 'staging': builtIn});
    });

    test('open: the same as what is saved', () {
      expect(
        OwnSoundRule.ringing(saved: saved, ownSoundsLocked: false),
        saved,
      );
    });

    test('whatever is saved, a locked ring is never an own sound', () {
      const ids = [own, otherOwn, builtIn, pack, 'classic_siren'];
      for (final defaultId in ids) {
        for (final topicId in ids) {
          final each = SoundAssignments(
            defaultSoundId: defaultId,
            perTopic: {'prod': topicId},
          );
          for (final topic in [null, 'prod', 'other']) {
            final id = rings(each, locked: true, topic: topic);
            expect(isOwnSoundId(id), isFalse, reason: '$each $topic');
          }
        }
      }
    });
  });
}
