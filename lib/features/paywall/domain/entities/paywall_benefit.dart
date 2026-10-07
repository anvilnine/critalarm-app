import 'package:critalarm/features/paywall/domain/entities/hosted_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_preview_id.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';

/// Every benefit a paywall layout can name, for both products.
///
/// The Hosted ones carry the same names as `HostedBenefitId`, so the two
/// lists can be matched one to one.
enum PaywallBenefitId {
  topics('topics'),
  pushes('pushes'),
  history('history'),
  widgets('widgets'),
  appIcons('app_icons'),
  weeklyCheck('weekly_check'),
  fireDrills('fire_drills'),
  wakeUpChallenges('wake_up_challenges'),
  customAlarmScreens('custom_alarm_screens'),
  morningSummary('morning_summary');

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
  });

  final PaywallBenefitId id;
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

/// The Hosted line and preview for each Hosted benefit. A benefit taken out
/// of `HostedBenefit.all` drops off every layout too.
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
      HostedBenefitId.widgets: (
        PaywallBenefitId.widgets,
        LocaleKeys.paywall_kit_benefits_widgets_line,
        PaywallPreviewId.widgets,
      ),
      HostedBenefitId.appIcons: (
        PaywallBenefitId.appIcons,
        LocaleKeys.paywall_kit_benefits_app_icons_line,
        PaywallPreviewId.appIcons,
      ),
    };

/// What Pro gives. Only the weekly check is in the app today. The rest are
/// written down so a layout picks them up the day each one is switched on.
const _proBenefits = <PaywallBenefit>[
  PaywallBenefit(
    id: PaywallBenefitId.weeklyCheck,
    product: PaywallProduct.pro,
    titleKey: LocaleKeys.paywall_kit_benefits_weekly_check_title,
    lineKey: LocaleKeys.paywall_kit_benefits_weekly_check_line,
    previewId: PaywallPreviewId.weeklyCheck,
    inThisBuild: true,
  ),
  PaywallBenefit(
    id: PaywallBenefitId.fireDrills,
    product: PaywallProduct.pro,
    titleKey: LocaleKeys.paywall_kit_benefits_fire_drills_title,
    lineKey: LocaleKeys.paywall_kit_benefits_fire_drills_line,
    previewId: PaywallPreviewId.fireDrills,
    inThisBuild: false,
  ),
  PaywallBenefit(
    id: PaywallBenefitId.wakeUpChallenges,
    product: PaywallProduct.pro,
    titleKey: LocaleKeys.paywall_kit_benefits_wake_up_challenges_title,
    lineKey: LocaleKeys.paywall_kit_benefits_wake_up_challenges_line,
    previewId: PaywallPreviewId.wakeUpChallenges,
    inThisBuild: false,
  ),
  PaywallBenefit(
    id: PaywallBenefitId.customAlarmScreens,
    product: PaywallProduct.pro,
    titleKey: LocaleKeys.paywall_kit_benefits_custom_alarm_screens_title,
    lineKey: LocaleKeys.paywall_kit_benefits_custom_alarm_screens_line,
    previewId: PaywallPreviewId.customAlarmScreens,
    inThisBuild: false,
  ),
  PaywallBenefit(
    id: PaywallBenefitId.morningSummary,
    product: PaywallProduct.pro,
    titleKey: LocaleKeys.paywall_kit_benefits_morning_summary_title,
    lineKey: LocaleKeys.paywall_kit_benefits_morning_summary_line,
    previewId: PaywallPreviewId.morningSummary,
    inThisBuild: false,
  ),
];

/// Every benefit of both products, Hosted first, each in display order.
/// Includes the ones this build does not have yet. Only the tests and the
/// developer pages read this: a layout reads [paywallBenefitsFor].
List<PaywallBenefit> get allPaywallBenefits => [
  for (final hosted in HostedBenefit.all)
    if (_hostedParts[hosted.id] case (final id, final lineKey, final preview))
      PaywallBenefit(
        id: id,
        product: PaywallProduct.hosted,
        titleKey: hosted.compareLabelKey,
        lineKey: lineKey,
        previewId: preview,
        inThisBuild: true,
      ),
  ..._proBenefits,
];

/// What a layout lists for [product]: the benefits this build really has,
/// in display order.
List<PaywallBenefit> paywallBenefitsFor(PaywallProduct product) => [
  for (final benefit in allPaywallBenefits)
    if (benefit.product == product && benefit.inThisBuild) benefit,
];
