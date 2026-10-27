import 'package:critalarm/core/alarm/alarm_signals.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';

void main() {
  const signals = AlarmSignals(
    flashTopics: {'flash-only', 'both'},
    vibrationTopics: {'vibration-only', 'both'},
  );

  group('ringSignalsFor', () {
    test('nothing ringing runs nothing', () {
      expect(
        ringSignalsFor(ringingTopics: const [], signals: signals),
        RingSignals.none,
      );
    });

    test('one ringing topic with both off runs nothing', () {
      expect(
        ringSignalsFor(ringingTopics: const ['plain'], signals: signals),
        RingSignals.none,
      );
    });

    test('one ringing topic runs what that topic has on', () {
      expect(
        ringSignalsFor(ringingTopics: const ['flash-only'], signals: signals),
        const RingSignals(flash: true, vibration: false),
      );
      expect(
        ringSignalsFor(
          ringingTopics: const ['vibration-only'],
          signals: signals,
        ),
        const RingSignals(flash: false, vibration: true),
      );
      expect(
        ringSignalsFor(ringingTopics: const ['both'], signals: signals),
        const RingSignals(flash: true, vibration: true),
      );
    });

    test('several ringing topics run each one that any of them has on', () {
      expect(
        ringSignalsFor(
          ringingTopics: const ['plain', 'flash-only'],
          signals: signals,
        ),
        const RingSignals(flash: true, vibration: false),
      );
      expect(
        ringSignalsFor(
          ringingTopics: const ['flash-only', 'vibration-only'],
          signals: signals,
        ),
        const RingSignals(flash: true, vibration: true),
      );
    });

    test('a second alarm with both off does not take them away', () {
      expect(
        ringSignalsFor(
          ringingTopics: const ['both', 'plain'],
          signals: signals,
        ),
        const RingSignals(flash: true, vibration: true),
      );
    });

    test('several ringing topics with both off run nothing', () {
      expect(
        ringSignalsFor(
          ringingTopics: const ['plain', 'other'],
          signals: signals,
        ),
        RingSignals.none,
      );
    });

    test('no switch on anywhere runs nothing', () {
      expect(
        ringSignalsFor(
          ringingTopics: const ['both'],
          signals: const AlarmSignals(),
        ),
        RingSignals.none,
      );
    });
  });

  group('flashingTopicsFor', () {
    test('keeps the ringing topics with the flash on, once each', () {
      expect(
        flashingTopicsFor(
          ringingTopics: const ['plain', 'both', 'vibration-only', 'both'],
          signals: signals,
        ),
        ['both'],
      );
    });

    test('is empty when no ringing topic has the flash on', () {
      expect(
        flashingTopicsFor(
          ringingTopics: const ['plain', 'vibration-only'],
          signals: signals,
        ),
        isEmpty,
      );
      expect(
        flashingTopicsFor(ringingTopics: const [], signals: signals),
        isEmpty,
      );
    });
  });

  group('alarmSignalRowsFor', () {
    const android = PlatformCapabilities(
      isWeb: false,
      platform: TargetPlatform.android,
    );
    const iphone = PlatformCapabilities(
      isWeb: false,
      platform: TargetPlatform.iOS,
    );
    const webOnAndroid = PlatformCapabilities(
      isWeb: true,
      platform: TargetPlatform.android,
    );
    const webOnIphone = PlatformCapabilities(
      isWeb: true,
      platform: TargetPlatform.iOS,
    );

    test('Android with a flash shows both rows', () {
      expect(
        alarmSignalRowsFor(
          capabilities: android,
          hasTorch: true,
          critical: true,
        ),
        const AlarmSignalRows(
          flash: true,
          strongVibration: true,
          flashNeedsAlarmScreen: false,
        ),
      );
    });

    test('Android with no flash shows the vibration row only', () {
      final rows = alarmSignalRowsFor(
        capabilities: android,
        hasTorch: false,
        critical: true,
      );

      expect(rows.flash, isFalse);
      expect(rows.strongVibration, isTrue);
    });

    test('iPhone shows the flash row only, tied to the alarm screen', () {
      expect(
        alarmSignalRowsFor(
          capabilities: iphone,
          hasTorch: true,
          critical: true,
        ),
        const AlarmSignalRows(
          flash: true,
          strongVibration: false,
          flashNeedsAlarmScreen: true,
        ),
      );
    });

    test('an iPhone or iPad with no flash shows neither row', () {
      final rows = alarmSignalRowsFor(
        capabilities: iphone,
        hasTorch: false,
        critical: true,
      );

      expect(rows.any, isFalse);
    });

    test('a topic that is not critical shows neither row anywhere', () {
      for (final capabilities in [android, iphone]) {
        expect(
          alarmSignalRowsFor(
            capabilities: capabilities,
            hasTorch: true,
            critical: false,
          ),
          AlarmSignalRows.none,
        );
      }
    });

    test('the web build shows neither row, whatever it is told', () {
      for (final capabilities in [webOnAndroid, webOnIphone]) {
        expect(
          alarmSignalRowsFor(
            capabilities: capabilities,
            hasTorch: true,
            critical: true,
          ),
          AlarmSignalRows.none,
        );
      }
    });
  });
}
