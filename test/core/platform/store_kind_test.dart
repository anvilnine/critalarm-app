import 'package:critalarm/core/platform/store_kind.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StoreKind.resolve', () {
    test('each define names its store, on any platform', () {
      for (final platform in TargetPlatform.values) {
        for (final store in StoreKind.values) {
          expect(
            StoreKind.resolve(define: store.name, platform: platform),
            store,
            reason: '${store.name} on ${platform.name}',
          );
        }
      }
    });

    test('the define ignores case and spaces', () {
      expect(
        StoreKind.resolve(define: ' Huawei ', platform: TargetPlatform.android),
        StoreKind.huawei,
      );
    });

    test('no define: play on Android, apple on iPhone and Mac', () {
      expect(
        StoreKind.resolve(define: '', platform: TargetPlatform.android),
        StoreKind.play,
      );
      expect(
        StoreKind.resolve(define: '', platform: TargetPlatform.iOS),
        StoreKind.apple,
      );
      expect(
        StoreKind.resolve(define: '', platform: TargetPlatform.macOS),
        StoreKind.apple,
      );
    });

    test('no define on any other platform is play', () {
      for (final platform in [
        TargetPlatform.fuchsia,
        TargetPlatform.linux,
        TargetPlatform.windows,
      ]) {
        expect(
          StoreKind.resolve(define: '', platform: platform),
          StoreKind.play,
          reason: platform.name,
        );
      }
    });

    test('a define that names no store throws', () {
      expect(
        () => StoreKind.resolve(
          define: 'hauwei',
          platform: TargetPlatform.android,
        ),
        throwsArgumentError,
      );
    });
  });
}
