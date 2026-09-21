import 'package:critalarm/core/sound/sound_import.dart';
import 'package:critalarm/features/settings/domain/usecases/import_sound_usecase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const oneMb = 1024 * 1024;

  group('import caps', () {
    test('a short, small, known file passes', () {
      expect(
        checkSoundImport(
          fileName: 'honk.mp3',
          sizeBytes: oneMb,
          duration: const Duration(seconds: 12),
          platform: TargetPlatform.android,
        ),
        isNull,
      );
    });

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

    test(
      'on Android exactly 60 seconds passes, a millisecond over does not',
      () {
        const cap = Duration(seconds: 60);
        expect(
          checkSoundImport(
            fileName: 'honk.mp3',
            sizeBytes: oneMb,
            duration: cap,
            platform: TargetPlatform.android,
          ),
          isNull,
        );
        expect(
          checkSoundImport(
            fileName: 'honk.mp3',
            sizeBytes: oneMb,
            duration: cap + const Duration(milliseconds: 1),
            platform: TargetPlatform.android,
          ),
          SoundImportRejection.tooLong,
        );
      },
    );

    test('on iOS exactly 29.5 seconds passes, a millisecond over does not', () {
      const cap = Duration(milliseconds: 29500);
      expect(
        checkSoundImport(
          fileName: 'honk.mp3',
          sizeBytes: oneMb,
          duration: cap,
          platform: TargetPlatform.iOS,
        ),
        isNull,
      );
      expect(
        checkSoundImport(
          fileName: 'honk.mp3',
          sizeBytes: oneMb,
          duration: cap + const Duration(milliseconds: 1),
          platform: TargetPlatform.iOS,
        ),
        SoundImportRejection.tooLong,
      );
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

    test('exactly 5 MB passes, a byte over does not', () {
      expect(
        checkSoundImport(
          fileName: 'honk.mp3',
          sizeBytes: SoundImportLimits.maxBytes,
          duration: const Duration(seconds: 5),
          platform: TargetPlatform.android,
        ),
        isNull,
      );
      expect(
        checkSoundImport(
          fileName: 'honk.mp3',
          sizeBytes: SoundImportLimits.maxBytes + 1,
          duration: const Duration(seconds: 5),
          platform: TargetPlatform.android,
        ),
        SoundImportRejection.tooLarge,
      );
    });

    test('a file type neither platform plays is turned away', () {
      expect(
        checkSoundImport(
          fileName: 'clip.mov',
          sizeBytes: oneMb,
          duration: const Duration(seconds: 5),
          platform: TargetPlatform.android,
        ),
        SoundImportRejection.unsupportedFormat,
      );
      expect(
        checkSoundImport(
          fileName: 'noextension',
          sizeBytes: oneMb,
          duration: const Duration(seconds: 5),
          platform: TargetPlatform.android,
        ),
        SoundImportRejection.unsupportedFormat,
      );
    });

    test('an empty file, or one nothing can decode, is unreadable', () {
      expect(
        checkSoundImport(
          fileName: 'honk.mp3',
          sizeBytes: 0,
          duration: const Duration(seconds: 5),
          platform: TargetPlatform.android,
        ),
        SoundImportRejection.unreadable,
      );
      expect(
        checkSoundImport(
          fileName: 'honk.mp3',
          sizeBytes: oneMb,
          duration: Duration.zero,
          platform: TargetPlatform.android,
        ),
        SoundImportRejection.unreadable,
      );
    });

    test('the length cap is checked before the size cap', () {
      expect(
        checkSoundImport(
          fileName: 'honk.mp3',
          sizeBytes: SoundImportLimits.maxBytes + 1,
          duration: const Duration(minutes: 5),
          platform: TargetPlatform.android,
        ),
        SoundImportRejection.tooLong,
      );
    });

    test('the extension check ignores case', () {
      expect(extensionOf('HONK.MP3'), 'mp3');
      expect(extensionOf('a.b.OGG'), 'ogg');
      expect(extensionOf('trailing.'), '');
      expect(extensionOf('none'), '');
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
