import 'package:critalarm/core/device/dev_bar_backing_switch.dart';
import 'package:critalarm/design_system/bar_backing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final tuned = BarBackingConfig(
    top: BarBackingStyle(
      mode: BarBackingMode.blur,
      blurSigma: 24,
      fadeLength: 48,
      gradientPeak: 0.4,
    ),
    bottom: BarBackingConfig.defaults.bottom.copyWith(
      mode: BarBackingMode.gradient,
      gradientPeak: 0.85,
    ),
  );

  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  test('starts on the defaults with nothing stored', () async {
    final backing = DevBarBackingSwitch(await prefsWith({}));
    expect(backing.value, BarBackingConfig.defaults);
    expect(backing.isOverridden, isFalse);
  });

  test('a change is kept and read back by the next launch', () async {
    final prefs = await prefsWith({});
    final backing = DevBarBackingSwitch(prefs);
    await backing.setConfig(tuned);
    expect(backing.value, tuned);
    expect(backing.isOverridden, isTrue);
    expect(prefs.getString(DevBarBackingSwitch.prefsKey), tuned.encode());

    final next = DevBarBackingSwitch(prefs);
    expect(next.value, tuned);
  });

  test('tells its listeners at once', () async {
    final backing = DevBarBackingSwitch(await prefsWith({}));
    final seen = <BarBackingConfig>[];
    backing.addListener(() => seen.add(backing.value));
    await backing.setConfig(tuned);
    await backing.reset();
    expect(seen, [tuned, BarBackingConfig.defaults]);
  });

  test('reset goes back to the defaults and forgets the stored text', () async {
    final prefs = await prefsWith({
      DevBarBackingSwitch.prefsKey: tuned.encode(),
    });
    final backing = DevBarBackingSwitch(prefs);
    expect(backing.value, tuned);
    await backing.reset();
    expect(backing.value, BarBackingConfig.defaults);
    expect(prefs.containsKey(DevBarBackingSwitch.prefsKey), isFalse);
  });

  test('stored text that cannot be read is the defaults', () async {
    final backing = DevBarBackingSwitch(
      await prefsWith({DevBarBackingSwitch.prefsKey: 'solid please'}),
    );
    expect(backing.value, BarBackingConfig.defaults);
  });
}
