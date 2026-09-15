import 'package:critalarm/core/alarm/alarm_build_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the quiet alarm flag', () {
    test('is off unless the build asked for it', () {
      // A store build never passes --dart-define=QUIET_ALARM=true, so a
      // critical page always rings at full volume for its full length.
      expect(buildUsesQuietAlarm, isFalse);
    });

    test('a quiet ring is short enough to test at a desk', () {
      expect(quietAlarmSeconds, lessThanOrEqualTo(10));
      expect(quietAlarmSeconds, greaterThan(0));
    });
  });
}
