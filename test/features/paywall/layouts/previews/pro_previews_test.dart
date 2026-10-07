import 'package:critalarm/features/paywall/presentation/layouts/previews/alarm_screens_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/challenge_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/sounds_preview.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every hundredth of a second across [loop], twice round.
Iterable<double> _seconds(double loop) sync* {
  for (var i = 0; i <= loop * 200; i++) {
    yield i / 100;
  }
}

/// [values] with repeats next to each other folded into one.
List<T> _runs<T>(Iterable<T> values) {
  final out = <T>[];
  for (final value in values) {
    if (out.isEmpty || out.last != value) out.add(value);
  }
  return out;
}

void main() {
  group('wake-up challenge preview', () {
    test('plays its five steps in order, and loops', () {
      final phases = _runs(
        _seconds(
          challengePreviewLoop,
        ).map((t) => challengePreviewFrameAt(t).phase),
      );
      final once = challengePreviewPhases.map((entry) => entry.$1).toList();
      expect(once, ChallengePreviewPhase.values);
      expect(phases, [...once, ...once, ChallengePreviewPhase.ringing]);
    });

    test('rests on the ringing screen behind its lock, whole and upright', () {
      final rest = challengePreviewFrameAt(challengePreviewRestAt);
      expect(rest.phase, ChallengePreviewPhase.ringing);
      expect(rest.tilt, 0);
      expect(rest.pulse, 0);
      expect(rest.scanOpacity, 0);
      expect(rest.found, 0);
      expect(rest.unlock, 0);
      expect(rest.stopped, 0);
    });

    test('the alarm rings on through the scan and stops only once the lock '
        'is open', () {
      final scanning = challengePreviewFrameAt(1.2);
      expect(scanning.pulse, 1);
      expect(scanning.unlock, 0);
      for (final t in _seconds(challengePreviewLoop / 2)) {
        // The last moment of the loop undoes all three together.
        if (t > challengePreviewLoop - challengePreviewReset) continue;
        final frame = challengePreviewFrameAt(t);
        if (frame.stopped > 0) {
          expect(frame.unlock, 1, reason: '$t');
          expect(frame.pulse, 0, reason: '$t');
          expect(frame.tilt, 0, reason: '$t');
        }
        if (frame.unlock > 0) expect(frame.found, 1, reason: '$t');
      }
    });

    test('the line goes down the code and back, then is gone when the code '
        'is found', () {
      final start = challengePreviewStart(ChallengePreviewPhase.scanning);
      final found = challengePreviewStart(ChallengePreviewPhase.found);
      final mid = (start + found) / 2;
      expect(challengePreviewFrameAt(mid).scan, closeTo(1, 1e-9));
      expect(challengePreviewFrameAt(mid).scanOpacity, 1);
      expect(challengePreviewFrameAt(start + 0.25).scan, closeTo(0.5, 1e-9));
      expect(challengePreviewFrameAt(found - 0.25).scan, closeTo(0.5, 1e-9));
      expect(challengePreviewFrameAt(found).scanOpacity, 0);
      expect(challengePreviewFrameAt(found + 0.3).found, 1);
    });

    test('the stopped screen holds, then goes back to ringing before the '
        'loop ends', () {
      final held = challengePreviewFrameAt(6);
      expect(held.stopped, 1);
      expect(held.unlock, 1);
      expect(held.found, 1);
      final last = challengePreviewFrameAt(challengePreviewLoop - 0.001);
      expect(last.stopped, closeTo(0, 0.01));
      expect(last.found, closeTo(0, 0.01));
      expect(challengePreviewFrameAt(challengePreviewLoop).stopped, 0);
    });
  });

  group('alarm sounds preview', () {
    test('plays its five steps in order, and loops', () {
      final phases = _runs(
        _seconds(soundsPreviewLoop).map((t) => soundsPreviewFrameAt(t).phase),
      );
      final once = soundsPreviewPhases.map((entry) => entry.$1).toList();
      expect(once, SoundsPreviewPhase.values);
      expect(phases, [...once, ...once, SoundsPreviewPhase.idle]);
    });

    test('rests on the saved sound: every bar drawn, a row, not playing', () {
      final rest = soundsPreviewFrameAt(soundsPreviewRestAt);
      expect(rest.phase, SoundsPreviewPhase.resting);
      expect(rest.saved, 1);
      expect(rest.recorded, 1);
      expect(rest.peaks, soundsPreviewPeaks);
      expect(rest.played, 0);
      expect(rest.press, 0);
      expect(rest.tap.opacity, 0);
      expect(rest.fade, 1);
    });

    test('nothing is drawn before the record button is pressed', () {
      final idle = soundsPreviewFrameAt(0.3);
      expect(idle.peaks.every((p) => p == 0), isTrue);
      expect(idle.isRecording, isFalse);
      expect(idle.saved, 0);
    });

    test('the waveform draws itself left to right while it records', () {
      var drawn = 0;
      for (final t in _seconds(soundsPreviewLoop / 2)) {
        final frame = soundsPreviewFrameAt(t);
        if (frame.phase != SoundsPreviewPhase.recording) continue;
        final now = frame.peaks.where((p) => p > 0).length;
        expect(now, greaterThanOrEqualTo(drawn), reason: '$t');
        // A bar never stands before the one to its left.
        final firstFlat = frame.peaks.indexWhere((p) => p == 0);
        if (firstFlat >= 0) {
          expect(frame.peaks.skip(firstFlat).every((p) => p == 0), isTrue);
        }
        drawn = now;
      }
      expect(drawn, soundsPreviewPeaks.length);
      final stop = soundsPreviewTaps[1];
      expect(soundsPreviewFrameAt(stop).recorded, 1);
    });

    test('each press comes a tenth of a second before the step it leads '
        'to', () {
      expect(soundsPreviewTaps, [
        for (final phase in [
          SoundsPreviewPhase.recording,
          SoundsPreviewPhase.saved,
          SoundsPreviewPhase.playing,
        ])
          closeTo(soundsPreviewStart(phase) - 0.1, 1e-9),
      ]);
      for (final (i, at) in soundsPreviewTaps.indexed) {
        final frame = soundsPreviewFrameAt(at);
        expect(frame.tap.opacity, 1);
        expect(frame.tapIndex, i);
      }
    });

    test('it plays through once and stops', () {
      final playAt = soundsPreviewStart(SoundsPreviewPhase.playing);
      expect(soundsPreviewFrameAt(playAt + 1).played, closeTo(0.5, 1e-9));
      expect(soundsPreviewFrameAt(playAt + 1).isPlaying, isTrue);
      expect(soundsPreviewFrameAt(playAt + 2.01).played, 0);
    });

    test('the row goes back to the recorder before the loop ends', () {
      final last = soundsPreviewFrameAt(soundsPreviewLoop - 0.001);
      expect(last.saved, closeTo(0, 0.01));
      expect(last.fade, closeTo(0, 0.01));
    });
  });

  group('alarm screens preview', () {
    test('tries on the three looks in order, twice a loop', () {
      final looks = _runs(
        _seconds(
          alarmScreensPreviewLoop / 2,
        ).map((t) => alarmScreensPreviewFrameAt(t).look),
      );
      expect(looks, [
        ...AlarmScreenLook.values,
        ...AlarmScreenLook.values,
        AlarmScreenLook.classic,
      ]);
      expect(alarmScreensPreviewStep, 1.5);
    });

    test('rests on the terminal look, unsqueezed, the mark on its swatch', () {
      final rest = alarmScreensPreviewFrameAt(alarmScreensPreviewRestAt);
      expect(rest.look, AlarmScreenLook.terminal);
      expect(rest.press, 0);
      expect(rest.slot, 1);
      expect(rest.tap.opacity, 0);
    });

    test('the look changes while the screen is squeezed', () {
      final step = alarmScreensPreviewStep;
      expect(
        alarmScreensPreviewFrameAt(step - 0.01).look,
        AlarmScreenLook.classic,
      );
      expect(alarmScreensPreviewFrameAt(step).look, AlarmScreenLook.terminal);
      expect(alarmScreensPreviewFrameAt(step).press, greaterThan(0));
      expect(
        alarmScreensPreviewFrameAt(step + 0.03).press,
        closeTo(1, 0.01),
      );
      expect(alarmScreensPreviewFrameAt(step + 0.5).press, 0);
    });

    test('the finger lands on the swatch of the look that is coming', () {
      final step = alarmScreensPreviewStep;
      final before = alarmScreensPreviewFrameAt(step - 0.04);
      expect(before.look, AlarmScreenLook.classic);
      expect(before.tap.opacity, closeTo(1, 1e-6));
      expect(before.tapSlot, 1);
      expect(alarmScreensPreviewFrameAt(3 * step - 0.04).tapSlot, 0);
    });

    test('the pick mark follows, and goes home from the last swatch', () {
      final step = alarmScreensPreviewStep;
      expect(alarmScreensPreviewFrameAt(step + 0.4).slot, closeTo(1, 1e-9));
      expect(alarmScreensPreviewFrameAt(2 * step + 0.4).slot, closeTo(2, 1e-9));
      final home = alarmScreensPreviewFrameAt(3 * step + 0.1).slot;
      expect(home, lessThan(2));
      expect(alarmScreensPreviewFrameAt(3 * step + 0.4).slot, closeTo(0, 1e-9));
    });
  });
}
