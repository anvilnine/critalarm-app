import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_rule.dart';
import 'package:flutter_test/flutter_test.dart';

import 'missed_alarm_fixtures.dart';

void main() {
  MissedVerdict verdict({
    Incident? incident,
    bool? topicIsCritical = true,
    PhoneKnowledge knowledge = PhoneKnowledge.none,
    MissedAlarmCutoffs? cutoffs,
    bool isSetupTest = false,
  }) => missedVerdictFor(
    incident: incident ?? incidentFixture(),
    topicIsCritical: topicIsCritical,
    knowledge: knowledge,
    cutoffs: cutoffs ?? cutoffsLongAgo,
    isSetupTest: isSetupTest,
  );

  const missed = MissedVerdict.missed;
  const notMissed = MissedVerdict.notMissed;

  group('reasons', () {
    test('no push reached the phone', () {
      expect(
        verdict(knowledge: const PhoneKnowledge(silenceMeansNoPush: true)),
        missed(MissedReason.noPushReached),
      );
    });

    test('a push arrived and nothing rang', () {
      expect(
        verdict(
          knowledge: const PhoneKnowledge(
            pushReached: true,
            ringKnownNotStarted: true,
          ),
        ),
        missed(MissedReason.pushButNoRing),
      );
    });

    test('it rang and nobody acknowledged', () {
      expect(
        verdict(
          knowledge: const PhoneKnowledge(rang: true, pushReached: true),
        ),
        missed(MissedReason.rangUnanswered),
      );
    });

    test('a ring on record wins over a silent record', () {
      expect(
        verdict(
          knowledge: const PhoneKnowledge(
            rang: true,
            silenceMeansNoPush: true,
          ),
        ),
        missed(MissedReason.rangUnanswered),
      );
    });
  });

  group('the phone lacks the data to tell reasons apart', () {
    test('nothing on record names no cause', () {
      expect(verdict(), missed(MissedReason.unanswered));
    });

    test('a push with no word on the ring names no cause', () {
      // It could have rung for nobody, or not rung at all.
      expect(
        verdict(knowledge: const PhoneKnowledge(pushReached: true)),
        missed(MissedReason.unanswered),
      );
    });

    test('"did not ring" without a push on record names no cause', () {
      expect(
        verdict(knowledge: const PhoneKnowledge(ringKnownNotStarted: true)),
        missed(MissedReason.unanswered),
      );
    });
  });

  group('not missed', () {
    test('acknowledged on another device', () {
      expect(
        verdict(
          incident: incidentFixture(
            ackedAt: opened.add(const Duration(minutes: 2)),
          ),
        ),
        notMissed(NotMissedReason.acknowledgedElsewhere),
      );
    });

    test('closed, so it was acknowledged first', () {
      expect(
        verdict(incident: incidentFixture(state: IncidentStates.closed)),
        notMissed(NotMissedReason.acknowledgedElsewhere),
      );
    });

    test('acknowledged on this phone, even if the server never heard', () {
      expect(
        verdict(knowledge: const PhoneKnowledge(acknowledgedHere: true)),
        notMissed(NotMissedReason.acknowledgedHere),
      );
    });

    test('the phone was not connected to this server when it opened', () {
      expect(
        verdict(
          cutoffs: MissedAlarmCutoffs(
            firstLaunchAt: cutoffsLongAgo.firstLaunchAt,
            setupDoneAt: cutoffsLongAgo.setupDoneAt,
            connectedSince: opened.add(const Duration(minutes: 1)),
          ),
        ),
        notMissed(NotMissedReason.notConnected),
      );
    });

    test('a connection the phone never saw counts as not connected', () {
      expect(
        verdict(
          cutoffs: MissedAlarmCutoffs(
            firstLaunchAt: cutoffsLongAgo.firstLaunchAt,
            setupDoneAt: cutoffsLongAgo.setupDoneAt,
            connectedSince: null,
          ),
        ),
        notMissed(NotMissedReason.notConnected),
      );
    });

    test('an incident still open', () {
      expect(
        verdict(incident: incidentFixture(state: IncidentStates.open)),
        notMissed(NotMissedReason.stillOpen),
      );
    });

    test('an acknowledged incident still going', () {
      expect(
        verdict(
          incident: incidentFixture(
            state: IncidentStates.acked,
            ackedAt: opened.add(const Duration(minutes: 1)),
          ),
        ),
        notMissed(NotMissedReason.stillOpen),
      );
    });

    test('a topic that is not critical', () {
      expect(
        verdict(topicIsCritical: false),
        notMissed(NotMissedReason.topicNotCritical),
      );
    });

    test('a topic that is gone or could not be read', () {
      expect(
        verdict(topicIsCritical: null),
        notMissed(NotMissedReason.topicNotCritical),
      );
    });

    test('priority 4', () {
      expect(
        verdict(incident: incidentFixture(priority: 4)),
        notMissed(NotMissedReason.belowPriorityFive),
      );
    });

    test('no opening time', () {
      expect(
        verdict(incident: incidentFixture(hasOpenedAt: false)),
        notMissed(NotMissedReason.timeUnknown),
      );
    });

    test('an alarm setup rang on purpose', () {
      expect(
        verdict(isSetupTest: true),
        notMissed(NotMissedReason.setupTest),
      );
    });
  });

  group('cut-offs', () {
    test('older than the first launch', () {
      expect(
        verdict(
          cutoffs: MissedAlarmCutoffs(
            firstLaunchAt: opened.add(const Duration(seconds: 1)),
            setupDoneAt: opened.add(const Duration(seconds: 1)),
            connectedSince: opened.add(const Duration(seconds: 1)),
          ),
        ),
        notMissed(NotMissedReason.beforeFirstLaunch),
      );
    });

    test('a first launch nobody stamped', () {
      expect(
        verdict(
          cutoffs: MissedAlarmCutoffs(
            firstLaunchAt: null,
            setupDoneAt: cutoffsLongAgo.setupDoneAt,
            connectedSince: cutoffsLongAgo.connectedSince,
          ),
        ),
        notMissed(NotMissedReason.beforeFirstLaunch),
      );
    });

    test('opened while setup was unfinished', () {
      expect(
        verdict(
          cutoffs: MissedAlarmCutoffs(
            firstLaunchAt: cutoffsLongAgo.firstLaunchAt,
            setupDoneAt: opened.add(const Duration(minutes: 5)),
            connectedSince: cutoffsLongAgo.connectedSince,
          ),
        ),
        notMissed(NotMissedReason.setupUnfinished),
      );
    });

    test('setup never finished', () {
      expect(
        verdict(
          cutoffs: MissedAlarmCutoffs(
            firstLaunchAt: cutoffsLongAgo.firstLaunchAt,
            setupDoneAt: null,
            connectedSince: cutoffsLongAgo.connectedSince,
          ),
        ),
        notMissed(NotMissedReason.setupUnfinished),
      );
    });

    test('opened at the very moment setup finished counts', () {
      expect(
        verdict(
          cutoffs: MissedAlarmCutoffs(
            firstLaunchAt: opened,
            setupDoneAt: opened,
            connectedSince: opened,
          ),
        ).isMissed,
        isTrue,
      );
    });

    test('a strong record does not get past a cut-off', () {
      expect(
        verdict(
          knowledge: const PhoneKnowledge(rang: true, pushReached: true),
          cutoffs: MissedAlarmCutoffs(
            firstLaunchAt: cutoffsLongAgo.firstLaunchAt,
            setupDoneAt: opened.add(const Duration(minutes: 5)),
            connectedSince: cutoffsLongAgo.connectedSince,
          ),
        ).isMissed,
        isFalse,
      );
    });
  });

  test('every reason has its own code', () {
    expect(
      MissedReason.values.map((reason) => reason.code).toSet(),
      {'no_push', 'push_no_ring', 'rang', 'unanswered'},
    );
  });
}
