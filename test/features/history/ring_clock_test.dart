import 'package:critalarm/features/history/presentation/history_formatting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatRingClock', () {
    test('pads seconds under a minute', () {
      expect(formatRingClock(const Duration(seconds: 4)), '0:04');
    });

    test('shows minutes and padded seconds', () {
      expect(formatRingClock(const Duration(minutes: 6, seconds: 2)), '6:02');
    });

    test('zero reads 0:00', () {
      expect(formatRingClock(Duration.zero), '0:00');
    });
  });
}
