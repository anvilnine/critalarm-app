import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/features/paywall/domain/entities/hosted_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_preview_id.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';

/// Every benefit a paywall layout can name, for both products.
enum PaywallBenefitId {
  topics('topics'),
  pushes('pushes'),
  history('history'),
  appIcons('app_icons'),
  wakeUpChallenges('wake_up_challenges'),
  widgets('widgets'),
  reliabilityChecks('reliability_checks'),
  customSounds('custom_sounds'),
  customAlarmScreens('custom_alarm_screens');

  const PaywallBenefitId(this.key);

  final String key;
}

/// One thing a product gives, as a layout draws it: a title, one short line
/// and a preview.
class PaywallBenefit {
  const PaywallBenefit({
    required this.id,
    required this.product,
    required this.titleKey,
    required this.lineKey,
    required this.previewId,
    required this.inThisBuild,
    this.feature,
  });

  final PaywallBenefitId id;

  /// The feature this benefit stands for, where it has one in the table.
  final AppFeature? feature;
  final PaywallProduct product;
  final String titleKey;

  /// One short line under the title.
  final String lineKey;
  final PaywallPreviewId previewId;

  /// Whether this build really has the feature. A layout never sees an item
  /// where this is false: [paywallBenefitsFor] leaves it out.
  final bool inThisBuild;

  /// The title as text.
  String get title => titleKey.tr(namedArgs: HostedBenefit.args);

  /// The line as text. The Hosted numbers come from [HostedBenefit.args],
  /// so a number is still edited in one place.
  String get line => lineKey.tr(namedArgs: HostedBenefit.args);
}

/// The Hosted line and preview for each benefit a layout lists under
/// Hosted. A benefit of `HostedBenefit.all` with no entry here is not
/// listed. A benefit taken out of `HostedBenefit.all` drops off every
/// layout too.
///
/// The weekly delivery check is such a benefit today: it is in
/// `HostedBenefit.all`, so the shipped Hosted paywall, the ask sheet and
/// the notices name it, and it has no entry here yet. A layout lists it
/// once it has one, and once the step after a purchase has plan facts for
/// it (`limitsHostedFor`), which needs a row for every Hosted benefit a
/// layout lists.
const _hostedParts =
    <HostedBenefitId, (PaywallBenefitId, String, PaywallPreviewId)>{
      HostedBenefitId.topics: (
        PaywallBenefitId.topics,
        LocaleKeys.paywall_kit_benefits_topics_line,
        PaywallPreviewId.topics,
      ),
      HostedBenefitId.pushes: (
        PaywallBenefitId.pushes,
        LocaleKeys.paywall_kit_benefits_pushes_line,
        PaywallPreviewId.pushes,
      ),
      HostedBenefitId.history: (
        PaywallBenefitId.history,
        LocaleKeys.paywall_kit_benefits_history_line,
        PaywallPreviewId.history,
      ),
      HostedBenefitId.appIcons: (
        PaywallBenefitId.appIcons,
        LocaleKeys.paywall_kit_benefits_app_icons_line,
        PaywallPreviewId.appIcons,
      ),
    };

/// Every benefit Pro has a title, a line and a preview for, in display
/// order. The table picks from it and never reorders it: a benefit is
/// listed under Pro while Pro unlocks its feature.
///
/// [PaywallBenefit.inThisBuild] is true only for what the app has today:
/// the widgets and the alarm screen looks (four fixed ones and the
/// person's own photo). Two more are written and drawn, and a layout picks
/// each one up the day its switch is turned on.
///
/// The weekly delivery check keeps its entry here and the table leaves it
/// out, because Hosted is what unlocks it now.
///
/// The app icons have no entry here yet, though Pro unlocks them too. A
/// layout lists them under Hosted only. An entry for them needs the step
/// after a purchase to tell the two products apart first: it reads a
/// benefit's plan facts by id (`limitsHostedFor`) and expects none for a
/// Pro benefit.
const _proDisplayOrder = <PaywallBenefit>[
  PaywallBenefit(
    id: PaywallBenefitId.wakeUpChallenges,
    feature: AppFeature.wakeUpChallenges,
    product: PaywallProduct.pro,
    titleKey: LocaleKeys.paywall_kit_benefits_wake_up_challenges_title,
    lineKey: LocaleKeys.paywall_kit_benefits_wake_up_challenges_line,
    previewId: PaywallPreviewId.wakeUpChallenges,
    inThisBuild: false,
  ),
  PaywallBenefit(
    id: PaywallBenefitId.widgets,
    feature: AppFeature.widgets,
    product: PaywallProduct.pro,
    titleKey: LocaleKeys.paywall_kit_benefits_widgets_title,
    lineKey: LocaleKeys.paywall_kit_benefits_widgets_line,
    previewId: PaywallPreviewId.widgets,
    inThisBuild: true,
  ),
  PaywallBenefit(
    id: PaywallBenefitId.reliabilityChecks,
    feature: AppFeature.weeklyCheck,
    product: PaywallProduct.pro,
    titleKey: LocaleKeys.paywall_kit_benefits_reliability_checks_title,
    lineKey: LocaleKeys.paywall_kit_benefits_reliability_checks_line,
    previewId: PaywallPreviewId.weeklyCheck,
    inThisBuild: true,
  ),
  PaywallBenefit(
    id: PaywallBenefitId.customSounds,
    feature: AppFeature.ownSounds,
    product: PaywallProduct.pro,
    titleKey: LocaleKeys.paywall_kit_benefits_custom_sounds_title,
    lineKey: LocaleKeys.paywall_kit_benefits_custom_sounds_line,
    previewId: PaywallPreviewId.customSounds,
    inThisBuild: false,
  ),
  PaywallBenefit(
    id: PaywallBenefitId.customAlarmScreens,
    feature: AppFeature.alarmScreenStyles,
    product: PaywallProduct.pro,
    titleKey: LocaleKeys.paywall_kit_benefits_custom_alarm_screens_title,
    lineKey: LocaleKeys.paywall_kit_benefits_custom_alarm_screens_line,
    previewId: PaywallPreviewId.customAlarmScreens,
    inThisBuild: true,
  ),
];

/// Every benefit of both products under [table], Hosted first, each in
/// display order. Includes the ones this build does not have yet.
///
/// Hosted lists each benefit of [hostedBenefitsIn] that has a line and a
/// preview here. Pro lists each of its benefits whose feature Pro unlocks
/// in [table].
List<PaywallBenefit> allPaywallBenefitsIn(
  Map<AppFeature, FeatureRule> table,
) => [
  for (final hosted in hostedBenefitsIn(table))
    if (_hostedParts[hosted.id] case (final id, final lineKey, final preview))
      PaywallBenefit(
        id: id,
        feature: hosted.feature,
        product: PaywallProduct.hosted,
        titleKey: hosted.compareLabelKey,
        lineKey: lineKey,
        previewId: preview,
        inThisBuild: true,
      ),
  for (final pro in _proDisplayOrder)
    if (table[pro.feature]?.unlockedBy.contains(Holding.pro) ?? false) pro,
];

/// [allPaywallBenefitsIn] for the app's own table. Only the tests and the
/// developer pages read this: a layout reads [paywallBenefitsFor].
List<PaywallBenefit> get allPaywallBenefits =>
    allPaywallBenefitsIn(featureTable);

/// What a layout lists for [product]: the benefits this build really has,
/// in display order.
List<PaywallBenefit> paywallBenefitsFor(PaywallProduct product) => [
  for (final benefit in allPaywallBenefits)
    if (benefit.product == product && benefit.inThisBuild) benefit,
];
