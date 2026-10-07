import 'package:critalarm/features/paywall/presentation/layouts/proof/proof_pro_stage.dart';
import 'package:critalarm/features/paywall/presentation/layouts/proof/proof_replay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('proofBeatTable', () {
    test(
      'plays the refusal, the shake, the note, then the switch going on',
      () {
        final beats = [for (final (beat, _) in proofBeatTable()) beat];

        expect(beats, [
          ProofBeat.capped,
          ProofBeat.refusedTap,
          ProofBeat.shake,
          ProofBeat.note,
          ProofBeat.lifted,
          ProofBeat.switchOn,
          ProofBeat.allOn,
          ProofBeat.reset,
        ]);
      },
    );

    test('has every beat once, in rising time, inside one loop', () {
      for (final locked in [1, 2, 3, 6]) {
        final table = proofBeatTable(lockedRows: locked);
        final times = [for (final (_, at) in table) at];

        expect({for (final (beat, _) in table) beat}, ProofBeat.values.toSet());
        expect(table, hasLength(ProofBeat.values.length));
        expect(times.first, 0);
        for (var i = 1; i < times.length; i++) {
          expect(times[i], greaterThan(times[i - 1]), reason: '$locked rows');
        }
        expect(times.last, lessThan(proofLoopSeconds));
      }
    });

    test('proofBeatAt reads the table', () {
      for (final (beat, at) in proofBeatTable()) {
        expect(proofBeatAt(at + 0.001), beat);
      }
      expect(proofBeatAt(-1), ProofBeat.capped);
      expect(proofBeatAt(proofLoopSeconds), ProofBeat.reset);
    });
  });

  group('ProofFrame', () {
    test('starts capped: locked, off, nothing moving', () {
      final frame = ProofFrame.at(0);

      expect(frame.beat, ProofBeat.capped);
      expect(frame.lifted, 0);
      expect(frame.barsFilled, 0);
      expect(frame.switchOn(0), 0);
      expect(frame.switchOn(1), 0);
      expect(frame.rings(0), 0);
      expect(frame.tap(0), isNull);
      expect(frame.shakeDx, 0);
      expect(frame.noteScale, 1);
    });

    test('the refused tap moves the knob and gives it back', () {
      var furthest = 0.0;
      for (var s = 0.0; s < 2.6; s += 0.01) {
        final frame = ProofFrame.at(s);
        furthest = furthest > frame.switchOn(0) ? furthest : frame.switchOn(0);
        // The cap is still on, so nothing reads as ringing.
        expect(frame.rings(0), 0);
        expect(frame.lifted, 0);
        // Only the tapped row answers.
        expect(frame.switchOn(1), 0);
      }

      expect(furthest, greaterThan(0.3));
      expect(furthest, lessThanOrEqualTo(0.5));
      expect(ProofFrame.at(2.5).switchOn(0), 0);
    });

    test('the shake is sideways, both ways, and ends where it began', () {
      final during = [
        for (var s = 1.22; s < 1.94; s += 0.01) ProofFrame.at(s).shakeDx,
      ];

      expect(during.any((dx) => dx < -1), isTrue);
      expect(during.any((dx) => dx > 1), isTrue);
      expect(ProofFrame.at(1.2).shakeDx, 0);
      expect(ProofFrame.at(1.94).shakeDx, 0);
      expect(ProofFrame.at(5).shakeDx, 0);
    });

    test('the note swells and settles back to its size', () {
      final during = [
        for (var s = 1.55; s < 2.3; s += 0.01) ProofFrame.at(s).noteScale,
      ];

      expect(during.reduce((a, b) => a > b ? a : b), greaterThan(1.1));
      expect(during.every((scale) => scale >= 1), isTrue);
      expect(ProofFrame.at(2.3).noteScale, 1);
    });

    test('the switches go on one after another, after the cap lifts', () {
      // The moment each one is fully on.
      double onAt(int row) {
        for (var s = 0.0; s < proofLoopSeconds; s += 0.01) {
          if (ProofFrame.at(s).switchOn(row) >= 1) return s;
        }
        return double.infinity;
      }

      double liftedAt() {
        for (var s = 0.0; s < proofLoopSeconds; s += 0.01) {
          if (ProofFrame.at(s).lifted >= 1) return s;
        }
        return double.infinity;
      }

      expect(liftedAt(), lessThan(onAt(0)));
      expect(onAt(0), lessThan(onAt(1)));
      expect(onAt(1).isFinite, isTrue);
    });

    test('a finger is on a row only around its own taps', () {
      expect(ProofFrame.at(0.9).tap(0), isNotNull);
      expect(ProofFrame.at(0.9).tap(1), isNull);
      expect(ProofFrame.at(3.5).tap(0), isNotNull);
      expect(ProofFrame.at(3.5).tap(1), isNull);
      expect(ProofFrame.at(4.6).tap(1), isNotNull);
      expect(ProofFrame.at(4.6).tap(0), isNull);
      expect(ProofFrame.at(7).tap(0), isNull);
      expect(ProofFrame.at(7).tap(1), isNull);
    });

    test('the reset takes everything back to the start', () {
      final frame = ProofFrame.at(8.6);

      expect(frame.beat, ProofBeat.reset);
      expect(frame.lifted, 0);
      expect(frame.barsFilled, 0);
      expect(frame.switchOn(0), 0);
      expect(frame.rings(1), 0);
    });
  });

  group('the resting frame', () {
    test('is the end state for any number of locked rows', () {
      for (final locked in [1, 2, 3, 6]) {
        final frame = ProofFrame.atClock(proofRestAt, lockedRows: locked);

        expect(frame.beat, ProofBeat.allOn, reason: '$locked rows');
        expect(frame.lifted, 1);
        expect(frame.barsFilled, 1);
        for (var row = 0; row < locked; row++) {
          expect(frame.switchOn(row), 1, reason: 'row $row of $locked');
          expect(frame.rings(row), 1, reason: 'row $row of $locked');
          expect(frame.tap(row), isNull);
        }
        // Nothing is half way or off its place.
        expect(frame.shakeDx, 0);
        expect(frame.noteScale, 1);
      }
    });

    test('the clock holds the capped frame until the replay starts', () {
      expect(ProofFrame.atClock(0).seconds, 0);
      expect(ProofFrame.atClock(proofReplayStartsAt).seconds, 0);
      expect(
        ProofFrame.atClock(proofReplayStartsAt + 1).seconds,
        closeTo(1, 1e-9),
      );
    });

    test('the replay loops', () {
      final first = ProofFrame.atClock(proofReplayStartsAt + 2);
      final second = ProofFrame.atClock(
        proofReplayStartsAt + proofLoopSeconds + 2,
      );

      expect(second.seconds, closeTo(first.seconds, 1e-9));
      expect(second.beat, first.beat);
    });
  });

  group('proofStripRows', () {
    test('one row up to five tiles, then two rows with the longer first', () {
      expect(proofStripRows(0), isEmpty);
      expect(proofStripRows(-2), isEmpty);
      expect(proofStripRows(1), [1]);
      expect(proofStripRows(4), [4]);
      expect(proofStripRows(5), [5]);
      expect(proofStripRows(6), [3, 3]);
      expect(proofStripRows(7), [4, 3]);
      expect(proofStripRows(9), [5, 4]);
    });

    test('every tile is in a row', () {
      for (var count = 0; count < 12; count++) {
        expect(proofStripRows(count).fold<int>(0, (a, b) => a + b), count);
      }
    });
  });
}
