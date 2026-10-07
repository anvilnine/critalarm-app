import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';

/// The benefit a place in the app is about, or null for a place that names
/// none: a link, a reminder, the plan row in Settings.
PaywallBenefitId? sheetBenefitIdFor(PaywallSource source) => switch (source) {
  PaywallSource.createTopicCard => PaywallBenefitId.topics,
  PaywallSource.history ||
  PaywallSource.historyOlder => PaywallBenefitId.history,
  PaywallSource.widgetLocked ||
  PaywallSource.homeWidgets => PaywallBenefitId.widgets,
  PaywallSource.appIcon => PaywallBenefitId.appIcons,
  PaywallSource.settingsPlan ||
  PaywallSource.askSheet ||
  PaywallSource.planSheetEnding ||
  PaywallSource.planSheetEnded ||
  PaywallSource.settingsSearch ||
  PaywallSource.reminderMorningAfter ||
  PaywallSource.reminderProLater ||
  PaywallSource.homeDay0Card ||
  PaywallSource.onboardingOffer ||
  PaywallSource.direct => null,
};

/// The benefit the sheet answers first: the one the user was reaching for
/// when the paywall opened.
///
/// A topic limit leads with topics, history with history, a widget with
/// widgets. Anything else, and a benefit the product on sale does not list,
/// leads with the first one. Null only when [benefits] is empty.
PaywallBenefit? sheetLeadBenefit(
  PaywallSource source,
  List<PaywallBenefit> benefits,
) {
  if (benefits.isEmpty) return null;
  final wanted = sheetBenefitIdFor(source);
  for (final benefit in benefits) {
    if (benefit.id == wanted) return benefit;
  }
  return benefits.first;
}

/// The benefits listed under the lead, in their own order.
List<PaywallBenefit> sheetOtherBenefits(
  PaywallBenefit? lead,
  List<PaywallBenefit> benefits,
) => [
  for (final benefit in benefits)
    if (benefit.id != lead?.id) benefit,
];
