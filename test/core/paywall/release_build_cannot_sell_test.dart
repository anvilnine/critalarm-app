import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:flutter_test/flutter_test.dart';

/// `kReleaseMode` is a compile-time constant, so a test running in debug
/// cannot fake it. The composition root reads it and hands it to
/// [releaseBuildCannotSell], which is what these tests check instead.
void main() {
  group('releaseBuildCannotSell', () {
    test('a release build with no key is the one case that throws', () {
      expect(
        releaseBuildCannotSell(
          isRelease: true,
          skipsPaywall: false,
          apiKey: '',
        ),
        isTrue,
      );
    });

    test('SKIP_PAYWALL wins, so make build-quiet-apk still works', () {
      expect(
        releaseBuildCannotSell(
          isRelease: true,
          skipsPaywall: true,
          apiKey: '',
        ),
        isFalse,
      );
    });

    test('a release build with a key is fine', () {
      expect(
        releaseBuildCannotSell(
          isRelease: true,
          skipsPaywall: false,
          apiKey: 'goog_example',
        ),
        isFalse,
      );
    });

    test('debug and profile builds keep working with no key', () {
      expect(
        releaseBuildCannotSell(
          isRelease: false,
          skipsPaywall: false,
          apiKey: '',
        ),
        isFalse,
      );
    });
  });
}
