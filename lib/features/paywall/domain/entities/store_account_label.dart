import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

/// Which store account the renewal wording names.
///
/// Apple review guideline 3.1.2 wants the renewal sentence to say where the
/// money comes from, and the two stores call that place different things. One
/// pure function so the paywall never branches on the platform inline, and so
/// a test can check both answers without a device.
String storeAccountLabelFor(TargetPlatform platform) {
  switch (platform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return LocaleKeys.paywall_store_apple.tr();
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return LocaleKeys.paywall_store_google.tr();
  }
}
