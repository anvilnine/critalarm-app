import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/paywall_lead.dart';
import 'package:critalarm/features/paywall/presentation/layouts/proof/proof_beats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a lead puts its beat first in the loop', () {
    final listed = paywallBenefitsFor(PaywallProduct.hosted);
    for (final lead in [
      PaywallBenefitId.history,
      PaywallBenefitId.reliabilityChecks,
      PaywallBenefitId.topics,
    ]) {
      final led = paywallBenefitsLeadFirst(listed, PaywallLead(benefit: lead));
      final loop = proofLoopFor([for (final b in led) b.previewId]);
      expect(
        loop.scenes.first.preview,
        led.first.previewId,
        reason: lead.key,
      );
      expect(led.first.id, lead);
    }
  });
}
