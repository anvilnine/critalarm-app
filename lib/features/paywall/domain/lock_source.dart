import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_analytics.dart';

/// Where a person met a locked feature.
///
/// One tag per place. It carries the analytics source for both paywalls,
/// so the place never says which product it sells: the paywall door reads
/// that from the feature's decision. A feature that moves from Hosted to
/// Pro keeps its tag and opens the other paywall.
enum LockSource {
  /// The count card under the Critical switch on the new topic screen.
  createTopicCard(
    PaywallSource.createTopicCard,
    ProPackSheetSource.createTopicCard,
  ),

  /// A longer window picked in the History filter sheet.
  history(PaywallSource.history, ProPackSheetSource.history),

  /// The "older alarms" line under the History list.
  historyOlder(PaywallSource.historyOlder, ProPackSheetSource.historyOlder),

  /// The widgets card on Home and the sheet it opens.
  homeWidgets(PaywallSource.homeWidgets, ProPackSheetSource.homeWidgets),

  /// A tap on a locked home screen widget. The tap arrives as a link, so
  /// the paywall door picks the product from the widgets decision.
  widgetLocked(PaywallSource.widgetLocked, ProPackSheetSource.widgetLocked),

  /// A locked icon on the App icon screen.
  appIcon(PaywallSource.appIcon, ProPackSheetSource.appIcon),

  /// A locked row on the Reliability screen.
  ///
  /// `PaywallSource` has no value for it yet, so on the Hosted side it
  /// reads as `direct`. Nothing on that screen sells Hosted today.
  reliability(PaywallSource.direct, ProPackSheetSource.reliability),

  /// The sound strip on the Personalize page, and the bar under its
  /// preview while a locked sound is being tried.
  ///
  /// The three Personalize places have a Pro source of their own. On the
  /// Hosted side each reads as the older place that sells the same thing,
  /// so the Hosted paywall still leads with the benefit the person reached
  /// for. `PaywallSource` gets its own values for them once the paywall
  /// layouts, which switch over every value, can take new cases.
  personalizeSound(PaywallSource.direct, ProPackSheetSource.personalizeSound),

  /// The Widgets row on the Personalize page.
  personalizeWidgets(
    PaywallSource.homeWidgets,
    ProPackSheetSource.personalizeWidgets,
  ),

  /// The App icon row on the Personalize page.
  personalizeAppIcon(
    PaywallSource.appIcon,
    ProPackSheetSource.personalizeAppIcon,
  ),

  /// An own alarm sound: Pick a file, Record, the cropper, a file shared
  /// in from another app, and a locked own sound in the sound list.
  ///
  /// `PaywallSource` has no value for it, so on the Hosted side it reads
  /// as `direct`. Own sounds are sold with Pro only.
  sounds(PaywallSource.direct, ProPackSheetSource.sounds);

  const LockSource(this.hosted, this.pro);

  /// The source the Hosted paywall is opened with.
  final PaywallSource hosted;

  /// The source the Pro paywall is opened with.
  final ProPackSheetSource pro;
}
