import 'package:critalarm/features/in_app_notices/domain/system_update_notice_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const updated = SystemUpdateReading(needsLook: true, osMajor: 27);

  bool show({
    bool isSetupDone = true,
    SystemUpdateReading? reading = updated,
    int? dismissedForMajor,
  }) => SystemUpdateNoticeRule.shouldShow(
    isSetupDone: isSetupDone,
    reading: reading,
    dismissedForMajor: dismissedForMajor,
  );

  group('SystemUpdateNoticeRule', () {
    test('shows when the phone was updated and setup is done', () {
      expect(show(), isTrue);
    });

    test('waits for SetupGate', () {
      expect(show(isSetupDone: false), isFalse);
    });

    test('shows nothing when the check is fine', () {
      expect(
        show(
          reading: const SystemUpdateReading(needsLook: false, osMajor: 27),
        ),
        isFalse,
      );
    });

    test('shows nothing when there is no reading', () {
      expect(show(reading: null), isFalse);
    });

    test('shows nothing when the OS version cannot be read', () {
      expect(
        show(
          reading: const SystemUpdateReading(needsLook: true, osMajor: null),
        ),
        isFalse,
      );
    });

    test('a dismissal holds for the same OS version', () {
      expect(show(dismissedForMajor: 27), isFalse);
    });

    test('a dismissal for an older version does not hold after an update', () {
      expect(show(dismissedForMajor: 26), isTrue);
    });
  });
}
