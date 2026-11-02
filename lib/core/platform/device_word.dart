import 'dart:math' as math;
import 'dart:ui'
    show DisplayFeature, DisplayFeatureType, FlutterView, PlatformDispatcher;

import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// The word the app uses for the device it runs on.
///
/// Copy that talks about this device ("This phone is online", "Phone
/// checks") names it with this word. Copy about phones in general ("every
/// phone signed in to this account") keeps "phone".
///
/// The word never goes into a sentence on its own. Each string that names
/// the device has a whole-sentence variant per word in
/// `assets/translations/*.json`, a sibling key with the word's [name] as a
/// suffix (`wake.stop_phone_ipad`), so every language words the sentence its
/// own way. `lib/core/platform/device_text.dart` swaps the variants in when
/// the translations load.
///
/// Read once at launch, in `lib/app/di.dart`, and registered in `get_it`
/// beside `PlatformCapabilities`.
enum DeviceWord {
  /// iPhones, the iPhone Duo, Android phones and Android foldables, folded or
  /// open. Also any device this file cannot place.
  phone,

  /// The iPad app.
  ipad,

  /// An Android tablet, one that does not fold.
  tablet,

  /// The Mac app, and the web app on a computer.
  computer,
}

/// The short side of the screen, in logical pixels, from which an Android
/// device is a tablet. It is the `sw600dp` line Android itself draws, and the
/// line `AppSize.mediumMinWidth` draws for layout.
const double tabletMinShortSide = 600;

/// The Android system feature only a folding device declares.
const String androidHingeFeature = 'android.hardware.sensor.hinge_angle';

/// The device word for a device with these values.
///
/// - [capabilities]: the build and the platform it runs on.
/// - [isIpad]: `UIDevice.model` names an iPad, which is what the iPad idiom
///   (`UIUserInterfaceIdiom.pad`) runs on. Only read for the iOS app.
/// - [shortSide]: the short side of the screen in logical pixels. Decides
///   phone or tablet on Android and in a browser on a phone platform.
/// - [isFoldable]: an Android device that folds. It stays a phone when it is
///   open, though its open screen is as wide as a tablet's.
///
/// A browser on an iPhone or an Android phone is a phone, one on an iPad an
/// iPad, one on an Android tablet a tablet. A browser on any other platform
/// runs on a computer.
DeviceWord deviceWordFor({
  required PlatformCapabilities capabilities,
  required bool isIpad,
  required double shortSide,
  bool isFoldable = false,
}) {
  final isWide = shortSide >= tabletMinShortSide;
  if (capabilities.isWeb) {
    return switch (capabilities.platform) {
      TargetPlatform.iOS => isWide ? DeviceWord.ipad : DeviceWord.phone,
      TargetPlatform.android => isWide ? DeviceWord.tablet : DeviceWord.phone,
      TargetPlatform.fuchsia => DeviceWord.phone,
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => DeviceWord.computer,
    };
  }
  return switch (capabilities.platform) {
    TargetPlatform.iOS => isIpad ? DeviceWord.ipad : DeviceWord.phone,
    TargetPlatform.android =>
      isWide && !isFoldable ? DeviceWord.tablet : DeviceWord.phone,
    TargetPlatform.fuchsia => DeviceWord.phone,
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux => DeviceWord.computer,
  };
}

/// True when `UIDevice.model` names an iPad. iOS answers "iPhone", "iPad"
/// or "iPod touch", and the simulator answers the same as the device.
bool isIpadModel(String model) => model.toLowerCase().startsWith('ipad');

/// Whether [features] hold a fold or a hinge, in any posture.
bool hasFoldFeature(Iterable<DisplayFeature> features) => features.any(
  (f) =>
      f.type == DisplayFeatureType.fold || f.type == DisplayFeatureType.hinge,
);

/// The short side of the screen in logical pixels: the larger of the
/// display's and the app window's, so a split screen or a window that has
/// not been laid out yet does not make a tablet a phone. Zero when neither
/// is known.
double screenShortSide(PlatformDispatcher dispatcher) {
  var side = 0.0;
  for (final display in dispatcher.displays) {
    if (display.devicePixelRatio > 0) {
      side = math.max(
        side,
        (display.size / display.devicePixelRatio).shortestSide,
      );
    }
  }
  final view = _appView(dispatcher);
  if (view != null && view.devicePixelRatio > 0) {
    side = math.max(
      side,
      (view.physicalSize / view.devicePixelRatio).shortestSide,
    );
  }
  return side;
}

FlutterView? _appView(PlatformDispatcher dispatcher) =>
    dispatcher.implicitView ??
    (dispatcher.views.isEmpty ? null : dispatcher.views.first);

/// Reads the [DeviceWord] for the running device, once, at launch.
///
/// Asks `device_info_plus` for the iPhone or iPad model and for Android's
/// hinge sensor, and [dispatcher] for the screen. Anything that goes wrong,
/// including a test with no plugin behind it, counts as "not an iPad" and
/// "does not fold", which keeps the phone's words.
Future<DeviceWord> readDeviceWord({
  required PlatformCapabilities capabilities,
  required PlatformDispatcher dispatcher,
  DeviceInfoPlugin? plugin,
}) async {
  var isIpad = false;
  var isFoldable = false;
  final asksPlugin =
      !capabilities.isWeb &&
      (capabilities.platform == TargetPlatform.iOS ||
          capabilities.platform == TargetPlatform.android);
  if (asksPlugin) {
    try {
      final info = await (plugin ?? DeviceInfoPlugin()).deviceInfo;
      isIpad = info is IosDeviceInfo && isIpadModel(info.model);
      isFoldable =
          info is AndroidDeviceInfo &&
          info.systemFeatures.contains(androidHingeFeature);
    } on Object {
      // Keeps the phone's words.
    }
  }
  final view = _appView(dispatcher);
  return deviceWordFor(
    capabilities: capabilities,
    isIpad: isIpad,
    shortSide: screenShortSide(dispatcher),
    isFoldable:
        isFoldable || (view != null && hasFoldFeature(view.displayFeatures)),
  );
}
