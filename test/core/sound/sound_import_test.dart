import 'package:critalarm/core/sound/sound_import.dart';
import 'package:critalarm/features/settings/domain/usecases/import_sound_usecase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const oneMb = 1024 * 1024;

  group('import caps', () {
    test('the clip cap is 29.5 seconds on iOS and 60 everywhere else', () {
      expect(
        SoundImportLimits.maxClipDuration(TargetPlatform.iOS),
        const Duration(milliseconds: 29500),
      );
      expect(
        SoundImportLimits.maxClipDuration(TargetPlatform.android),
        const Duration(seconds: 60),
      );
    });

    test('the picked file may be up to 100 MB and 20 minutes', () {
      expect(SoundImportLimits.maxSourceBytes, 100 * oneMb);
      expect(SoundImportLimits.maxSourceDuration, const Duration(minutes: 20));
      expect(SoundImportLimits.maxBytes, 5 * oneMb);
    });

    test('an iOS sound of 30 seconds or more is too long to ring', () {
      expect(
        SoundImportLimits.tooLongToRing(
          TargetPlatform.iOS,
          const Duration(seconds: 30),
        ),
        isTrue,
      );
      expect(
        SoundImportLimits.tooLongToRing(
          TargetPlatform.iOS,
          const Duration(milliseconds: 29999),
        ),
        isFalse,
      );
      expect(
        SoundImportLimits.tooLongToRing(
          TargetPlatform.android,
          const Duration(seconds: 90),
        ),
        isFalse,
      );
    });

    test('Android cannot read aiff or caf, iOS also reads Voice Memos qta', () {
      final android = SoundImportLimits.readableExtensionsFor(
        TargetPlatform.android,
      );
      final ios = SoundImportLimits.readableExtensionsFor(TargetPlatform.iOS);
      expect(android, containsAll(['mp3', 'm4a', 'wav', 'ogg', 'flac']));
      expect(android, isNot(contains('aiff')));
      expect(android, isNot(contains('aif')));
      expect(android, isNot(contains('caf')));
      expect(android, isNot(contains('qta')));
      expect(ios, containsAll(['mp3', 'm4a', 'wav', 'aiff', 'aif', 'caf']));
      expect(ios, contains('qta'));
    });
  });

  group('the check before the cropper opens', () {
    SoundImportRejection? check(
      String name,
      int size, {
      TargetPlatform platform = TargetPlatform.android,
    }) => checkPickedSound(
      fileName: name,
      sizeBytes: size,
      platform: platform,
    );

    test('a known file under 100 MB passes', () {
      expect(check('song.mp3', 40 * oneMb), isNull);
    });

    test('exactly 100 MB passes, a byte over does not', () {
      expect(check('song.mp3', SoundImportLimits.maxSourceBytes), isNull);
      expect(
        check('song.mp3', SoundImportLimits.maxSourceBytes + 1),
        SoundImportRejection.tooLarge,
      );
    });

    test('an empty file is unreadable', () {
      expect(check('song.mp3', 0), SoundImportRejection.unreadable);
    });

    test('a file type the platform cannot read is turned away', () {
      expect(check('clip.mov', oneMb), SoundImportRejection.unsupportedFormat);
      expect(check('none', oneMb), SoundImportRejection.unsupportedFormat);
      expect(check('memo.caf', oneMb), SoundImportRejection.unsupportedFormat);
      expect(
        check('memo.caf', oneMb, platform: TargetPlatform.iOS),
        isNull,
      );
      expect(
        check('memo.qta', oneMb, platform: TargetPlatform.iOS),
        isNull,
      );
    });

    test('the extension check ignores case', () {
      expect(extensionOf('HONK.MP3'), 'mp3');
      expect(extensionOf('a.b.OGG'), 'ogg');
      expect(extensionOf('trailing.'), '');
      expect(extensionOf('none'), '');
    });
  });

  group('the check once the length is known', () {
    test('zero means nothing could read it', () {
      expect(
        checkSourceDuration(Duration.zero),
        SoundImportRejection.unreadable,
      );
    });

    test('exactly 20 minutes passes, a millisecond over does not', () {
      const cap = Duration(minutes: 20);
      expect(checkSourceDuration(cap), isNull);
      expect(
        checkSourceDuration(cap + const Duration(milliseconds: 1)),
        SoundImportRejection.sourceTooLong,
      );
    });

    test('a long file is fine, the cropper shortens it', () {
      expect(checkSourceDuration(const Duration(minutes: 4)), isNull);
    });
  });

  group('the name shown for an imported file', () {
    test('drops the extension', () {
      expect(ImportSoundUsecase.displayNameFor('air horn.mp3'), 'air horn');
    });

    test('keeps a name with no extension as it is', () {
      expect(ImportSoundUsecase.displayNameFor('airhorn'), 'airhorn');
    });

    test('cuts a very long name down to one row', () {
      final long = '${'x' * 80}.mp3';
      expect(ImportSoundUsecase.displayNameFor(long).length, 40);
    });
  });
}
