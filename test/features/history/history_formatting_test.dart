import 'package:critalarm/features/history/presentation/history_formatting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatCompactDuration', () {
    test('seconds under a minute', () {
      expect(formatCompactDuration(Duration.zero), '0 s');
      expect(formatCompactDuration(const Duration(seconds: 11)), '11 s');
      expect(formatCompactDuration(const Duration(seconds: 59)), '59 s');
    });

    test('whole minutes from a minute on', () {
      expect(formatCompactDuration(const Duration(seconds: 60)), '1 min');
      expect(
        formatCompactDuration(const Duration(minutes: 6, seconds: 2)),
        '6 min',
      );
    });

    test('hours and minutes', () {
      expect(formatCompactDuration(const Duration(minutes: 60)), '1 h');
      expect(
        formatCompactDuration(const Duration(hours: 1, minutes: 5)),
        '1 h 5 min',
      );
    });
  });
}
