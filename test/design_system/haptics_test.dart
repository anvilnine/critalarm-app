import 'package:critalarm/design_system/haptics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> pulses;

  setUp(() {
    pulses = [];
    AppHaptics.userEnabled = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            pulses.add('${call.arguments}'.split('.').last);
          }
          return null;
        });
  });

  tearDown(() {
    AppHaptics.cancelPattern();
    AppHaptics.userEnabled = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('the patterns', () {
    test('none is like an alarm: three pulses at most, and soon over', () {
      for (final pattern in HapticPattern.values) {
        expect(
          pattern.steps.length,
          lessThanOrEqualTo(HapticPattern.maxPulses),
          reason: pattern.name,
        );
        if (pattern.steps.isEmpty) continue;
        expect(pattern.steps.first.atMs, 0, reason: pattern.name);
        expect(
          Duration(milliseconds: pattern.steps.last.atMs),
          lessThanOrEqualTo(HapticPattern.maxSpan),
          reason: pattern.name,
        );
      }
      expect(HapticPattern.maxPulses, 3);
      expect(
        HapticPattern.maxSpan,
        lessThan(const Duration(milliseconds: 500)),
      );
    });

    test('the pulses come in order, never two at once', () {
      for (final pattern in HapticPattern.values) {
        for (var i = 1; i < pattern.steps.length; i++) {
          expect(
            pattern.steps[i].atMs - pattern.steps[i - 1].atMs,
            greaterThanOrEqualTo(60),
            reason: pattern.name,
          );
        }
      }
    });

    test('the shapes are what their names say', () {
      List<HapticPulse> of(HapticPattern pattern) =>
          pattern.steps.map((step) => step.pulse).toList();
      expect(of(HapticPattern.none), isEmpty);
      expect(of(HapticPattern.light), [HapticPulse.light]);
      expect(of(HapticPattern.medium), [HapticPulse.medium]);
      expect(of(HapticPattern.heavy), [HapticPulse.heavy]);
      expect(of(HapticPattern.doubleKnock), [
        HapticPulse.medium,
        HapticPulse.medium,
      ]);
      expect(of(HapticPattern.tripleFade), [
        HapticPulse.heavy,
        HapticPulse.medium,
        HapticPulse.light,
      ]);
      expect(of(HapticPattern.risingPair), [
        HapticPulse.light,
        HapticPulse.medium,
      ]);
    });
  });

  // These run on the real clock. A pattern is over in under a third of a
  // second, so waiting for one costs nothing.
  Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  group('playing a pattern', () {
    test('each pulse goes out at its time', () async {
      AppHaptics.play(HapticPattern.tripleFade);
      await wait(40);
      expect(pulses, ['heavyImpact']);
      await wait(180);
      expect(pulses, ['heavyImpact', 'mediumImpact']);
      await wait(120);
      expect(pulses, ['heavyImpact', 'mediumImpact', 'lightImpact']);
      await wait(300);
      expect(pulses, hasLength(3));
    });

    test('a single pattern maps to the system pulse of that weight', () async {
      AppHaptics.play(HapticPattern.tick);
      AppHaptics.play(HapticPattern.light);
      AppHaptics.play(HapticPattern.medium);
      AppHaptics.play(HapticPattern.heavy);
      AppHaptics.play(HapticPattern.none);
      await wait(10);
      expect(pulses, [
        'selectionClick',
        'lightImpact',
        'mediumImpact',
        'heavyImpact',
      ]);
    });

    test('a new pattern drops what is left of the one before', () async {
      AppHaptics.play(HapticPattern.tripleFade);
      await wait(40);
      AppHaptics.play(HapticPattern.light);
      await wait(400);
      expect(pulses, ['heavyImpact', 'lightImpact']);
    });

    test('cancel drops the pulses still to come', () async {
      AppHaptics.play(HapticPattern.doubleKnock);
      await wait(20);
      AppHaptics.cancelPattern();
      await wait(300);
      expect(pulses, ['mediumImpact']);
    });

    test('the Haptics switch off means nothing, even mid pattern', () async {
      AppHaptics.userEnabled = false;
      AppHaptics.play(HapticPattern.heavy);
      await wait(10);
      expect(pulses, isEmpty);

      AppHaptics.userEnabled = true;
      AppHaptics.play(HapticPattern.doubleKnock);
      await wait(10);
      AppHaptics.userEnabled = false;
      await wait(300);
      expect(pulses, ['mediumImpact']);
    });
  });
}
