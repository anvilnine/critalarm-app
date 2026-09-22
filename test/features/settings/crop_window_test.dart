import 'package:critalarm/features/settings/domain/crop_window.dart';
import 'package:flutter_test/flutter_test.dart';

Duration ms(int value) => Duration(milliseconds: value);
Duration s(num value) => Duration(milliseconds: (value * 1000).round());

void main() {
  const max = Duration(milliseconds: 29500);

  CropWindow window({
    required num start,
    required num length,
    num file = 222,
  }) => CropWindow(
    start: s(start),
    length: s(length),
    fileLength: s(file),
    maxLength: max,
  );

  group('the first window', () {
    test('a file that fits is selected whole', () {
      final w = CropWindow.initial(fileLength: ms(12345), maxLength: max);
      expect(w.start, Duration.zero);
      expect(w.length, ms(12345));
      expect(w.end, ms(12345));
    });

    test('a long file opens at max length on its loudest part', () {
      // 100 slices over 100 s. Slices 40 to 69 are loud.
      final peaks = [
        for (var i = 0; i < 100; i++) i >= 40 && i < 70 ? 1.0 : 0.1,
      ];
      final w = CropWindow.initial(
        fileLength: s(100),
        maxLength: max,
        peaks: peaks,
      );
      expect(w.length, max);
      expect(w.start, s(40));
      expect(w.isAtMax, isTrue);
    });

    test('a whole file shorter than the max is not at the max', () {
      final w = CropWindow.initial(fileLength: s(21.7), maxLength: max);
      expect(w.length, s(21.7));
      expect(w.isAtMax, isFalse);
    });

    test('a long file with no peaks opens at the start', () {
      final w = CropWindow.initial(fileLength: s(100), maxLength: max);
      expect(w.start, Duration.zero);
      expect(w.length, max);
    });
  });

  group('loudestStart', () {
    test('finds the loudest stretch of the given length', () {
      final peaks = [0.1, 0.1, 0.9, 1.0, 0.8, 0.1, 0.1, 0.1, 0.1, 0.1];
      expect(
        CropWindow.loudestStart(peaks, fileLength: s(10), length: s(3)),
        s(2),
      );
    });

    test('never starts so late the window runs off the end', () {
      final peaks = [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 1.0];
      expect(
        CropWindow.loudestStart(peaks, fileLength: s(10), length: s(3)),
        s(7),
      );
    });

    test('with no peaks it is the start', () {
      expect(
        CropWindow.loudestStart(const [], fileLength: s(10), length: s(3)),
        Duration.zero,
      );
    });
  });

  group('moving the whole window', () {
    test('keeps its length and rounds to a tenth of a second', () {
      final w = window(start: 42, length: 20).move(ms(1234));
      expect(w.start, ms(43200));
      expect(w.length, s(20));
    });

    test('stops at the start of the file', () {
      final w = window(start: 2, length: 20).move(s(-10));
      expect(w.start, Duration.zero);
      expect(w.length, s(20));
    });

    test('stops at the end of the file', () {
      final w = window(start: 190, length: 20).move(s(50));
      expect(w.end, s(222));
      expect(w.length, s(20));
    });

    test('centring on a point keeps it inside the file', () {
      expect(window(start: 0, length: 20).centerOn(s(100)).start, s(90));
      expect(window(start: 50, length: 20).centerOn(s(3)).start, Duration.zero);
      expect(window(start: 0, length: 20).centerOn(s(221)).end, s(222));
    });
  });

  group('pulling the start handle', () {
    test('moves the start and keeps the end', () {
      final w = window(start: 42, length: 20).dragStart(s(45.04));
      expect(w.start, s(45));
      expect(w.end, s(62));
    });

    test('cannot make the clip shorter than one second', () {
      final w = window(start: 42, length: 20).dragStart(s(61.8));
      expect(w.length, s(1));
      expect(w.end, s(62));
    });

    test('cannot make the clip longer than the max', () {
      final w = window(start: 42, length: 20).dragStart(s(10));
      expect(w.length, max);
      expect(w.end, s(62));
    });

    test('cannot go before the start of the file', () {
      final w = window(start: 5, length: 20).dragStart(s(-3));
      expect(w.start, Duration.zero);
      expect(w.end, s(25));
    });
  });

  group('pulling the end handle', () {
    test('moves the end and keeps the start', () {
      final w = window(start: 42, length: 20).dragEnd(s(50));
      expect(w.start, s(42));
      expect(w.length, s(8));
    });

    test('cannot make the clip shorter than one second', () {
      final w = window(start: 42, length: 20).dragEnd(s(42.2));
      expect(w.length, s(1));
    });

    test('cannot make the clip longer than the max', () {
      final w = window(start: 42, length: 20).dragEnd(s(200));
      expect(w.length, max);
      expect(w.isAtMax, isTrue);
    });

    test('cannot run past the end of the file', () {
      final w = window(start: 210, length: 5).dragEnd(s(300));
      expect(w.end, s(222));
    });
  });

  group('clamp', () {
    test('pulls a window back inside all the limits', () {
      final w = CropWindow(
        start: s(-5),
        length: s(90),
        fileLength: s(222),
        maxLength: max,
      ).clamp();
      expect(w.start, Duration.zero);
      expect(w.length, max);
    });

    test('a file shorter than a second is kept whole', () {
      final w = CropWindow.initial(fileLength: ms(600), maxLength: max);
      expect(w.length, ms(600));
      expect(w.dragEnd(ms(100)).length, ms(600));
    });
  });

  group('slicePeaks', () {
    test('takes the loudest value in each slice', () {
      final peaks = [0.1, 0.9, 0.2, 0.3, 0.8, 0.4];
      expect(slicePeaks(peaks, from: 0, to: 1, count: 3), [0.9, 0.3, 0.8]);
    });

    test('a slice of the file zooms in', () {
      final peaks = [0.1, 0.9, 0.2, 0.3, 0.8, 0.4];
      expect(slicePeaks(peaks, from: 0.5, to: 1, count: 3), [0.3, 0.8, 0.4]);
    });

    test('anything outside the file is zero', () {
      final peaks = [0.5, 0.5];
      expect(slicePeaks(peaks, from: -0.5, to: 1.5, count: 4), [
        0.0,
        0.5,
        0.5,
        0.0,
      ]);
    });

    test('no peaks gives an empty list', () {
      expect(slicePeaks(const [], from: 0, to: 1, count: 10), isEmpty);
    });
  });
}
