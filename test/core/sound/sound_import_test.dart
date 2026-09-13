import 'package:critalarm/core/sound/sound_import.dart';
import 'package:critalarm/features/settings/domain/usecases/import_sound_usecase.dart';
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
        ),
        isNull,
      );
    });

    test('exactly 60 seconds passes, a millisecond over does not', () {
      expect(
        checkSoundImport(
          fileName: 'honk.mp3',
          sizeBytes: oneMb,
          duration: SoundImportLimits.maxDuration,
        ),
        isNull,
      );
      expect(
        checkSoundImport(
          fileName: 'honk.mp3',
          sizeBytes: oneMb,
          duration:
              SoundImportLimits.maxDuration + const Duration(milliseconds: 1),
        ),
        SoundImportRejection.tooLong,
      );
    });

    test('exactly 5 MB passes, a byte over does not', () {
      expect(
        checkSoundImport(
          fileName: 'honk.mp3',
          sizeBytes: SoundImportLimits.maxBytes,
          duration: const Duration(seconds: 5),
        ),
        isNull,
      );
      expect(
        checkSoundImport(
          fileName: 'honk.mp3',
          sizeBytes: SoundImportLimits.maxBytes + 1,
          duration: const Duration(seconds: 5),
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
        ),
        SoundImportRejection.unsupportedFormat,
      );
      expect(
        checkSoundImport(
          fileName: 'noextension',
          sizeBytes: oneMb,
          duration: const Duration(seconds: 5),
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
        ),
        SoundImportRejection.unreadable,
      );
      expect(
        checkSoundImport(
          fileName: 'honk.mp3',
          sizeBytes: oneMb,
          duration: Duration.zero,
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
