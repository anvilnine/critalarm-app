import 'dart:async';

import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/features/incidents/data/shared_prefs_alarm_style_choices.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_assignments.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_gate.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_rule.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _open = FeatureDecision.open();
const _locked = FeatureDecision.locked(Holding.pro);
const _unread = FeatureDecision.unread(Holding.pro);

const _account = 'acct_mine';
final String _mine = alarmStyleAccountTag(_account)!;
final String _theirs = alarmStyleAccountTag('acct_theirs')!;

void main() {
  late SharedPreferences prefs;
  late SharedPrefsAlarmStyleChoices choices;

  Future<void> start([Map<String, Object> initial = const {}]) async {
    SharedPreferences.setMockInitialValues(initial);
    prefs = await SharedPreferences.getInstance();
    choices = SharedPrefsAlarmStyleChoices(prefs);
    addTearDown(choices.dispose);
  }

  group('the store', () {
    test('a phone starts with nothing saved', () async {
      await start();
      expect(choices.assignments, const AlarmStyleAssignments());
      expect(choices.openNote, isNull);
    });

    test('the default is kept under alarm_style_default', () async {
      await start();
      await choices.setDefault('minimal');
      expect(prefs.getString('alarm_style_default'), 'minimal');
      expect(choices.assignments.defaultStyleId, 'minimal');
    });

    test('a topic look is kept under alarm_style_topic.<topic>', () async {
      await start();
      await choices.setTopicStyle('prod-db', 'minimal');
      expect(prefs.getString('alarm_style_topic.prod-db'), 'minimal');
      expect(choices.assignments.perTopic, {'prod-db': 'minimal'});
    });

    test('none takes the key away', () async {
      await start({
        'alarm_style_default': 'minimal',
        'alarm_style_topic.prod-db': 'minimal',
      });
      await choices.setDefault(null);
      await choices.setTopicStyle('prod-db', null);
      expect(prefs.containsKey('alarm_style_default'), isFalse);
      expect(prefs.containsKey('alarm_style_topic.prod-db'), isFalse);
      expect(choices.assignments, const AlarmStyleAssignments());
    });

    test('a deleted topic takes its look along and no other', () async {
      await start({
        'alarm_style_topic.prod-db': 'minimal',
        'alarm_style_topic.staging': 'minimal',
      });
      await choices.forgetTopic('prod-db');
      expect(choices.assignments.perTopic, {'staging': 'minimal'});
    });

    test('an id from a newer build is kept as it was written', () async {
      await start({'alarm_style_topic.prod-db': 'red_alert'});
      expect(choices.assignments.perTopic, {'prod-db': 'red_alert'});
    });

    test('a key of the wrong type reads as not there', () async {
      await start({
        'alarm_style_default': 7,
        'alarm_style_topic.prod-db': true,
        'alarm_style_open_when_last_sure': true,
      });
      expect(choices.assignments, const AlarmStyleAssignments());
      expect(choices.openNote, isNull);
    });

    test('the note is one key, gone again when cleared', () async {
      await start();
      await choices.writeOpenNote(_mine);
      expect(prefs.getString('alarm_style_open_when_last_sure'), _mine);
      expect(choices.openNote, _mine);
      await choices.writeOpenNote(null);
      expect(prefs.containsKey('alarm_style_open_when_last_sure'), isFalse);
    });

    test('a saved choice fires a change, the note does not', () async {
      await start();
      var fired = 0;
      final subscription = choices.changes.listen((_) => fired++);
      addTearDown(subscription.cancel);
      await choices.setDefault('minimal');
      await choices.setTopicStyle('prod-db', 'minimal');
      await choices.writeOpenNote(_mine);
      await Future<void>.delayed(Duration.zero);
      expect(fired, 2);
    });
  });

  group('the gate', () {
    late FeatureDecision now;
    late Completer<void> planRead;
    late bool isUnreadable;
    late String? account;

    var isOwnLookReady = false;

    AlarmStyleGate gate({Stream<Object?>? changes}) => AlarmStyleGate(
      isOwnLookReady: () => isOwnLookReady,
      choices: choices,
      decide: () => now,
      decideOnceReady: () async {
        await planRead.future;
        if (isUnreadable) throw const HoldingUnreadable(Holding.pro);
        return now;
      },
      readAccountId: () async => account,
      planRead: planRead.future,
      changes: [?changes],
    );

    setUp(() {
      isOwnLookReady = false;
      now = _open;
      planRead = Completer<void>();
      isUnreadable = false;
      account = _account;
    });

    test('draws what the rule says for a topic and for the phone', () async {
      await start({
        'alarm_style_default': 'standard',
        'alarm_style_topic.prod-db': 'minimal',
      });
      final styles = gate();
      expect(styles.styleFor('prod-db'), AlarmStyleId.minimal);
      expect(styles.styleFor('staging'), AlarmStyleId.standard);
      expect(styles.styleFor(null), AlarmStyleId.standard);
      expect(
        styles.styleFor('prod-db', isSetupAlarm: true),
        AlarmStyleId.standard,
      );
    });

    test('the own look draws only while its photo is held, and is asked '
        'each time', () async {
      await start({'alarm_style_default': 'own'});
      final styles = gate();
      expect(styles.styleFor('prod-db'), AlarmStyleId.standard);
      isOwnLookReady = true;
      expect(styles.styleFor('prod-db'), AlarmStyleId.own);
      // The photo was removed, or the account left.
      isOwnLookReady = false;
      expect(styles.styleFor('prod-db'), AlarmStyleId.standard);
      // What is saved was never touched.
      expect(choices.assignments.defaultStyleId, 'own');
    });

    test('a gate that is told nothing about the photo never draws the own '
        'look', () async {
      await start({'alarm_style_default': 'own'});
      final styles = AlarmStyleGate(
        choices: choices,
        decide: () => _open,
        decideOnceReady: () async => _open,
        readAccountId: () async => _account,
        planRead: Future<void>.value(),
      );
      expect(styles.styleFor(null), AlarmStyleId.standard);
    });

    test('a sure lock draws Standard and keeps what is saved, and the plan '
        'coming back draws Minimal again', () async {
      await start({'alarm_style_topic.prod-db': 'minimal'});
      final styles = gate();
      planRead.complete();
      await styles.check();
      expect(styles.styleFor('prod-db'), AlarmStyleId.minimal);

      now = _locked;
      await styles.check();
      expect(styles.styleFor('prod-db'), AlarmStyleId.standard);
      expect(prefs.getString('alarm_style_topic.prod-db'), 'minimal');
      expect(choices.openNote, isNull);

      now = _open;
      expect(styles.styleFor('prod-db'), AlarmStyleId.minimal);
    });

    test('a lock from before the plan is read takes nothing from a phone '
        'whose last sure answer was open', () async {
      await start({
        'alarm_style_topic.prod-db': 'minimal',
        'alarm_style_open_when_last_sure': _mine,
      });
      now = _locked;
      final styles = gate();
      // Until this phone's account is known the note counts for nobody.
      expect(styles.styleFor('prod-db'), AlarmStyleId.standard);
      final checking = styles.check();
      await Future<void>.delayed(Duration.zero);
      expect(styles.styleFor('prod-db'), AlarmStyleId.minimal);

      // Read, and it really is locked: now it is sure.
      planRead.complete();
      await checking;
      expect(styles.styleFor('prod-db'), AlarmStyleId.standard);
    });

    test('an unreadable plan keeps drawing for a phone that held it, and '
        'leaves the note alone', () async {
      await start({
        'alarm_style_topic.prod-db': 'minimal',
        'alarm_style_open_when_last_sure': _mine,
      });
      now = _unread;
      isUnreadable = true;
      planRead.complete();
      final styles = gate();
      await styles.check();
      expect(choices.openNote, _mine);
      expect(styles.styleFor('prod-db'), AlarmStyleId.minimal);
    });

    test('an unreadable plan gives nothing to a phone that never held '
        'it', () async {
      await start({'alarm_style_topic.prod-db': 'minimal'});
      now = _unread;
      isUnreadable = true;
      planRead.complete();
      final styles = gate();
      await styles.check();
      expect(choices.openNote, isNull);
      expect(styles.styleFor('prod-db'), AlarmStyleId.standard);
    });

    test('a note restored from a backup of another account gives '
        'nothing', () async {
      await start({
        'alarm_style_topic.prod-db': 'minimal',
        'alarm_style_open_when_last_sure': _theirs,
      });
      now = _unread;
      isUnreadable = true;
      planRead.complete();
      final styles = gate();
      await styles.check();
      expect(styles.styleFor('prod-db'), AlarmStyleId.standard);
      // Nobody knows, so the note itself is left as it was found.
      expect(choices.openNote, _theirs);
    });

    test('a note restored onto a phone with no account gives '
        'nothing', () async {
      await start({
        'alarm_style_topic.prod-db': 'minimal',
        'alarm_style_open_when_last_sure': _mine,
      });
      account = null;
      now = _unread;
      isUnreadable = true;
      planRead.complete();
      final styles = gate();
      await styles.check();
      expect(styles.styleFor('prod-db'), AlarmStyleId.standard);
    });

    test('a sure open on this account replaces the note of another '
        'account', () async {
      await start({'alarm_style_open_when_last_sure': _theirs});
      planRead.complete();
      await gate().check();
      expect(choices.openNote, _mine);
    });

    test('notes a sure open once the plan is read, and not before', () async {
      await start();
      final styles = gate();
      final checking = styles.check();
      await Future<void>.delayed(Duration.zero);
      expect(choices.openNote, isNull);
      planRead.complete();
      await checking;
      expect(choices.openNote, _mine);
    });

    test('checks again when the answer changes', () async {
      await start();
      planRead.complete();
      final changes = StreamController<Object?>.broadcast();
      addTearDown(changes.close);
      final styles = gate(changes: changes.stream)..start();
      addTearDown(styles.dispose);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(choices.openNote, _mine);

      now = _locked;
      changes.add(null);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(choices.openNote, isNull);
    });

    test('never throws: a decision that cannot be asked draws '
        'Standard', () async {
      await start({'alarm_style_default': 'minimal'});
      final styles = AlarmStyleGate(
        choices: choices,
        decide: () => throw StateError('no access layer'),
        decideOnceReady: () async => throw StateError('no access layer'),
        readAccountId: () async => throw StateError('no identity'),
        planRead: Future<void>.error(StateError('never read')),
      );
      expect(styles.styleFor('prod-db'), AlarmStyleId.standard);
      await styles.check();
      expect(choices.openNote, isNull);
    });
  });
}
