import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:critalarm/core/sound/bundled_sounds.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';

/// The iPhone vibrates on the beat of the sound while the incident screen
/// rings. Each sound has a Core Haptics pattern in `ios/Runner/Haptics`,
/// made by `tools/sounds/haptics.mjs` from the sound's loudness. These tests
/// hold the files to the sounds: there is a pattern for every sound, it is as
/// long as its sound, the sound it was made from has not changed, and its
/// strong and still moments fall where the sound's loud and quiet ones do.
void main() {
  final folder = Directory('ios/Runner/Haptics');
  final manifest =
      jsonDecode(File('${folder.path}/manifest.json').readAsStringSync())
          as Map<String, dynamic>;
  final sounds = manifest['sounds'] as Map<String, dynamic>;

  /// The default ring that ships in the app for an alarm with no sound of
  /// its own, apart from the bundled catalogue.
  const defaultRing = 'alarm';

  final ids = [...BundledSounds.ids, defaultRing];

  Map<String, dynamic> read(String name) =>
      jsonDecode(File('${folder.path}/$name.ahap').readAsStringSync())
          as Map<String, dynamic>;

  List<Map<String, dynamic>> eventsOf(Map<String, dynamic> ahap) => [
    for (final entry in ahap['Pattern'] as List<dynamic>)
      (entry as Map<String, dynamic>)['Event'] as Map<String, dynamic>,
  ];

  double intensityOf(Map<String, dynamic> event) {
    final parameters = event['EventParameters'] as List<dynamic>;
    final intensity = parameters.cast<Map<String, dynamic>>().singleWhere(
      (parameter) => parameter['ParameterID'] == 'HapticIntensity',
    );
    return (intensity['ParameterValue'] as num).toDouble();
  }

  double endOf(Map<String, dynamic> ahap) => eventsOf(ahap)
      .map(
        (event) =>
            (event['Time'] as num).toDouble() +
            (event['EventDuration'] as num).toDouble(),
      )
      .reduce(math.max);

  /// The strongest vibration in each [cellMs] of the pattern.
  List<double> strengthPerCell(Map<String, dynamic> ahap, int cellMs, int n) {
    final cells = List<double>.filled(n, 0);
    for (final event in eventsOf(ahap)) {
      final start = ((event['Time'] as num) * 1000).round();
      final end = start + ((event['EventDuration'] as num) * 1000).round();
      final strength = intensityOf(event);
      for (var c = start ~/ cellMs; c < n && c * cellMs < end; c++) {
        cells[c] = math.max(cells[c], strength);
      }
    }
    return cells;
  }

  /// The strength the rule in `haptics.mjs` gives a loudness: still below
  /// 0.3, then five steps up to full.
  double expectedStrength(double loudness) {
    if (loudness < 0.3) return 0;
    final step = math.max(1, (((loudness - 0.3) / 0.7) * 5).ceil());
    return 0.4 + 0.6 * step / 5;
  }

  test('the folder holds a pattern for every sound and nothing else', () {
    final names = folder
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .where((name) => name.endsWith('.ahap'))
        .map((name) => name.substring(0, name.length - '.ahap'.length))
        .toSet();

    expect(names, {...ids, 'steady'});
    expect(sounds.keys.toSet(), ids.toSet());
  });

  test('the Xcode project ships the Haptics folder with the app', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(project, contains('path = Haptics;'));
    expect(project, contains('Haptics in Resources'));
  });

  group('every pattern', () {
    for (final id in [...ids, 'steady']) {
      test('$id is a valid pattern of continuous events', () {
        final ahap = read(id);
        final events = eventsOf(ahap);

        expect(ahap['Version'], 1);
        expect(events, isNotEmpty);
        for (final event in events) {
          expect(event['EventType'], 'HapticContinuous');
          expect(event['Time'], greaterThanOrEqualTo(0));
          expect(event['EventDuration'], greaterThan(0));
          // Core Haptics plays a continuous event for 30 seconds at most.
          expect(event['EventDuration'], lessThanOrEqualTo(30));
          expect(intensityOf(event), inInclusiveRange(0, 1));
        }
      });
    }
  });

  group('every bundled sound', () {
    for (final id in ids) {
      final entry = sounds[id] as Map<String, dynamic>;
      final expectedMs = id == defaultRing
          ? 25000
          : BundledSounds.durations[id]!.inMilliseconds;

      test('$id is as long as its sound', () {
        expect(entry['durationMs'], expectedMs);
        expect(endOf(read(id)) * 1000, closeTo(expectedMs, 1));
      });

      test('$id was made from the sound that ships today', () {
        final source = File(entry['source'] as String);
        final expected = id == defaultRing
            ? 'ios/Runner/Sounds/alarm.caf'
            : BundledSounds.assetPath(id, TargetPlatform.iOS);

        expect(entry['source'], expected);
        // A new sound file needs `node tools/sounds/haptics.mjs`.
        expect(
          sha256.convert(source.readAsBytesSync()).toString(),
          entry['sha256'],
        );
      });

      test('$id peaks where its sound peaks', () {
        final envelope = (entry['envelope'] as List<dynamic>)
            .map((value) => (value as num).toDouble() / 100)
            .toList();
        final cellMs = manifest['envelopeMs'] as int;
        final strength = strengthPerCell(read(id), cellMs, envelope.length);

        // The loudest moment of the sound is the strongest of the pattern.
        final loudest = envelope.indexOf(envelope.reduce(math.max));
        expect(strength[loudest], 1);

        // Where the sound is loud the motor is strong, and where it is
        // quiet the motor is still.
        for (var i = 0; i < envelope.length; i++) {
          if (envelope[i] >= 0.8) {
            expect(strength[i], greaterThanOrEqualTo(0.88));
          }
          if (envelope[i] < 0.25) {
            expect(strength[i], 0);
          }
        }

        // Rises and falls together. A loudness is kept to whole percent, so
        // a cell on the edge of a step may sit one step off.
        final off = [
          for (var i = 0; i < envelope.length; i++)
            if ((strength[i] - expectedStrength(envelope[i])).abs() > 0.125) i,
        ];
        expect(off.length / envelope.length, lessThan(0.01));
      });
    }
  });

  test('a sound with a pattern of its own is not the steady pulse', () {
    final pulses = eventsOf(read('steady')).where((e) => intensityOf(e) > 0);

    expect(pulses, hasLength(1));
    expect(endOf(read('steady')), 1);
    expect(eventsOf(read('classic_siren')).length, isNot(1));
  });
}
