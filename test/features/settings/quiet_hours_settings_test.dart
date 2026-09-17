import 'package:critalarm/core/alarm/quiet_hours.dart';
import 'package:critalarm/core/alarm/quiet_hours_store.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late QuietHoursStore store;

  SettingsCubit build() => SettingsCubit(quietHoursStore: store);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = QuietHoursStore(prefs);
  });

  test('a cubit with nothing saved loads the defaults', () async {
    final cubit = build();
    await cubit.load();

    expect(cubit.state.quietHoursEnabled, QuietHours.defaults.isEnabled);
    expect(
      cubit.state.quietHoursStartMinutes,
      QuietHours.defaults.startMinutes,
    );
    expect(cubit.state.quietHoursEndMinutes, QuietHours.defaults.endMinutes);
    expect(
      cubit.state.criticalRingsQuietHours,
      QuietHours.defaults.criticalRingsThrough,
    );
    await cubit.close();
  });

  test('all four values survive a fresh cubit', () async {
    // The cubit is a factory, so leaving the screen throws the old one away.
    final first = build();
    await first.load();
    await first.toggleQuietHours(isEnabled: false);
    await first.toggleCriticalRingsQuietHours(isEnabled: false);
    await first.setQuietHoursWindow(
      startMinutes: 23 * 60 + 15,
      endMinutes: 6 * 60 + 45,
    );
    await first.close();

    final second = build();
    await second.load();

    expect(second.state.quietHoursEnabled, isFalse);
    expect(second.state.criticalRingsQuietHours, isFalse);
    expect(second.state.quietHoursStartMinutes, 23 * 60 + 15);
    expect(second.state.quietHoursEndMinutes, 6 * 60 + 45);
    await second.close();
  });

  test('the store holds what the screen shows', () async {
    final cubit = build();
    await cubit.load();
    await cubit.setQuietHoursWindow(startMinutes: 60, endMinutes: 300);
    await cubit.toggleQuietHours(isEnabled: true);

    expect(
      store.read(),
      const QuietHours(
        isEnabled: true,
        startMinutes: 60,
        endMinutes: 300,
        criticalRingsThrough: true,
      ),
    );
    await cubit.close();
  });

  test('a cubit with no store still moves the three controls', () async {
    final cubit = SettingsCubit();
    await cubit.toggleQuietHours(isEnabled: false);
    await cubit.setQuietHoursWindow(startMinutes: 0, endMinutes: 30);

    expect(cubit.state.quietHoursEnabled, isFalse);
    expect(cubit.state.quietHoursStartMinutes, 0);
    expect(cubit.state.quietHoursEndMinutes, 30);
    await cubit.close();
  });
}
