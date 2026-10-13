import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/history_own.dart';
import 'package:critalarm/features/paywall/presentation/layouts/proof_paywall_layout.dart';
import 'package:flutter_test/flutter_test.dart';

const _own = HistoryOwn(
  inside: [],
  beyond: [HistoryOwnRow('nas', 12)],
);

void main() {
  test('See older alarms only when the phone holds older alarms', () {
    expect(
      proofHeadlineFor(
        isHosted: true,
        lead: PaywallBenefitId.history,
        own: _own,
      ),
      ProofHeadline.olderAlarms,
    );
  });

  test('a phone with nothing older keeps the normal headline', () {
    expect(
      proofHeadlineFor(
        isHosted: true,
        lead: PaywallBenefitId.history,
        own: null,
      ),
      ProofHeadline.hosted,
    );
  });

  test('another lead keeps the normal headline whatever the phone holds', () {
    for (final lead in [
      null,
      PaywallBenefitId.reliabilityChecks,
      PaywallBenefitId.topics,
    ]) {
      expect(
        proofHeadlineFor(isHosted: true, lead: lead, own: _own),
        ProofHeadline.hosted,
        reason: '$lead',
      );
    }
  });

  test('Pro never says it', () {
    expect(
      proofHeadlineFor(
        isHosted: false,
        lead: PaywallBenefitId.history,
        own: _own,
      ),
      ProofHeadline.pro,
    );
  });

  group('which beat the headline shows on', () {
    test('See older alarms stays on the lead beat only', () {
      expect(
        proofHeadlineOnBeat(ProofHeadline.olderAlarms, beat: 0),
        ProofHeadline.olderAlarms,
      );
      for (var beat = 1; beat < 8; beat++) {
        expect(
          proofHeadlineOnBeat(ProofHeadline.olderAlarms, beat: beat),
          ProofHeadline.hosted,
          reason: 'beat $beat',
        );
      }
    });

    test('the other headlines do not follow the beat', () {
      for (final headline in [ProofHeadline.hosted, ProofHeadline.pro]) {
        for (var beat = 0; beat < 4; beat++) {
          expect(proofHeadlineOnBeat(headline, beat: beat), headline);
        }
      }
    });
  });
}
