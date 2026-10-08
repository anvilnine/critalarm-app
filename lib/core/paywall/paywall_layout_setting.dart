import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:critalarm/core/paywall/paywall_intro.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What one product's paywall is set to open: the surface that ships today,
/// a layout picked by entry point, or one named layout.
///
/// Remote Config holds one of these per product, as a string, under
/// `paywall_layout` (Hosted) and `pro_paywall_layout` (Pro). The intro that
/// plays first is a second value beside it: see `PaywallIntroId`.
@immutable
final class PaywallLayoutSetting {
  const PaywallLayoutSetting._(this._key, this.layout);

  /// Pins every entry point to [layout].
  const PaywallLayoutSetting.pinned(PaywallLayoutId this.layout) : _key = null;

  /// Reads a Remote Config value. Empty means [shipped], and so does a
  /// value this build does not know, so a typo in the console cannot leave
  /// a device with no paywall.
  factory PaywallLayoutSetting.parse(String? value) {
    final key = value?.trim() ?? '';
    if (key == autoKey) return auto;
    // The joke was a layout once. Its key still opens `hero`, and
    // [paywallIntroInLayoutValue] reads the intro out of the same value.
    if (key == paywallFalseAlarmLayoutKey) {
      return const PaywallLayoutSetting.pinned(PaywallLayoutId.hero);
    }
    final layout = PaywallLayoutId.fromKey(key);
    return layout == null ? shipped : PaywallLayoutSetting.pinned(layout);
  }

  /// The surface that ships today. What an empty value means.
  static const shipped = PaywallLayoutSetting._(_shippedKey, null);

  /// A layout picked by what opened the paywall.
  static const auto = PaywallLayoutSetting._(autoKey, null);

  /// The remote value that picks by entry point.
  static const String autoKey = 'auto';

  /// Only the developer control saves this word. The remote value for the
  /// shipped surface is the empty string.
  static const String _shippedKey = 'shipped';

  final String? _key;

  /// The pinned layout, or null for [shipped] and [auto].
  final PaywallLayoutId? layout;

  bool get isShipped => _key == _shippedKey;
  bool get isAuto => _key == autoKey;

  /// What the developer control saves for this setting.
  String get storedKey => layout?.key ?? _key!;

  /// Reads what the developer control saved. Null, for nothing saved or a
  /// word this build does not know, means "follow the remote value".
  static PaywallLayoutSetting? fromStored(String? stored) {
    if (stored == null || stored.isEmpty) return null;
    if (stored == _shippedKey) return shipped;
    final setting = PaywallLayoutSetting.parse(stored);
    return setting.isShipped ? null : setting;
  }

  @override
  bool operator ==(Object other) =>
      other is PaywallLayoutSetting &&
      other._key == _key &&
      other.layout == layout;

  @override
  int get hashCode => Object.hash(_key, layout);

  @override
  String toString() => 'PaywallLayoutSetting($storedKey)';
}

/// The developer control for one product: follow the remote value (null),
/// or one setting that outranks it. Saved in prefs under [_key].
class DevPaywallLayoutSwitch extends ValueNotifier<PaywallLayoutSetting?> {
  DevPaywallLayoutSwitch(this._prefs, this._key)
    : super(PaywallLayoutSetting.fromStored(_prefs.getString(_key)));

  static const hostedKey = 'dev.paywall_layout';
  static const proKey = 'dev.pro_paywall_layout';

  final SharedPreferences _prefs;
  final String _key;

  /// Sets what outranks the remote value, or hands the choice back to it
  /// when [setting] is null. Remembered across launches.
  Future<void> setSetting(PaywallLayoutSetting? setting) async {
    value = setting;
    if (setting == null) {
      await _prefs.remove(_key);
      return;
    }
    await _prefs.setString(_key, setting.storedKey);
  }
}

/// The developer control for one product's intro: follow the remote value
/// (null), or one intro that outranks it, `none` among them. Saved in prefs
/// under [_key].
class DevPaywallIntroSwitch extends ValueNotifier<PaywallIntroId?> {
  DevPaywallIntroSwitch(this._prefs, this._key)
    : super(PaywallIntroId.fromKey(_prefs.getString(_key)));

  static const hostedKey = 'dev.paywall_intro';
  static const proKey = 'dev.pro_paywall_intro';

  final SharedPreferences _prefs;
  final String _key;

  /// Sets what outranks the remote value, or hands the choice back to it
  /// when [intro] is null. Remembered across launches.
  Future<void> setIntro(PaywallIntroId? intro) async {
    value = intro;
    if (intro == null) {
      await _prefs.remove(_key);
      return;
    }
    await _prefs.setString(_key, intro.key);
  }
}

/// The developer controls, a layout and an intro per product.
class DevPaywallLayoutSwitches {
  const DevPaywallLayoutSwitches({
    required this.hosted,
    required this.pro,
    required this.hostedIntro,
    required this.proIntro,
  });

  final DevPaywallLayoutSwitch hosted;
  final DevPaywallLayoutSwitch pro;
  final DevPaywallIntroSwitch hostedIntro;
  final DevPaywallIntroSwitch proIntro;
}

/// Lets a developer build choose what each product's paywall opens.
///
/// Settled when the app is compiled, the same way the paywall variant
/// override is. A store build is compiled with [NoPaywallLayoutOverride],
/// which has nowhere to keep a switch and always answers null, so the
/// remote value decides.
abstract interface class PaywallLayoutOverride {
  /// What a developer set for Hosted, or null to follow the remote value.
  PaywallLayoutSetting? get hosted;

  /// The same for Pro.
  PaywallLayoutSetting? get pro;

  /// The intro a developer set for Hosted, or null to follow the remote
  /// value.
  PaywallIntroId? get hostedIntro;

  /// The same for Pro.
  PaywallIntroId? get proIntro;

  /// Starts reporting the switches. Does nothing in a build with no
  /// override.
  void watch({
    required ValueListenable<PaywallLayoutSetting?> hosted,
    required ValueListenable<PaywallLayoutSetting?> pro,
    ValueListenable<PaywallIntroId?>? hostedIntro,
    ValueListenable<PaywallIntroId?>? proIntro,
  });
}

/// The override a store build is compiled with. No storage, always null.
class NoPaywallLayoutOverride implements PaywallLayoutOverride {
  const NoPaywallLayoutOverride();

  @override
  PaywallLayoutSetting? get hosted => null;

  @override
  PaywallLayoutSetting? get pro => null;

  @override
  PaywallIntroId? get hostedIntro => null;

  @override
  PaywallIntroId? get proIntro => null;

  @override
  void watch({
    required ValueListenable<PaywallLayoutSetting?> hosted,
    required ValueListenable<PaywallLayoutSetting?> pro,
    ValueListenable<PaywallIntroId?>? hostedIntro,
    ValueListenable<PaywallIntroId?>? proIntro,
  }) {}
}

/// The override a build with Developer options is compiled with.
class DevPaywallLayoutOverride implements PaywallLayoutOverride {
  ValueListenable<PaywallLayoutSetting?>? _hosted;
  ValueListenable<PaywallLayoutSetting?>? _pro;
  ValueListenable<PaywallIntroId?>? _hostedIntro;
  ValueListenable<PaywallIntroId?>? _proIntro;

  @override
  PaywallLayoutSetting? get hosted => _hosted?.value;

  @override
  PaywallLayoutSetting? get pro => _pro?.value;

  @override
  PaywallIntroId? get hostedIntro => _hostedIntro?.value;

  @override
  PaywallIntroId? get proIntro => _proIntro?.value;

  @override
  void watch({
    required ValueListenable<PaywallLayoutSetting?> hosted,
    required ValueListenable<PaywallLayoutSetting?> pro,
    ValueListenable<PaywallIntroId?>? hostedIntro,
    ValueListenable<PaywallIntroId?>? proIntro,
  }) {
    _hosted = hosted;
    _pro = pro;
    _hostedIntro = hostedIntro;
    _proIntro = proIntro;
  }
}

/// Whether this build has Developer options, and so the layout controls.
/// Both dart-defines are compile-time constants.
const bool buildHasPaywallLayoutSwitch =
    buildSkipsPaywall || buildHasPaywallLab;

/// The override this build was compiled with. Constant condition, so a store
/// build never even holds a reference to [DevPaywallLayoutOverride].
final PaywallLayoutOverride appPaywallLayoutOverride =
    buildHasPaywallLayoutSwitch
    ? DevPaywallLayoutOverride()
    : const NoPaywallLayoutOverride();
