import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
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
    late List<FeatureDecision> paywalls;
    late Future<FeatureDecision> Function() readOwnSounds;

    IncomingAudio build() {
      final incoming = IncomingAudio(
        canImportSounds: () async => canImport,
        readOwnSounds: () => readOwnSounds(),
        isOnboardingDone: () async => onboardingDone,
        isRinging: () async => ringing,
        discard: (path) async => discarded.add(path),
        platform: TargetPlatform.iOS,
      );
      incoming.toOpen.listen(opened.add);
      incoming.rejected.listen(rejected.add);
      incoming.locked.listen(paywalls.add);
      addTearDown(incoming.dispose);
      return incoming;
    }

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
      paywalls = [];
      readOwnSounds = () async => const FeatureDecision.open();
    });

    group('own sounds locked', () {
      const lockedDecision = FeatureDecision.locked(Holding.pro);

      test('the file is dropped and the paywall opens', () async {
        readOwnSounds = () async => lockedDecision;
        final incoming = build();
        await incoming.receive(memo);
        expect(opened, isEmpty);
        expect(discarded, [memo.path]);
        expect(incoming.pending, isNull);
        expect(paywalls, [lockedDecision]);
        expect(incoming.hasPaywallPending, isFalse);
      });

      test('a file the check would reject still gets the paywall', () async {
        readOwnSounds = () async => lockedDecision;
        final incoming = build();
        const pdf = PickedSoundFile(
          path: '/cache/incoming_audio/a.pdf',
          name: 'a.pdf',
          sizeBytes: 10,
        );
        await incoming.receive(pdf);
        expect(rejected, isEmpty);
        expect(discarded, [pdf.path]);
        expect(paywalls, [lockedDecision]);
      });

      test('the paywall waits for a ringing alarm, not the file', () async {
        readOwnSounds = () async => lockedDecision;
        ringing = true;
        final incoming = build();
        await incoming.receive(memo);
        expect(discarded, [memo.path]);
        expect(paywalls, isEmpty);
        expect(incoming.hasPaywallPending, isTrue);

        ringing = false;
        await incoming.tryOpen();
        expect(paywalls, [lockedDecision]);
        expect(opened, isEmpty);

        await incoming.tryOpen();
        expect(paywalls, hasLength(1));
      });

      test('the paywall waits for setup to finish', () async {
        readOwnSounds = () async => lockedDecision;
        onboardingDone = false;
        final incoming = build();
        await incoming.receive(memo);
        expect(paywalls, isEmpty);

        onboardingDone = true;
        await incoming.tryOpen();
        expect(paywalls, [lockedDecision]);
      });

      test('a paywall still waiting is dropped once Pro is back', () async {
        readOwnSounds = () async => lockedDecision;
        ringing = true;
        final incoming = build();
        await incoming.receive(memo);

        readOwnSounds = () async => const FeatureDecision.open();
        ringing = false;
        await incoming.tryOpen();
        expect(paywalls, isEmpty);
        expect(opened, isEmpty);
        expect(incoming.hasPaywallPending, isFalse);
      });

      test('a file held from before the lock is dropped, not kept', () async {
        ringing = true;
        final incoming = build();
        await incoming.receive(memo);
        expect(incoming.pending, memo);

        readOwnSounds = () async => lockedDecision;
        ringing = false;
        await incoming.tryOpen();
        expect(opened, isEmpty);
        expect(discarded, [memo.path]);
        expect(incoming.pending, isNull);
        expect(paywalls, [lockedDecision]);
      });

      test('a plan that could not be read lets the file through', () async {
        readOwnSounds = () async => const FeatureDecision.unread(Holding.pro);
        final incoming = build();
        await incoming.receive(memo);
        expect(opened, [memo]);
        expect(paywalls, isEmpty);
        expect(discarded, isEmpty);
      });

      test('a read that throws lets the file through', () async {
        readOwnSounds = () async => throw const HoldingUnreadable(Holding.pro);
        final incoming = build();
        await incoming.receive(memo);
        expect(opened, [memo]);
        expect(paywalls, isEmpty);
      });

      test('a purchase being confirmed lets the file through', () async {
        readOwnSounds = () async =>
            const FeatureDecision.confirming(Holding.pro);
        final incoming = build();
        await incoming.receive(memo);
        expect(opened, [memo]);
        expect(paywalls, isEmpty);
      });
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

    test('the same copy arriving twice opens once', () async {
      final incoming = build();
      await incoming.receive(memo);
      await incoming.receive(memo);
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

    test(
      'a newer file replaces a held one, and the older is deleted',
      () async {
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
      },
    );

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
