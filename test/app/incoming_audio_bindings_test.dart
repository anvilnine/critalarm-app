import 'package:critalarm/app/incoming_audio_bindings.dart';
import 'package:critalarm/core/sound/sound_import.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('messageFor', () {
    String message(SoundImportRejection r) =>
        AppIncomingAudioBindings.messageFor(r);

    test('an unreadable share has its own words', () {
      expect(
        message(SoundImportRejection.unreadable),
        'The shared file could not be opened.',
      );
    });

    test('the other reasons use the "Pick a file" words', () {
      expect(
        message(SoundImportRejection.unsupportedFormat),
        'That file type is not supported.',
      );
      expect(
        message(SoundImportRejection.tooLarge),
        'That file is bigger than 100 MB.',
      );
      expect(
        message(SoundImportRejection.sourceTooLong),
        'That file is longer than 20 minutes.',
      );
    });
  });
}
