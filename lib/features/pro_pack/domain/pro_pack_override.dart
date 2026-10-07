import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:flutter/foundation.dart';

/// The switch in Developer options that makes this install hold the Pro
/// pack. Only a build that skips the store has one.
abstract class ProPackDevSwitch implements ValueListenable<bool> {
  /// Holds or drops the pack and remembers the choice across launches.
  Future<void> setHeld({required bool isHeld});
}

/// Lets a developer build act as if the install holds the Pro pack.
///
/// In a build anyone can install, the pack comes from the relay and nothing
/// else. Which override a build gets is settled when it is compiled:
/// [appProPackOverride] picks [DevProPackOverride] only when
/// `buildSkipsPaywall` is true, a compile-time constant. A store build is
/// compiled with [NoProPackOverride], which has nowhere to keep a switch.
abstract interface class ProPackOverride {
  /// The switch to listen to, or null when this build has no override.
  ValueListenable<bool>? get listenable;

  /// True while a developer has switched the pack on.
  bool get isForcing;

  /// Starts reporting [devSwitch]. Does nothing in a build with no override.
  void watch(ValueListenable<bool> devSwitch);
}

/// The override a store build is compiled with. Always false.
class NoProPackOverride implements ProPackOverride {
  const NoProPackOverride();

  @override
  ValueListenable<bool>? get listenable => null;

  @override
  bool get isForcing => false;

  @override
  void watch(ValueListenable<bool> devSwitch) {}
}

/// The override a `--dart-define=SKIP_PAYWALL=true` build is compiled with.
class DevProPackOverride implements ProPackOverride {
  ValueListenable<bool>? _devSwitch;

  @override
  ValueListenable<bool>? get listenable => _devSwitch;

  @override
  bool get isForcing => _devSwitch?.value ?? false;

  @override
  void watch(ValueListenable<bool> devSwitch) => _devSwitch = devSwitch;
}

/// The override this build was compiled with.
final ProPackOverride appProPackOverride = buildSkipsPaywall
    ? DevProPackOverride()
    : const NoProPackOverride();
