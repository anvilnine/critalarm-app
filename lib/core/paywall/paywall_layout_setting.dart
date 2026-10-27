import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:critalarm/core/paywall/paywall_intro.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_outro.dart';
import 'package:critalarm/core/paywall/paywall_thanks.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What one product's paywall is set to open: a layout picked by the place
/// that opened it, or one named layout.
///
/// Nothing remote holds one of these. The place table in
/// `paywall_routing.dart` is what a store build opens, and [auto] is its
/// name here. Developer options can pin one layout in its place. The intro
/// that plays first is a second value beside it: see `PaywallIntroId`. What
/// plays after a confirmed purchase is a third: see `PaywallThanksId`. The
/// outro between the two is a fourth: see `PaywallOutroId`.
@immutable
final class PaywallLayoutSetting {
  const PaywallLayoutSetting._(this.layout);

  /// Pins every entry point to [layout].
  const PaywallLayoutSetting.pinned(PaywallLayoutId this.layout);

  /// A layout picked by what opened the paywall. What a build with nothing
  /// set in Developer options opens.
  static const auto = PaywallLayoutSetting._(null);

  /// The word for [auto]. Older builds saved it, and `shipped`, from the
  /// developer control: both read as nothing saved.
  static const String autoKey = 'auto';

  /// The pinned layout, or null for [auto].
  final PaywallLayoutId? layout;

  bool get isAuto => layout == null;

  /// What the developer control saves for this setting.
  String get storedKey => layout?.key ?? autoKey;

  /// Reads what the developer control saved. Null means nothing is pinned,
  /// so the place table decides. That is the answer for nothing saved, for
  /// `auto`, for the `shipped` word an older build saved, and for a word
  /// this build does not know.
  static PaywallLayoutSetting? fromStored(String? stored) {
    final key = stored?.trim() ?? '';
    // The joke was a layout once. Its key still opens `hero`.
    if (key == paywallFalseAlarmLayoutKey) {
      return const PaywallLayoutSetting.pinned(PaywallLayoutId.hero);
    }
    final layout = PaywallLayoutId.fromKey(key);
    return layout == null ? null : PaywallLayoutSetting.pinned(layout);
  }

  @override
  bool operator ==(Object other) =>
      other is PaywallLayoutSetting && other.layout == layout;

  @override
  int get hashCode => layout.hashCode;

  @override
  String toString() => 'PaywallLayoutSetting($storedKey)';
}

/// The developer control for one product: the place table (null), or one
/// pinned layout that outranks it. Saved in prefs under [_key].
class DevPaywallLayoutSwitch extends ValueNotifier<PaywallLayoutSetting?> {
  DevPaywallLayoutSwitch(this._prefs, this._key)
    : super(PaywallLayoutSetting.fromStored(_prefs.getString(_key)));

  static const hostedKey = 'dev.paywall_layout';
  static const proKey = 'dev.pro_paywall_layout';

  final SharedPreferences _prefs;
  final String _key;

  /// Pins a layout, or hands the choice back to the place table when
  /// [setting] is null or [PaywallLayoutSetting.auto]. Remembered across
  /// launches.
  Future<void> setSetting(PaywallLayoutSetting? setting) async {
    final pinned = setting == null || setting.isAuto ? null : setting;
    value = pinned;
    if (pinned == null) {
      await _prefs.remove(_key);
      return;
    }
    await _prefs.setString(_key, pinned.storedKey);
  }
}

/// The developer control for one product's intro: the coded default
/// (null), or one intro that outranks it, `none` among them. Saved in prefs
/// under [_key].
class DevPaywallIntroSwitch extends ValueNotifier<PaywallIntroId?> {
  DevPaywallIntroSwitch(this._prefs, this._key)
    : super(PaywallIntroId.fromKey(_prefs.getString(_key)));

  static const hostedKey = 'dev.paywall_intro';
  static const proKey = 'dev.pro_paywall_intro';

  final SharedPreferences _prefs;
  final String _key;

  /// Sets what outranks the coded default, or hands the choice back to it
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

/// The developer control for one product's thanks: the coded default
/// (null), or one thanks that outranks it, `none` among them. Saved in
/// prefs under [_key].
class DevPaywallThanksSwitch extends ValueNotifier<PaywallThanksId?> {
  DevPaywallThanksSwitch(this._prefs, this._key)
    : super(PaywallThanksId.fromKey(_prefs.getString(_key)));

  static const hostedKey = 'dev.paywall_thanks';
  static const proKey = 'dev.pro_paywall_thanks';

  final SharedPreferences _prefs;
  final String _key;

  /// Sets what outranks the coded default, or hands the choice back to it
  /// when [thanks] is null. Remembered across launches.
  Future<void> setThanks(PaywallThanksId? thanks) async {
    value = thanks;
    if (thanks == null) {
      await _prefs.remove(_key);
      return;
    }
    await _prefs.setString(_key, thanks.key);
  }
}

/// The developer control for one product's success outro: the coded
/// default (null), or one outro that outranks it, `none` among them.
/// Saved in prefs under [_key].
class DevPaywallOutroSwitch extends ValueNotifier<PaywallOutroId?> {
  DevPaywallOutroSwitch(this._prefs, this._key)
    : super(PaywallOutroId.fromKey(_prefs.getString(_key)));

  static const hostedKey = 'dev.paywall_outro';
  static const proKey = 'dev.pro_paywall_outro';

  final SharedPreferences _prefs;
  final String _key;

  /// Sets what outranks the coded default, or hands the choice back to it
  /// when [outro] is null. Remembered across launches.
  Future<void> setOutro(PaywallOutroId? outro) async {
    value = outro;
    if (outro == null) {
      await _prefs.remove(_key);
      return;
    }
    await _prefs.setString(_key, outro.key);
  }
}

/// The developer controls: a layout, an intro, a thanks and a success
/// outro per product.
class DevPaywallLayoutSwitches {
  const DevPaywallLayoutSwitches({
    required this.hosted,
    required this.pro,
    required this.hostedIntro,
    required this.proIntro,
    required this.hostedThanks,
    required this.proThanks,
    required this.hostedOutro,
    required this.proOutro,
  });

  final DevPaywallLayoutSwitch hosted;
  final DevPaywallLayoutSwitch pro;
  final DevPaywallIntroSwitch hostedIntro;
  final DevPaywallIntroSwitch proIntro;
  final DevPaywallThanksSwitch hostedThanks;
  final DevPaywallThanksSwitch proThanks;
  final DevPaywallOutroSwitch hostedOutro;
  final DevPaywallOutroSwitch proOutro;
}

/// Lets a developer build choose what each product's paywall opens.
///
/// Settled when the app is compiled. A store build is compiled with
/// [NoPaywallLayoutOverride], which has nowhere to keep a switch and always
/// answers null, so the coded defaults decide.
abstract interface class PaywallLayoutOverride {
  /// What a developer set for Hosted, or null for the place table.
  PaywallLayoutSetting? get hosted;

  /// The same for Pro.
  PaywallLayoutSetting? get pro;

  /// The intro a developer set for Hosted, or null for the coded
  /// default.
  PaywallIntroId? get hostedIntro;

  /// The same for Pro.
  PaywallIntroId? get proIntro;

  /// The thanks a developer set for Hosted, or null for the coded
  /// default.
  PaywallThanksId? get hostedThanks;

  /// The same for Pro.
  PaywallThanksId? get proThanks;

  /// The success outro a developer set for Hosted, or null for the coded
  /// default.
  PaywallOutroId? get hostedOutro;

  /// The same for Pro.
  PaywallOutroId? get proOutro;

  /// Starts reporting the switches. Does nothing in a build with no
  /// override.
  void watch({
    required ValueListenable<PaywallLayoutSetting?> hosted,
    required ValueListenable<PaywallLayoutSetting?> pro,
    ValueListenable<PaywallIntroId?>? hostedIntro,
    ValueListenable<PaywallIntroId?>? proIntro,
    ValueListenable<PaywallThanksId?>? hostedThanks,
    ValueListenable<PaywallThanksId?>? proThanks,
    ValueListenable<PaywallOutroId?>? hostedOutro,
    ValueListenable<PaywallOutroId?>? proOutro,
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
  PaywallThanksId? get hostedThanks => null;

  @override
  PaywallThanksId? get proThanks => null;

  @override
  PaywallOutroId? get hostedOutro => null;

  @override
  PaywallOutroId? get proOutro => null;

  @override
  void watch({
    required ValueListenable<PaywallLayoutSetting?> hosted,
    required ValueListenable<PaywallLayoutSetting?> pro,
    ValueListenable<PaywallIntroId?>? hostedIntro,
    ValueListenable<PaywallIntroId?>? proIntro,
    ValueListenable<PaywallThanksId?>? hostedThanks,
    ValueListenable<PaywallThanksId?>? proThanks,
    ValueListenable<PaywallOutroId?>? hostedOutro,
    ValueListenable<PaywallOutroId?>? proOutro,
  }) {}
}

/// The override a build with Developer options is compiled with.
class DevPaywallLayoutOverride implements PaywallLayoutOverride {
  ValueListenable<PaywallLayoutSetting?>? _hosted;
  ValueListenable<PaywallLayoutSetting?>? _pro;
  ValueListenable<PaywallIntroId?>? _hostedIntro;
  ValueListenable<PaywallIntroId?>? _proIntro;
  ValueListenable<PaywallThanksId?>? _hostedThanks;
  ValueListenable<PaywallThanksId?>? _proThanks;
  ValueListenable<PaywallOutroId?>? _hostedOutro;
  ValueListenable<PaywallOutroId?>? _proOutro;

  @override
  PaywallLayoutSetting? get hosted => _hosted?.value;

  @override
  PaywallLayoutSetting? get pro => _pro?.value;

  @override
  PaywallIntroId? get hostedIntro => _hostedIntro?.value;

  @override
  PaywallIntroId? get proIntro => _proIntro?.value;

  @override
  PaywallThanksId? get hostedThanks => _hostedThanks?.value;

  @override
  PaywallThanksId? get proThanks => _proThanks?.value;

  @override
  PaywallOutroId? get hostedOutro => _hostedOutro?.value;

  @override
  PaywallOutroId? get proOutro => _proOutro?.value;

  @override
  void watch({
    required ValueListenable<PaywallLayoutSetting?> hosted,
    required ValueListenable<PaywallLayoutSetting?> pro,
    ValueListenable<PaywallIntroId?>? hostedIntro,
    ValueListenable<PaywallIntroId?>? proIntro,
    ValueListenable<PaywallThanksId?>? hostedThanks,
    ValueListenable<PaywallThanksId?>? proThanks,
    ValueListenable<PaywallOutroId?>? hostedOutro,
    ValueListenable<PaywallOutroId?>? proOutro,
  }) {
    _hosted = hosted;
    _pro = pro;
    _hostedIntro = hostedIntro;
    _proIntro = proIntro;
    _hostedThanks = hostedThanks;
    _proThanks = proThanks;
    _hostedOutro = hostedOutro;
    _proOutro = proOutro;
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
