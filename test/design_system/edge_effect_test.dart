import 'package:critalarm/design_system/edge_effect.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('autoEdgeEffect', () {
    test('iOS with Impeller gets the shader blur', () {
      expect(
        autoEdgeEffect(
          platform: TargetPlatform.iOS,
          shaderSupported: true,
          isLowRamDevice: false,
        ),
        EdgeEffect.shaderBlur,
      );
    });

    test('iOS without Impeller gets the fade', () {
      expect(
        autoEdgeEffect(
          platform: TargetPlatform.iOS,
          shaderSupported: false,
          isLowRamDevice: false,
        ),
        EdgeEffect.fade,
      );
    });

    test('Android with Impeller gets the shader blur', () {
      expect(
        autoEdgeEffect(
          platform: TargetPlatform.android,
          shaderSupported: true,
          isLowRamDevice: false,
        ),
        EdgeEffect.shaderBlur,
      );
    });

    test('Android without Impeller gets the fade', () {
      expect(
        autoEdgeEffect(
          platform: TargetPlatform.android,
          shaderSupported: false,
          isLowRamDevice: false,
        ),
        EdgeEffect.fade,
      );
    });

    test('a low-RAM Android phone gets nothing', () {
      expect(
        autoEdgeEffect(
          platform: TargetPlatform.android,
          shaderSupported: true,
          isLowRamDevice: true,
        ),
        EdgeEffect.none,
      );
    });
  });
}
