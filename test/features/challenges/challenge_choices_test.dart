import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/features/challenges/data/shared_prefs_challenge_choices.dart';
import 'package:critalarm/features/challenges/domain/challenge_gate.dart';
import 'package:critalarm/features/challenges/domain/challenge_incident.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/challenges/domain/challenge_rule.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const ChallengeKind _kind = ChallengeKind.typeTopicName;

void main() {
  late SharedPreferences prefs;
  late SharedPrefsChallengeChoices choices;

  Future<void> start([Map<String, Object> initial = const {}]) async {
    SharedPreferences.setMockInitialValues(initial);
    prefs = await SharedPreferences.getInstance();
    choices = SharedPrefsChallengeChoices(prefs);
    addTearDown(choices.dispose);
  }

  group('the choice', () {
    test('a topic starts with none', () async {
      await start();
      expect(choices.choiceFor('prod-db'), isNull);
      expect(choices.choices, isEmpty);
      expect(choices.defaultForNewTopics, isNull);
    });

    test('is kept under topic_challenge.<topic> as the kind id', () async {
      await start();
      await choices.setChoice('prod-db', _kind);
      expect(prefs.getString('topic_challenge.prod-db'), 'type_topic_name');
      expect(choices.choiceFor('prod-db'), _kind);
      expect(choices.choices, {'prod-db': _kind});
    });

    test('none takes the key away', () async {
      await start({'topic_challenge.prod-db': 'type_topic_name'});
      await choices.setChoice('prod-db', null);
      expect(prefs.containsKey('topic_challenge.prod-db'), isFalse);
      expect(choices.choiceFor('prod-db'), isNull);
    });

    test('an id from a newer build reads as none', () async {
      await start({'topic_challenge.prod-db': 'push_ups'});
      expect(choices.choiceFor('prod-db'), isNull);
      expect(choices.choices, isEmpty);
    });

    test('a key of the wrong type reads as none', () async {
      await start({'topic_challenge.prod-db': 3});
      expect(choices.choiceFor('prod-db'), isNull);
      expect(choices.choices, isEmpty);
    });

    test('a topic name with a dot in it keeps its whole name', () async {
      await start();
      await choices.setChoice('db.eu.1', _kind);
      expect(choices.choices.keys, ['db.eu.1']);
    });

    test('the flag and the default are not read as choices', () async {
      await start({
        'topic_challenge_owed.prod-db': true,
        'topic_challenge_default': 'type_topic_name',
      });
      expect(choices.choices, isEmpty);
    });

    test('a change is announced', () async {
      await start();
      var heard = 0;
      final sub = choices.changes.listen((_) => heard++);
      await choices.setChoice('a', _kind);
      await choices.setDefaultForNewTopics(_kind);
      await Future<void>.delayed(Duration.zero);
      expect(heard, 2);
      await sub.cancel();
    });
  });

  group('the default for new topics', () {
    test('is off until picked, and kept under its own key', () async {
      await start();
      await choices.setDefaultForNewTopics(_kind);
      expect(prefs.getString('topic_challenge_default'), 'type_topic_name');
      expect(choices.defaultForNewTopics, _kind);
      await choices.setDefaultForNewTopics(null);
      expect(prefs.containsKey('topic_challenge_default'), isFalse);
    });

    test('a new topic gets none while the default is off', () async {
      await start();
      await choices.applyDefaultTo('new');
      expect(choices.choiceFor('new'), isNull);
    });

    test('a new topic gets the default', () async {
      await start({'topic_challenge_default': 'type_topic_name'});
      await choices.applyDefaultTo('new');
      expect(choices.choiceFor('new'), _kind);
    });

    test('a topic that exists is not touched by the default', () async {
      await start();
      await choices.setDefaultForNewTopics(_kind);
      expect(choices.choiceFor('old'), isNull);
    });

    test('a new topic never inherits what an old one of its name '
        'left behind', () async {
      await start({'topic_challenge.reused': 'type_topic_name'});
      await choices.applyDefaultTo('reused');
      expect(choices.choiceFor('reused'), isNull);
    });
  });

  group('the flag native reads', () {
    test('is topic_challenge_owed.<topic>, true while owed', () async {
      await start();
      await choices.writeFlag('prod-db', isOwed: true);
      expect(prefs.getBool('topic_challenge_owed.prod-db'), isTrue);
      expect(choices.isFlagged('prod-db'), isTrue);
      expect(choices.flaggedTopics, {'prod-db'});
    });

    test('cleared, it leaves no key', () async {
      await start({'topic_challenge_owed.prod-db': true});
      await choices.writeFlag('prod-db', isOwed: false);
      expect(prefs.containsKey('topic_challenge_owed.prod-db'), isFalse);
      expect(choices.isFlagged('prod-db'), isFalse);
      expect(choices.flaggedTopics, isEmpty);
    });

    test('false, or something that is not a boolean, is not owed', () async {
      await start({
        'topic_challenge_owed.a': false,
        'topic_challenge_owed.b': 'true',
        'topic_challenge_owed.c': true,
      });
      expect(choices.isFlagged('a'), isFalse);
      expect(choices.isFlagged('b'), isFalse);
      expect(choices.flaggedTopics, {'c'});
    });

    test('saving a choice never writes a flag', () async {
      await start();
      await choices.setChoice('prod-db', _kind);
      await choices.setDefaultForNewTopics(_kind);
      await choices.applyDefaultTo('new');
      expect(choices.flaggedTopics, isEmpty);
    });
  });

  group('ChallengeGate', () {
    const incident = ChallengeIncident(topic: 'prod-db');

    ChallengeGate gate({
      FeatureDecision decision = const FeatureDecision.open(),
      Future<void>? planRead,
      bool canRun = true,
    }) => ChallengeGate(
      choices: choices,
      decide: () => decision,
      canRun: (_, _) => canRun,
      planRead: planRead ?? Future<void>.value(),
    );

    ChallengeDue ask(
      ChallengeGate gate, {
      bool reader = false,
      bool cleared = false,
    }) => gate.dueFor(
      incident: incident,
      isScreenReaderOn: reader,
      isCleared: cleared,
    );

    test('no choice, no challenge', () async {
      await start();
      expect(ask(gate()), isA<ChallengeNotOwed>());
    });

    test('a choice with Pro is owed, with the hold as the way out', () async {
      await start({'topic_challenge.prod-db': 'type_topic_name'});
      expect(
        ask(gate()),
        const ChallengeOwed(_kind, wayOut: ChallengeWayOut.hold),
      );
    });

    test('a screen reader gets the tap', () async {
      await start({'topic_challenge.prod-db': 'type_topic_name'});
      expect(
        ask(gate(), reader: true),
        const ChallengeOwed(_kind, wayOut: ChallengeWayOut.tap),
      );
    });

    test('a choice on another topic asks nothing here', () async {
      await start({'topic_challenge.other': 'type_topic_name'});
      expect(ask(gate()), isA<ChallengeNotOwed>());
    });

    test('a sure lock asks nothing, flag or not', () async {
      await start({
        'topic_challenge.prod-db': 'type_topic_name',
        'topic_challenge_owed.prod-db': true,
      });
      final g = gate(decision: const FeatureDecision.locked(Holding.pro));
      await Future<void>.delayed(Duration.zero);
      expect(ask(g), const ChallengeNotOwed(NoChallengeReason.locked));
    });

    test('before the plan is read, "locked" follows the flag', () async {
      await start({
        'topic_challenge.prod-db': 'type_topic_name',
        'topic_challenge_owed.prod-db': true,
      });
      final g = gate(
        decision: const FeatureDecision.locked(Holding.pro),
        planRead: Future<void>.delayed(const Duration(days: 1)),
      );
      expect(ask(g), isA<ChallengeOwed>());
    });

    test('unread with no flag asks nothing', () async {
      await start({'topic_challenge.prod-db': 'type_topic_name'});
      final g = gate(decision: const FeatureDecision.unread(Holding.pro));
      await Future<void>.delayed(Duration.zero);
      expect(ask(g), const ChallengeNotOwed(NoChallengeReason.planUnread));
    });

    test('unread with the flag written stays owed', () async {
      await start({
        'topic_challenge.prod-db': 'type_topic_name',
        'topic_challenge_owed.prod-db': true,
      });
      final g = gate(decision: const FeatureDecision.unread(Holding.pro));
      expect(ask(g), isA<ChallengeOwed>());
    });

    test('a challenge that cannot run asks nothing', () async {
      await start({'topic_challenge.prod-db': 'type_topic_name'});
      expect(
        ask(gate(canRun: false)),
        const ChallengeNotOwed(NoChallengeReason.cannotRun),
      );
    });

    test('cleared by the screen, it is not asked again', () async {
      await start({'topic_challenge.prod-db': 'type_topic_name'});
      final g = gate();
      expect(
        ask(g, cleared: true),
        const ChallengeNotOwed(NoChallengeReason.alreadyCleared),
      );
      expect(ask(g), isA<ChallengeOwed>());
    });

    test('a failure anywhere reads as no challenge', () async {
      await start({'topic_challenge.prod-db': 'type_topic_name'});
      final g = ChallengeGate(
        choices: choices,
        decide: () => throw StateError('access'),
        canRun: (_, _) => true,
        planRead: Future<void>.error(StateError('read')),
      );
      await Future<void>.delayed(Duration.zero);
      expect(ask(g), isA<ChallengeNotOwed>());
    });
  });
}
