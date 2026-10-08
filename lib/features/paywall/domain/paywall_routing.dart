import 'package:critalarm/core/paywall/paywall_intro.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_layout_setting.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_analytics.dart';
import 'package:flutter/foundation.dart';

/// The kind of place a paywall was opened from. Each is one row of the
/// table [paywallOpeningFor] picks from when a product is set to `auto`.
enum PaywallEntry {
  /// A limit was reached: a refused critical topic, history's older rows.
  capHit,

  /// A locked row or widget: a home screen widget, an app icon, a locked
  /// Pro row.
  lockedRow,

  /// The plan row in Settings.
  settingsPlan,

  /// The plan result in Settings search.
  settingsSearch,

  /// The app asked: the ask sheet, the day 0 card, a reminder.
  nudge,

  /// A plan that is ending or has ended.
  lapse,

  /// Anything else, a link with no source among them.
  other,
}

/// The row each Hosted entry point belongs to.
PaywallEntry paywallEntryOf(PaywallSource source) => switch (source) {
  PaywallSource.createTopicCard ||
  PaywallSource.historyOlder ||
  PaywallSource.history => PaywallEntry.capHit,
  PaywallSource.widgetLocked ||
  PaywallSource.homeWidgets ||
  PaywallSource.appIcon => PaywallEntry.lockedRow,
  PaywallSource.settingsPlan => PaywallEntry.settingsPlan,
  PaywallSource.settingsSearch => PaywallEntry.settingsSearch,
  PaywallSource.askSheet ||
  PaywallSource.homeDay0Card ||
  PaywallSource.reminderMorningAfter ||
  PaywallSource.reminderProLater => PaywallEntry.nudge,
  PaywallSource.planSheetEnding ||
  PaywallSource.planSheetEnded => PaywallEntry.lapse,
  PaywallSource.direct => PaywallEntry.other,
};

/// The row each Pro entry point belongs to.
PaywallEntry paywallEntryOfProSheet(ProPackSheetSource source) =>
    switch (source) {
      ProPackSheetSource.reliability => PaywallEntry.lockedRow,
      ProPackSheetSource.direct => PaywallEntry.other,
    };

/// The layout `auto` opens for [entry]. The table is the same for both
/// products: Pro has no entry point in the two rows that are Hosted only.
PaywallLayoutId _autoLayout(PaywallEntry entry) => switch (entry) {
  PaywallEntry.capHit || PaywallEntry.lockedRow => PaywallLayoutId.sheet,
  PaywallEntry.settingsPlan ||
  PaywallEntry.settingsSearch ||
  PaywallEntry.other => PaywallLayoutId.hero,
  PaywallEntry.nudge => PaywallLayoutId.reel,
  PaywallEntry.lapse => PaywallLayoutId.doors,
};

/// What opens: a layout, and the intro that plays before it.
@immutable
class PaywallOpening {
  const PaywallOpening(this.layout, {this.intro = PaywallIntroId.none});

  final PaywallLayoutId layout;

  /// `none` when the layout opens with its own entrance alone.
  final PaywallIntroId intro;

  @override
  bool operator ==(Object other) =>
      other is PaywallOpening && other.layout == layout && other.intro == intro;

  @override
  int get hashCode => Object.hash(layout, intro);

  @override
  String toString() => 'PaywallOpening(${layout.key}, intro: ${intro.key})';
}

/// What opens for [product] from [entry]: a layout and its intro, or null
/// for the surface that ships today (the Hosted paywall, the Pro sheet).
///
/// [remote] is the product's remote layout value and [developer] what
/// Developer options set in its place, null in a store build. With [remote]
/// at its default and no [developer] value the answer is always null.
///
/// The intro is a second value. [developerIntro] outranks [remoteIntro],
/// and with neither set the rule from when the false alarm was a layout
/// still holds: a layout value that names it ([legacyIntro]), or `auto`
/// landing on `hero`, plays it from the Hosted Settings plan row alone.
///
/// The false alarm intro plays once on an install. While
/// [hasSeenFalseAlarm] is true no setting plays it again.
PaywallOpening? paywallOpeningFor({
  required PaywallProduct product,
  required PaywallEntry entry,
  required PaywallLayoutSetting remote,
  required bool hasSeenFalseAlarm,
  PaywallLayoutSetting? developer,
  PaywallIntroId remoteIntro = PaywallIntroId.none,
  PaywallIntroId? developerIntro,
  PaywallIntroId? legacyIntro,
}) {
  final setting = developer ?? remote;
  if (setting.isShipped) return null;
  final layout = setting.layout ?? _autoLayout(entry);

  var intro = developerIntro ?? remoteIntro;
  if (developerIntro == null && remoteIntro == PaywallIntroId.none) {
    final asksForFalseAlarm =
        legacyIntro == PaywallIntroId.falseAlarm ||
        (setting.isAuto && layout == PaywallLayoutId.hero);
    final opensFalseAlarm =
        asksForFalseAlarm &&
        product == PaywallProduct.hosted &&
        entry == PaywallEntry.settingsPlan;
    if (opensFalseAlarm) intro = PaywallIntroId.falseAlarm;
  }
  if (intro == PaywallIntroId.falseAlarm && hasSeenFalseAlarm) {
    intro = PaywallIntroId.none;
  }
  return PaywallOpening(layout, intro: intro);
}
