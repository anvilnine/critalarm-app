import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RingClaim.forPhone', () {
    test('iOS 26 with AlarmKit authorised rings through silent mode', () {
      expect(
        RingClaim.forPhone(
          AlarmAuthorization.authorized,
          platform: TargetPlatform.iOS,
          isWeb: false,
        ),
        RingClaim.alarm,
      );
    });

    test('iOS 16 to 25 is a Time-Sensitive notification', () {
      expect(
        RingClaim.forPhone(
          AlarmAuthorization.unsupported,
          platform: TargetPlatform.iOS,
          isWeb: false,
        ),
        RingClaim.timeSensitive,
      );
    });

    test('Android answers unsupported too and keeps the full-screen alarm', () {
      expect(
        RingClaim.forPhone(
          AlarmAuthorization.unsupported,
          platform: TargetPlatform.android,
          isWeb: false,
        ),
        RingClaim.alarm,
      );
    });

    test('iOS 26 before or after the alarm ask keeps the alarm wording', () {
      for (final alarm in [
        AlarmAuthorization.notDetermined,
        AlarmAuthorization.denied,
      ]) {
        expect(
          RingClaim.forPhone(
            alarm,
            platform: TargetPlatform.iOS,
            isWeb: false,
          ),
          RingClaim.alarm,
          reason: '$alarm',
        );
      }
    });

    test('the web dashboard never gets the iOS wording', () {
      expect(
        RingClaim.forPhone(
          AlarmAuthorization.unsupported,
          platform: TargetPlatform.iOS,
          isWeb: true,
        ),
        RingClaim.alarm,
      );
    });
  });
}
