import 'package:critalarm/core/paywall/paywall_variant.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The developer picker that pins the paywall to one layout.
///
/// Only a `--dart-define=PAYWALL_LAB=true` build ever hands this to
/// [PaywallVariantOverride]. Null means "let Remote Config decide", which is
/// what a store build always does.
class DevPaywallVariantSwitch extends ValueNotifier<PaywallVariant?> {
  DevPaywallVariantSwitch(this._prefs)
    : super(_read(_prefs.getString(_key)));

  static const _key = 'dev.paywall_variant';

  final SharedPreferences _prefs;

  static PaywallVariant? _read(String? stored) {
    if (stored == null || stored.isEmpty) return null;
    return PaywallVariant.fromKey(stored);
  }

  /// Pins the paywall to [variant], or hands it back to Remote Config when
  /// [variant] is null. Remembered across launches.
  Future<void> setVariant(PaywallVariant? variant) async {
    value = variant;
    if (variant == null) {
      await _prefs.remove(_key);
      return;
    }
    await _prefs.setString(_key, variant.key);
  }
}
