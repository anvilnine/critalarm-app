import 'package:critalarm/core/device/fold_division_switches.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_ext/foldable_ext.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // What the package starts with in a debug build: the division on. Said
  // outright, because the default is off in a release build.
  // ignore: avoid_redundant_argument_values
  const packageDefault = FoldDivisionConfig(enabled: true);

  Future<DevFoldDivisionSwitches> switchesWith(
    Map<String, Object> stored,
  ) async {
    SharedPreferences.setMockInitialValues(stored);
    return DevFoldDivisionSwitches(await SharedPreferences.getInstance());
  }

  group('DevFoldDivisionSwitches', () {
    test('every switch is off until it is set', () async {
      final switches = await switchesWith({});
      expect(switches.isOn, isFalse);
      expect(switches.staysOnFlat, isFalse);
      expect(switches.showsOverlay, isFalse);
    });

    test('a switch that was set is still set after a restart', () async {
      final switches = await switchesWith({});
      await switches.setOn(isOn: true);
      await switches.setStaysOnFlat(staysOnFlat: true);
      await switches.setShowsOverlay(showsOverlay: true);

      final again = DevFoldDivisionSwitches(
        await SharedPreferences.getInstance(),
      );
      expect(again.isOn, isTrue);
      expect(again.staysOnFlat, isTrue);
      expect(again.showsOverlay, isTrue);
    });

    test('turning a switch off removes its key', () async {
      final switches = await switchesWith({
        DevFoldDivisionSwitches.divisionKey: true,
        DevFoldDivisionSwitches.flatKey: true,
        DevFoldDivisionSwitches.overlayKey: true,
      });
      await switches.setOn(isOn: false);
      await switches.setStaysOnFlat(staysOnFlat: false);
      await switches.setShowsOverlay(showsOverlay: false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
    });

    test('tells its listeners once per change', () async {
      final switches = await switchesWith({});
      var calls = 0;
      switches.addListener(() => calls++);
      await switches.setOn(isOn: true);
      await switches.setOn(isOn: true);
      await switches.setShowsOverlay(showsOverlay: true);
      expect(calls, 2);
    });
  });

  group('foldDivisionConfigFor', () {
    test('with no switches the division is off, whatever the package '
        'started with', () {
      final config = foldDivisionConfigFor(packageDefault, null);
      expect(config.enabled, isFalse);
      expect(config.activation, DivisionActivation.followPosture);
    });

    test('with every switch off the division is off', () async {
      final config = foldDivisionConfigFor(
        packageDefault,
        await switchesWith({}),
      );
      expect(config.enabled, isFalse);
      expect(config.activation, DivisionActivation.followPosture);
    });

    test('the division switch turns it on and follows the posture', () async {
      final config = foldDivisionConfigFor(
        const FoldDivisionConfig(enabled: false),
        await switchesWith({DevFoldDivisionSwitches.divisionKey: true}),
      );
      expect(config.enabled, isTrue);
      expect(config.activation, DivisionActivation.followPosture);
    });

    test('the flat switch keeps the division on a flat device', () async {
      final config = foldDivisionConfigFor(
        packageDefault,
        await switchesWith({
          DevFoldDivisionSwitches.divisionKey: true,
          DevFoldDivisionSwitches.flatKey: true,
        }),
      );
      expect(config.enabled, isTrue);
      expect(config.activation, DivisionActivation.always);
    });

    test('the size and the margins of the division are kept', () {
      const base = FoldDivisionConfig(
        divisionExtent: 32,
        margins: EdgeInsets.symmetric(horizontal: 8),
      );
      final config = foldDivisionConfigFor(base, null);
      expect(config.divisionExtent, 32);
      expect(config.margins, const EdgeInsets.symmetric(horizontal: 8));
    });
  });

  group('bindFoldDivisionConfig', () {
    tearDown(() => FoldDivision.config.value = const FoldDivisionConfig());

    test('with no switches the division is off from the start', () {
      FoldDivision.config.value = packageDefault;
      bindFoldDivisionConfig(null);
      expect(FoldDivision.config.value.enabled, isFalse);
    });

    test('follows the switches from the start and on each change', () async {
      FoldDivision.config.value = packageDefault;
      final switches = await switchesWith({});
      bindFoldDivisionConfig(switches);
      expect(FoldDivision.config.value.enabled, isFalse);

      await switches.setOn(isOn: true);
      expect(FoldDivision.config.value.enabled, isTrue);
      expect(
        FoldDivision.config.value.activation,
        DivisionActivation.followPosture,
      );

      await switches.setStaysOnFlat(staysOnFlat: true);
      expect(FoldDivision.config.value.activation, DivisionActivation.always);

      await switches.setOn(isOn: false);
      expect(FoldDivision.config.value.enabled, isFalse);
    });
  });
}
