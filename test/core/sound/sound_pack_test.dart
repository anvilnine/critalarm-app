import 'package:critalarm/core/sound/bundled_sounds.dart';
import 'package:critalarm/core/sound/sound_import.dart';
import 'package:critalarm/core/sound/sound_pack.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const library = SoundPacks.library;

  test('the library pack holds 23 sounds with distinct pack ids', () {
    expect(library.sounds, hasLength(23));
    expect(library.soundIds.toSet(), hasLength(23));
    for (final id in library.soundIds) {
      expect(id, startsWith('pack_library_'));
      expect(SoundPacks.isPackSound(id), isTrue);
      expect(BundledSounds.isBundled(id), isFalse);
    }
  });

  test('no bundled sound looks like a pack sound', () {
    for (final id in BundledSounds.ids) {
      expect(SoundPacks.isPackSound(id), isFalse);
    }
  });

  test('every library sound is 10 to 30 s and rings on an iPhone', () {
    for (final sound in library.sounds) {
      expect(sound.duration, greaterThanOrEqualTo(const Duration(seconds: 10)));
      expect(
        SoundImportLimits.tooLongToRing(TargetPlatform.iOS, sound.duration),
        isFalse,
        reason: sound.id,
      );
    }
  });

  test('the six caution files are not in the pack', () {
    const excluded = [
      'ambulance-siren-2-s1464',
      'digital-pager-s3513',
      'alphanumeric-pager-s3514',
      'Alarm_-_Collision',
      'Alarm_-_Diving_-_H8',
      'sirens-and-alarm-noise',
    ];
    for (final sound in library.sounds) {
      for (final name in excluded) {
        expect(sound.sourceUrl, isNot(contains(name)), reason: sound.id);
      }
    }
  });

  test('every sound is credited with title, author, source and licence', () {
    final credits = library.creditsText;
    for (final sound in library.sounds) {
      expect(sound.title, isNotEmpty);
      expect(sound.author, isNotEmpty);
      expect(sound.sourceUrl, startsWith('https://'));
      expect(
        sound.licence,
        anyOf(startsWith('CC0'), startsWith('Public domain')),
      );
      expect(credits, contains(sound.sourceUrl));
      expect(credits, contains(sound.title));
    }
  });

  test('a pack sound is found by id', () {
    expect(
      SoundPacks.info('pack_library_boxing_bell')?.englishName,
      'Boxing bell',
    );
    expect(SoundPacks.info('classic_siren'), isNull);
    expect(library.contains('pack_library_boxing_bell'), isTrue);
  });

  test('wire words map to pack states, and anything else is unavailable', () {
    expect(
      SoundPackState.fromWire('not_downloaded'),
      SoundPackState.notDownloaded,
    );
    expect(SoundPackState.fromWire('downloading'), SoundPackState.downloading);
    expect(
      SoundPackState.fromWire('waiting_for_wifi'),
      SoundPackState.waitingForWifi,
    );
    expect(
      SoundPackState.fromWire('needs_confirmation'),
      SoundPackState.needsConfirmation,
    );
    expect(SoundPackState.fromWire('downloaded'), SoundPackState.downloaded);
    expect(SoundPackState.fromWire('failed'), SoundPackState.failed);
    expect(
      SoundPackState.fromWire('needs_newer_os'),
      SoundPackState.needsNewerOs,
    );
    expect(SoundPackState.fromWire('unsupported'), SoundPackState.unsupported);
    expect(SoundPackState.fromWire('unavailable'), SoundPackState.unavailable);
    expect(
      SoundPackState.fromWire('something new'),
      SoundPackState.unavailable,
    );
    expect(SoundPackState.fromWire(null), SoundPackState.unavailable);
  });

  test('only a pack that can be fetched offers download', () {
    expect(SoundPackState.notDownloaded.canDownload, isTrue);
    expect(SoundPackState.failed.canDownload, isTrue);
    expect(SoundPackState.downloaded.canDownload, isFalse);
    expect(SoundPackState.unavailable.canDownload, isFalse);
    expect(SoundPackState.needsNewerOs.canDownload, isFalse);
    expect(SoundPackState.downloading.isBusy, isTrue);
  });

  test('status reads progress and clamps it', () {
    expect(
      SoundPackStatus.fromMap(const {'state': 'downloading', 'progress': 0.4}),
      const SoundPackStatus(SoundPackState.downloading, progress: 0.4),
    );
    expect(
      SoundPackStatus.fromMap(const {
        'state': 'downloading',
        'progress': 3,
      }).progress,
      1.0,
    );
    expect(
      SoundPackStatus.fromMap(null).state,
      SoundPackState.unavailable,
    );
  });
}
