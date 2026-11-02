import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:critalarm/core/platform/device_word.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

PlatformCapabilities _native(TargetPlatform platform) =>
    PlatformCapabilities(isWeb: false, platform: platform);

PlatformCapabilities _web(TargetPlatform platform) =>
    PlatformCapabilities(isWeb: true, platform: platform);

class _FakeIos extends Fake implements IosDeviceInfo {
  _FakeIos(this.model);

  @override
  final String model;
}

class _FakeAndroid extends Fake implements AndroidDeviceInfo {
  _FakeAndroid(this.systemFeatures);

  @override
  final List<String> systemFeatures;
}

class _FakePlugin extends Fake implements DeviceInfoPlugin {
  _FakePlugin(this.info);

  final BaseDeviceInfo info;

  @override
  Future<BaseDeviceInfo> get deviceInfo async => info;
}

void main() {
  group('deviceWordFor', () {
    test('an iPhone is a phone', () {
      expect(
        deviceWordFor(
          capabilities: _native(TargetPlatform.iOS),
          isIpad: false,
          shortSide: 440,
        ),
        DeviceWord.phone,
      );
    });

    test('an unfolded iPhone Duo, as wide as an iPad, is still a phone', () {
      expect(
        deviceWordFor(
          capabilities: _native(TargetPlatform.iOS),
          isIpad: false,
          shortSide: 700,
        ),
        DeviceWord.phone,
      );
    });

    test('an iPad is an iPad, in a narrow split view too', () {
      for (final side in [1032.0, 320.0]) {
        expect(
          deviceWordFor(
            capabilities: _native(TargetPlatform.iOS),
            isIpad: true,
            shortSide: side,
          ),
          DeviceWord.ipad,
          reason: '$side',
        );
      }
    });

    test('an Android phone is a phone', () {
      expect(
        deviceWordFor(
          capabilities: _native(TargetPlatform.android),
          isIpad: false,
          shortSide: 411,
        ),
        DeviceWord.phone,
      );
    });

    test('an Android tablet is a tablet from 600 dp', () {
      expect(
        deviceWordFor(
          capabilities: _native(TargetPlatform.android),
          isIpad: false,
          shortSide: 600,
        ),
        DeviceWord.tablet,
      );
      expect(
        deviceWordFor(
          capabilities: _native(TargetPlatform.android),
          isIpad: false,
          shortSide: 599,
        ),
        DeviceWord.phone,
      );
    });

    test('an open Android foldable is a phone', () {
      expect(
        deviceWordFor(
          capabilities: _native(TargetPlatform.android),
          isIpad: false,
          shortSide: 673,
          isFoldable: true,
        ),
        DeviceWord.phone,
      );
    });

    test('the Mac app is a computer', () {
      expect(
        deviceWordFor(
          capabilities: _native(TargetPlatform.macOS),
          isIpad: false,
          shortSide: 900,
        ),
        DeviceWord.computer,
      );
    });

    test('a Windows or Linux build is a computer', () {
      for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
        expect(
          deviceWordFor(
            capabilities: _native(platform),
            isIpad: false,
            shortSide: 900,
          ),
          DeviceWord.computer,
          reason: platform.name,
        );
      }
    });

    test('Fuchsia, which nothing ships for, keeps the phone word', () {
      expect(
        deviceWordFor(
          capabilities: _native(TargetPlatform.fuchsia),
          isIpad: false,
          shortSide: 900,
        ),
        DeviceWord.phone,
      );
    });

    test('the web app on a computer is a computer, however narrow', () {
      for (final platform in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        for (final side in [1440.0, 400.0]) {
          expect(
            deviceWordFor(
              capabilities: _web(platform),
              isIpad: false,
              shortSide: side,
            ),
            DeviceWord.computer,
            reason: '${platform.name} $side',
          );
        }
      }
    });

    test('the web app on a phone is a phone', () {
      for (final platform in [
        TargetPlatform.iOS,
        TargetPlatform.android,
        TargetPlatform.fuchsia,
      ]) {
        expect(
          deviceWordFor(
            capabilities: _web(platform),
            isIpad: false,
            shortSide: 390,
          ),
          DeviceWord.phone,
          reason: platform.name,
        );
      }
    });

    test('the web app on an iPad is an iPad, on an Android tablet a '
        'tablet', () {
      expect(
        deviceWordFor(
          capabilities: _web(TargetPlatform.iOS),
          isIpad: false,
          shortSide: 820,
        ),
        DeviceWord.ipad,
      );
      expect(
        deviceWordFor(
          capabilities: _web(TargetPlatform.android),
          isIpad: false,
          shortSide: 800,
        ),
        DeviceWord.tablet,
      );
    });
  });

  test('isIpadModel names an iPad only', () {
    expect(isIpadModel('iPad'), isTrue);
    expect(isIpadModel('iPhone'), isFalse);
    expect(isIpadModel('iPod touch'), isFalse);
  });

  test('hasFoldFeature counts a fold or a hinge in any posture', () {
    DisplayFeature feature(
      DisplayFeatureType type,
      DisplayFeatureState state,
    ) => DisplayFeature(
      bounds: const Rect.fromLTWH(400, 0, 0, 800),
      type: type,
      state: state,
    );

    expect(hasFoldFeature(const []), isFalse);
    expect(
      hasFoldFeature([
        feature(DisplayFeatureType.cutout, DisplayFeatureState.unknown),
      ]),
      isFalse,
    );
    expect(
      hasFoldFeature([
        feature(DisplayFeatureType.fold, DisplayFeatureState.postureFlat),
      ]),
      isTrue,
    );
    expect(
      hasFoldFeature([
        feature(DisplayFeatureType.hinge, DisplayFeatureState.unknown),
      ]),
      isTrue,
    );
  });

  group('readDeviceWord', () {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final dispatcher = binding.platformDispatcher;

    tearDown(() {
      dispatcher.implicitView!.resetPhysicalSize();
      dispatcher.implicitView!.resetDevicePixelRatio();
      for (final display in dispatcher.displays) {
        display
          ..resetSize()
          ..resetDevicePixelRatio();
      }
    });

    void screen(double width, double height) {
      dispatcher.implicitView!
        ..physicalSize = Size(width * 2, height * 2)
        ..devicePixelRatio = 2;
      for (final display in dispatcher.displays) {
        display
          ..size = Size(width * 2, height * 2)
          ..devicePixelRatio = 2;
      }
    }

    test('an iPad model is an iPad', () async {
      screen(1032, 1376);
      final word = await readDeviceWord(
        capabilities: _native(TargetPlatform.iOS),
        dispatcher: dispatcher,
        plugin: _FakePlugin(_FakeIos('iPad')),
      );
      expect(word, DeviceWord.ipad);
    });

    test('an iPhone model is a phone', () async {
      screen(440, 956);
      final word = await readDeviceWord(
        capabilities: _native(TargetPlatform.iOS),
        dispatcher: dispatcher,
        plugin: _FakePlugin(_FakeIos('iPhone')),
      );
      expect(word, DeviceWord.phone);
    });

    test('a wide Android screen without a hinge is a tablet', () async {
      screen(800, 1280);
      final word = await readDeviceWord(
        capabilities: _native(TargetPlatform.android),
        dispatcher: dispatcher,
        plugin: _FakePlugin(_FakeAndroid(const [])),
      );
      expect(word, DeviceWord.tablet);
    });

    test('a wide Android screen with a hinge sensor is a phone', () async {
      screen(673, 841);
      final word = await readDeviceWord(
        capabilities: _native(TargetPlatform.android),
        dispatcher: dispatcher,
        plugin: _FakePlugin(_FakeAndroid(const [androidHingeFeature])),
      );
      expect(word, DeviceWord.phone);
    });

    test(
      'with no plugin behind it an iOS device keeps the phone word',
      () async {
        screen(1032, 1376);
        final word = await readDeviceWord(
          capabilities: _native(TargetPlatform.iOS),
          dispatcher: dispatcher,
        );
        expect(word, DeviceWord.phone);
      },
    );

    test('the Mac app is a computer without asking the plugin', () async {
      screen(1280, 800);
      final word = await readDeviceWord(
        capabilities: _native(TargetPlatform.macOS),
        dispatcher: dispatcher,
        plugin: _FakePlugin(_FakeIos('iPad')),
      );
      expect(word, DeviceWord.computer);
    });
  });
}
