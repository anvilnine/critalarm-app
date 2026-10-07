import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_layout_setting.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_analytics.dart';

/// The kind of place a paywall was opened from. Each is one row of the
/// table [paywallLayoutFor] picks from when a product is set to `auto`.
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

/// What opens for [product] from [entry]: a layout, or null for the surface
/// that ships today (the Hosted paywall, the Pro sheet).
///
/// [remote] is the product's remote value and [developer] what Developer
/// options set in its place, null in a store build. With [remote] at its
/// default and no [developer] value the answer is always null.
///
/// The False alarm layout is never in the table. It takes the place of
/// `hero` from the Settings plan row alone, and only while
/// [hasSeenFalseAlarm] is false. Anywhere else, and from then on, a setting
/// that asks for it opens `hero`.
PaywallLayoutId? paywallLayoutFor({
  required PaywallProduct product,
  required PaywallEntry entry,
  required PaywallLayoutSetting remote,
  required bool hasSeenFalseAlarm,
  PaywallLayoutSetting? developer,
}) {
  final setting = developer ?? remote;
  if (setting.isShipped) return null;

  final wanted = setting.layout ?? _autoLayout(entry);
  final mayBeFalseAlarm =
      wanted == PaywallLayoutId.falseAlarm ||
      (setting.isAuto && wanted == PaywallLayoutId.hero);
  if (!mayBeFalseAlarm) return wanted;

  final opensFalseAlarm =
      product == PaywallProduct.hosted &&
      entry == PaywallEntry.settingsPlan &&
      !hasSeenFalseAlarm;
  return opensFalseAlarm ? PaywallLayoutId.falseAlarm : PaywallLayoutId.hero;
}
