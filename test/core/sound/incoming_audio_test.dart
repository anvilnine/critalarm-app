import 'package:critalarm/core/sound/incoming_audio.dart';
import 'package:critalarm/core/sound/sound_import.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pickedSoundFileFrom', () {
    test('reads the path, name and size the platform sent', () {
      final file = pickedSoundFileFrom({
        'path': '/cache/incoming_audio/New Recording.m4a',
        'name': 'New Recording.m4a',
        'size_bytes': 2048,
      });
      expect(file?.path, '/cache/incoming_audio/New Recording.m4a');
      expect(file?.name, 'New Recording.m4a');
      expect(file?.sizeBytes, 2048);
    });

    test('takes the name from the path when none was sent', () {
      final file = pickedSoundFileFrom({
        'path': '/cache/incoming_audio/memo.m4a',
        'size_bytes': 10,
      });
      expect(file?.name, 'memo.m4a');
    });

    test('a missing size reads as zero, which the check calls unreadable', () {
      final file = pickedSoundFileFrom({'path': '/cache/a.mp3'});
      expect(file?.sizeBytes, 0);
    });

    test('anything without a path is nothing', () {
      expect(pickedSoundFileFrom(null), isNull);
      expect(pickedSoundFileFrom('/cache/a.mp3'), isNull);
      expect(pickedSoundFileFrom({'path': ''}), isNull);
    });
  });

  group('IncomingAudio', () {
    late List<PickedSoundFile> opened;
    late List<SoundImportRejection> rejected;
    late List<String> discarded;
    late bool canImport;
    late bool onboardingDone;
    late bool ringing;

    IncomingAudio build() => IncomingAudio(
      canImportSounds: () async => canImport,
      isOnboardingDone: () async => onboardingDone,
      isRinging: () async => ringing,
      open: opened.add,
      reject: rejected.add,
      discard: (path) async => discarded.add(path),
      platform: TargetPlatform.iOS,
    );

    const memo = PickedSoundFile(
      path: '/cache/incoming_audio/memo.m4a',
      name: 'memo.m4a',
      sizeBytes: 4096,
    );

    setUp(() {
      opened = [];
      rejected = [];
      discarded = [];
      canImport = true;
      onboardingDone = true;
      ringing = false;
    });

    test('a readable file opens the cropper', () async {
      final incoming = build();
      await incoming.receive(memo);
      expect(opened, [memo]);
      expect(incoming.pending, isNull);
    });

    test('waits until onboarding is finished', () async {
      onboardingDone = false;
      final incoming = build();
      await incoming.receive(memo);
      expect(opened, isEmpty);
      expect(incoming.pending, memo);

      await incoming.tryOpen();
      expect(opened, isEmpty);

      onboardingDone = true;
      await incoming.tryOpen();
      expect(opened, [memo]);
      expect(incoming.pending, isNull);
    });

    test('waits until a ringing alarm is acknowledged', () async {
      ringing = true;
      final incoming = build();
      await incoming.receive(memo);
      expect(opened, isEmpty);

      ringing = false;
      await incoming.tryOpen();
      expect(opened, [memo]);
    });

    test('opens once, however often it is asked', () async {
      final incoming = build();
      await incoming.receive(memo);
      await incoming.tryOpen();
      await incoming.tryOpen();
      expect(opened, [memo]);
    });

    test('a file that fails the check is deleted and reported', () async {
      final incoming = build();
      await incoming.receive(
        const PickedSoundFile(
          path: '/cache/incoming_audio/notes.txt',
          name: 'notes.txt',
          sizeBytes: 12,
        ),
      );
      expect(opened, isEmpty);
      expect(rejected, [SoundImportRejection.unsupportedFormat]);
      expect(discarded, ['/cache/incoming_audio/notes.txt']);
    });

    test('an empty file is reported as unreadable', () async {
      final incoming = build();
      await incoming.receive(
        const PickedSoundFile(path: '/c/a.m4a', name: 'a.m4a', sizeBytes: 0),
      );
      expect(rejected, [SoundImportRejection.unreadable]);
      expect(discarded, ['/c/a.m4a']);
    });

    test('the check runs before the wait, so a bad file is not held', () async {
      onboardingDone = false;
      final incoming = build();
      await incoming.receive(
        const PickedSoundFile(path: '/c/a.pdf', name: 'a.pdf', sizeBytes: 9),
      );
      expect(incoming.pending, isNull);
      expect(rejected, [SoundImportRejection.unsupportedFormat]);
    });

    test('a newer file replaces a held one, and the older is deleted', () async {
      onboardingDone = false;
      final incoming = build();
      await incoming.receive(memo);
      const second = PickedSoundFile(
        path: '/cache/incoming_audio/b.mp3',
        name: 'b.mp3',
        sizeBytes: 100,
      );
      await incoming.receive(second);
      expect(discarded, [memo.path]);

      onboardingDone = true;
      await incoming.tryOpen();
      expect(opened, [second]);
    });

    test('a platform that cannot import sounds drops the file', () async {
      canImport = false;
      final incoming = build();
      await incoming.receive(memo);
      expect(opened, isEmpty);
      expect(rejected, isEmpty);
      expect(incoming.pending, isNull);
      expect(discarded, [memo.path]);
    });
  });
}
