import 'package:critalarm/core/sound/bundled_sounds.dart';
import 'package:critalarm/core/sound/sound_assignments.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SoundAssignments', () {
    test('a topic with no choice of its own uses the default', () {
      const assignments = SoundAssignments(defaultSoundId: 'pager_beep');
      expect(assignments.soundIdFor('prod-db'), 'pager_beep');
    });

    test('a topic with its own choice keeps it', () {
      const assignments = SoundAssignments(
        defaultSoundId: 'pager_beep',
        perTopic: {'prod-db': 'user_1'},
      );
      expect(assignments.soundIdFor('prod-db'), 'user_1');
      expect(assignments.soundIdFor('nas-backup'), 'pager_beep');
    });

    test('clearing a topic puts it back on the default', () {
      const assignments = SoundAssignments(
        defaultSoundId: 'pager_beep',
        perTopic: {'prod-db': 'user_1'},
      );
      expect(
        assignments.withTopicSound('prod-db', null).soundIdFor('prod-db'),
        'pager_beep',
      );
    });
  });

  group('the fallback rule when a sound is deleted', () {
    test('a topic using the deleted sound falls back to the default', () {
      const before = SoundAssignments(
        defaultSoundId: 'pager_beep',
        perTopic: {'prod-db': 'user_1', 'nas-backup': 'plain_loud_beep'},
      );

      final after = before.withSoundDeleted(
        'user_1',
        fallbackSoundId: BundledSounds.fallbackId,
      );

      expect(after.soundIdFor('prod-db'), 'pager_beep');
      expect(
        after.soundIdFor('nas-backup'),
        'plain_loud_beep',
        reason: 'a topic on a different sound is left alone',
      );
      expect(after.defaultSoundId, 'pager_beep');
    });

    test('deleting the default moves the default to the bundled fallback', () {
      const before = SoundAssignments(
        defaultSoundId: 'user_1',
        perTopic: {'prod-db': 'user_1'},
      );

      final after = before.withSoundDeleted(
        'user_1',
        fallbackSoundId: BundledSounds.fallbackId,
      );

      expect(after.defaultSoundId, BundledSounds.fallbackId);
      expect(
        after.soundIdFor('prod-db'),
        BundledSounds.fallbackId,
        reason: 'the topic falls back to the default, which itself moved',
      );
    });

    test('deleting a sound nothing uses changes nothing', () {
      const before = SoundAssignments(
        defaultSoundId: 'pager_beep',
        perTopic: {'prod-db': 'plain_loud_beep'},
      );

      expect(
        before.withSoundDeleted(
          'user_9',
          fallbackSoundId: BundledSounds.fallbackId,
        ),
        equals(before),
      );
    });

    test('nothing is left pointing at the deleted id', () {
      const before = SoundAssignments(
        defaultSoundId: 'user_1',
        perTopic: {'a': 'user_1', 'b': 'user_1', 'c': 'pager_beep'},
      );

      final after = before.withSoundDeleted(
        'user_1',
        fallbackSoundId: BundledSounds.fallbackId,
      );

      expect(after.defaultSoundId, isNot('user_1'));
      expect(after.perTopic.values, isNot(contains('user_1')));
      expect(after.soundIdFor('c'), 'pager_beep');
    });
  });
}
