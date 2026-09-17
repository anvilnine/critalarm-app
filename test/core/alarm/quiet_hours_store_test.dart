import 'package:critalarm/core/alarm/quiet_hours.dart';
import 'package:critalarm/core/alarm/quiet_hours_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_alarm_host.dart';

void main() {
  late FakeAlarmHost fake;
  late SharedPreferences prefs;
  late QuietHoursStore store;

  setUp(() async {
    fake = FakeAlarmHost();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = QuietHoursStore(prefs, host: fake.host);
  });

  tearDown(() => fake.dispose());

  test('nothing saved reads back as the defaults', () {
    expect(store.read(), QuietHours.defaults);
  });

  test('what a write leaves behind is what the next read sees', () async {
    const window = QuietHours(
      isEnabled: true,
      startMinutes: 23 * 60 + 15,
      endMinutes: 6 * 60 + 45,
      criticalRingsThrough: false,
    );

    await store.write(window);

    // A second store over the same preferences is what a relaunch looks like.
    expect(QuietHoursStore(prefs).read(), window);
  });

  test('the four preference keys are the plain names', () async {
    await store.write(
      const QuietHours(
        isEnabled: false,
        startMinutes: 1,
        endMinutes: 2,
        criticalRingsThrough: true,
      ),
    );

    expect(prefs.getBool('quiet_hours_enabled'), isFalse);
    expect(prefs.getInt('quiet_hours_start_minutes'), 1);
    expect(prefs.getInt('quiet_hours_end_minutes'), 2);
    expect(prefs.getBool('quiet_hours_critical_rings'), isTrue);
  });

  test('every write hands the same window to the extension', () async {
    const window = QuietHours(
      isEnabled: true,
      startMinutes: 1320,
      endMinutes: 420,
      criticalRingsThrough: false,
    );

    await store.write(window);

    // The native side is faked here: this asserts the method name and the
    // arguments that cross the channel, not that iOS wrote the App Group.
    // `AppDelegate.handleAlarmCall` takes these four and calls
    // `QuietHours.write(_:to:)`, which is covered by the Swift test.
    expect(fake.callsTo('publishQuietHours'), hasLength(1));
    expect(fake.argsOnce('publishQuietHours'), {
      'enabled': true,
      'start_minutes': 1320,
      'end_minutes': 420,
      'critical_rings': false,
    });

    // And again on the next save, because a stale copy would ring at the
    // wrong time on the path the extension owns.
    await store.write(window.copyWith(isEnabled: false));
    expect(fake.callsTo('publishQuietHours'), hasLength(2));
    expect(
      fake.argsTo('publishQuietHours').last['enabled'],
      isFalse,
    );
  });
}
