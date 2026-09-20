import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:flutter/foundation.dart';

/// Which paywall layout a device sees.
///
/// Firebase Remote Config picks this in a shipping build, under the key
/// `paywall_variant`, so an A/B test can move traffic between layouts without
/// shipping a new build. Every variant sells the same two products at the same
/// prices and carries the same renewal wording, restore button and legal
/// links. Only the pitch above the plan rows changes.
enum PaywallVariant {
  /// A bullet list of what the plan gives.
  straight('straight'),

  /// Free and Hosted side by side, with the numbers.
  compare('compare'),

  /// Leads with the critical topic limit, which is the wall people hit.
  oneJob('one_job'),

  /// The paywall built in the RevenueCat dashboard, drawn by their SDK
  /// instead of by this app.
  hostedTemplate('hosted_template');

  const PaywallVariant(this.key);

  /// What Remote Config and the analytics events call this variant.
  final String key;

  /// The variant a device gets when nothing else answers.
  static const PaywallVariant fallback = PaywallVariant.straight;

  /// Reads a Remote Config value. An unknown or empty string means
  /// [fallback], so a typo in the console cannot leave a device with no
  /// paywall at all.
  static PaywallVariant fromKey(String? key) {
    for (final variant in PaywallVariant.values) {
      if (variant.key == key) {
        return variant;
      }
    }
    return fallback;
  }
}

/// Lets a developer build pin the paywall to one variant.
///
/// Which override a build gets is settled when the app is compiled, the same
/// way the Force Pro override works. [appPaywallVariantOverride] picks
/// [DevPaywallVariantOverride] only when `buildHasPaywallLab` is true, and
/// that comes from `bool.fromEnvironment('PAYWALL_LAB')`. A store build is
/// compiled with [NoPaywallVariantOverride], which has nowhere to keep a
/// switch and always answers null, so Remote Config decides.
abstract interface class PaywallVariantOverride {
  /// The switch to listen to, or null when this build has no override.
  ValueListenable<PaywallVariant?>? get listenable;

  /// The variant a developer pinned, or null to let Remote Config decide.
  PaywallVariant? get forcedVariant;

  /// Starts reporting [devSwitch]. Does nothing in a build with no override.
  void watch(ValueListenable<PaywallVariant?> devSwitch);
}

/// The override a store build is compiled with. No storage, no listener,
/// always null.
class NoPaywallVariantOverride implements PaywallVariantOverride {
  const NoPaywallVariantOverride();

  @override
  ValueListenable<PaywallVariant?>? get listenable => null;

  @override
  PaywallVariant? get forcedVariant => null;

  @override
  void watch(ValueListenable<PaywallVariant?> devSwitch) {}
}

/// The override a `--dart-define=PAYWALL_LAB=true` build is compiled with.
class DevPaywallVariantOverride implements PaywallVariantOverride {
  ValueListenable<PaywallVariant?>? _devSwitch;

  @override
  ValueListenable<PaywallVariant?>? get listenable => _devSwitch;

  @override
  PaywallVariant? get forcedVariant => _devSwitch?.value;

  @override
  void watch(ValueListenable<PaywallVariant?> devSwitch) =>
      _devSwitch = devSwitch;
}

/// The override this build was compiled with. Constant condition, so a store
/// build never even holds a reference to [DevPaywallVariantOverride].
final PaywallVariantOverride appPaywallVariantOverride = buildHasPaywallLab
    ? DevPaywallVariantOverride()
    : const NoPaywallVariantOverride();
