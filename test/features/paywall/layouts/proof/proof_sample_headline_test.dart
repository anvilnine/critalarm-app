import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/history_own.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/history_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/proof_paywall_layout.dart';
import 'package:flutter_test/flutter_test.dart';

const _own = HistoryOwn(inside: [], beyond: [HistoryOwnRow('nas', 12)]);

void main() {
  group('the headline of the route', () {
    test(
      'a history lead with no rows of the phone says what the Sheet says',
      () {
        expect(
          proofHeadlineForRoute(
            isHosted: true,
            lead: PaywallBenefitId.history,
            own: null,
          ),
          ProofHeadline.keptLonger,
        );
      },
    );

    test(
      "a history lead with the phone's own rows keeps See older alarms",
      () {
        expect(
          proofHeadlineForRoute(
            isHosted: true,
            lead: PaywallBenefitId.history,
            own: _own,
          ),
          ProofHeadline.olderAlarms,
        );
      },
    );

    test('any other lead, no lead and Pro keep what they had', () {
      for (final lead in [
        null,
        PaywallBenefitId.topics,
        PaywallBenefitId.reliabilityChecks,
      ]) {
        expect(
          proofHeadlineForRoute(isHosted: true, lead: lead, own: null),
          ProofHeadline.hosted,
          reason: '$lead',
        );
      }
      expect(
        proofHeadlineForRoute(
          isHosted: false,
          lead: PaywallBenefitId.history,
          own: null,
        ),
        ProofHeadline.pro,
      );
    });

    test('it is on the history beat only, the other beats keep the usual', () {
      expect(
        proofHeadlineOnBeat(ProofHeadline.keptLonger, beat: 0),
        ProofHeadline.keptLonger,
      );
      for (var beat = 1; beat < 8; beat++) {
        expect(
          proofHeadlineOnBeat(ProofHeadline.keptLonger, beat: beat),
          ProofHeadline.hosted,
          reason: 'beat $beat',
        );
      }
    });
  });

  group('the line label', () {
    test('settles on 90d, as on the Sheet and the Wipe', () {
      final rest = historyPreviewFrameAt(0, free: 7, hosted: 90);
      expect(historyPreviewAge(rest.window), '90d');
    });

    test('counts up from 7d through the lift and never past 90d', () {
      var last = 0;
      for (var t = 0.0; t < 9; t += 0.05) {
        final window = historyPreviewFrameAt(t, free: 7, hosted: 90).window;
        expect(window, inInclusiveRange(7, 90), reason: '$t');
        last = window;
      }
      expect(last, greaterThanOrEqualTo(7));
    });
  });
}
