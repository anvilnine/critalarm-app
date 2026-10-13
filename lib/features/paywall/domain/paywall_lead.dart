import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/paywall_lead_facts.dart';
import 'package:flutter/foundation.dart';

/// The benefit a paywall opens on, and the words to say it with.
///
/// A route sets one on `PaywallRouteInfo`. Every layout then lists
/// [benefit] first. A layout that draws a scene for each benefit (the
/// reel) also reads the words for that first scene. Anything left null
/// reads as the benefit's own.
///
/// Each key is an `en.json` key. A lead names no plan: the product the
/// paywall sells decides whether [benefit] is listed at all.
@immutable
class PaywallLead {
  const PaywallLead({
    required this.benefit,
    this.eyebrowKey,
    this.headlineKey,
    this.lineKey,
    this.topicName,
    this.usedCount,
    this.limitCount,
  });

  final PaywallBenefitId benefit;

  /// The small line over the headline. Null keeps the layout's own.
  final String? eyebrowKey;

  /// The headline of the first scene. Null keeps the benefit's own.
  final String? headlineKey;

  /// A line under the first scene's picture. Null draws none.
  final String? lineKey;

  /// A topic name for the topics picture to show in its first row, in
  /// place of its own made-up one.
  final String? topicName;

  /// How many critical topics the person has on, and the limit, for the
  /// topics picture's tag. Both are needed to draw it. Null otherwise.
  final int? usedCount;
  final int? limitCount;

  @override
  bool operator ==(Object other) =>
      other is PaywallLead &&
      other.benefit == benefit &&
      other.eyebrowKey == eyebrowKey &&
      other.headlineKey == headlineKey &&
      other.lineKey == lineKey &&
      other.topicName == topicName &&
      other.usedCount == usedCount &&
      other.limitCount == limitCount;

  @override
  int get hashCode => Object.hash(
    benefit,
    eyebrowKey,
    headlineKey,
    lineKey,
    topicName,
    usedCount,
    limitCount,
  );
}

/// [lead] when one of [benefits] is the benefit it names, else null: a
/// lead for a benefit this paywall does not list is ignored.
PaywallLead? paywallLeadIn(List<PaywallBenefit> benefits, PaywallLead? lead) {
  if (lead == null) return null;
  for (final benefit in benefits) {
    if (benefit.id == lead.benefit) return lead;
  }
  return null;
}

/// [benefits] with the one [lead] names first and the rest in the order
/// they were in. The same list when there is no lead, or when it names a
/// benefit that is not listed.
List<PaywallBenefit> paywallBenefitsLeadFirst(
  List<PaywallBenefit> benefits,
  PaywallLead? lead,
) {
  if (paywallLeadIn(benefits, lead) == null) return benefits;
  return [
    for (final benefit in benefits)
      if (benefit.id == lead!.benefit) benefit,
    for (final benefit in benefits)
      if (benefit.id != lead!.benefit) benefit,
  ];
}

/// The lead a `/plans/:layout` location names in `?lead=`, or null for a
/// missing or unknown one. The paywall opens either way. A topics lead also
/// reads the person's own count and topic name (`used`, `limit`, `topic`),
/// each checked on its own: a value that fails is left out.
PaywallLead? paywallLeadFromQuery(Map<String, String> query) {
  final benefit = PaywallBenefitId.fromKey(query['lead']);
  if (benefit == null) return null;
  if (benefit != PaywallBenefitId.topics) return PaywallLead(benefit: benefit);
  final facts = PaywallLeadFacts.fromQuery(query);
  return PaywallLead(
    benefit: benefit,
    usedCount: facts.used,
    limitCount: facts.limit,
    topicName: facts.topicName,
  );
}
