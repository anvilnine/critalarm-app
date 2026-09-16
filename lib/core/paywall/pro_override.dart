import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:flutter/foundation.dart';

/// Lets a developer build pretend the device is on a paid plan.
///
/// Access in a shipping build comes from registration and nothing else:
/// `AccountAccess` reads the tier the server gave this device. This override
/// is a convenience for builds that already skip the paywall, so whoever is
/// testing can look at the Pro screens without buying. It is not a second way
/// to be paid.
///
/// Which override a build gets is settled when the app is compiled, not while
/// it runs. [appProOverride] picks [DevProOverride] only when
/// `buildSkipsPaywall` is true, and that comes from
/// `bool.fromEnvironment('SKIP_PAYWALL')`, a compile-time constant. A store
/// build is compiled with [NoProOverride], which has nowhere to keep a switch
/// and answers false to everything. Calling [watch] on it, from here or from
/// some later edit, still does nothing.
abstract interface class ProOverride {
  /// The switch to listen to, or null when this build has no override.
  ValueListenable<bool>? get listenable;

  /// True while a developer has forced the app into Pro.
  bool get isForcingPro;

  /// Starts reporting [devSwitch]. Does nothing in a build with no override.
  void watch(ValueListenable<bool> devSwitch);
}

/// The override a store build is compiled with. No storage, no listener,
/// always false.
class NoProOverride implements ProOverride {
  const NoProOverride();

  @override
  ValueListenable<bool>? get listenable => null;

  @override
  bool get isForcingPro => false;

  @override
  void watch(ValueListenable<bool> devSwitch) {}
}

/// The override a `--dart-define=SKIP_PAYWALL=true` build is compiled with.
class DevProOverride implements ProOverride {
  ValueListenable<bool>? _devSwitch;

  @override
  ValueListenable<bool>? get listenable => _devSwitch;

  @override
  bool get isForcingPro => _devSwitch?.value ?? false;

  @override
  void watch(ValueListenable<bool> devSwitch) => _devSwitch = devSwitch;
}

/// The override this build was compiled with. Constant condition, so a store
/// build never even holds a reference to [DevProOverride].
final ProOverride appProOverride = buildSkipsPaywall
    ? DevProOverride()
    : const NoProOverride();
