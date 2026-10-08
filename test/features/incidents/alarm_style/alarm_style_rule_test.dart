import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_assignments.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_rule.dart';
import 'package:flutter_test/flutter_test.dart';

const _open = FeatureDecision.open();
const _locked = FeatureDecision.locked(Holding.pro);
const _confirming = FeatureDecision.confirming(Holding.pro);
const _unread = FeatureDecision.unread(Holding.pro);

const AlarmStyleId _standard = AlarmStyleId.standard;
const AlarmStyleId _minimal = AlarmStyleId.minimal;

/// A phone whose default is Minimal.
const _phoneMinimal = AlarmStyleAssignments(defaultStyleId: 'minimal');

/// A phone on the standard look where one topic picked Minimal.
const _topicMinimal = AlarmStyleAssignments(perTopic: {'prod-db': 'minimal'});

AlarmStyleId _draws({
  required AlarmStyleAssignments saved,
  required FeatureDecision decision,
  String? topic = 'prod-db',
  bool isPlanRead = true,
  bool wasOpenWhenLastSure = false,
  bool isSetupAlarm = false,
}) => alarmStyleFor(
  saved: saved,
  topicName: topic,
  decision: decision,
  isPlanRead: isPlanRead,
  wasOpenWhenLastSure: wasOpenWhenLastSure,
  isSetupAlarm: isSetupAlarm,
);

void main() {
  group('AlarmStyleId', () {
    test('the ids saved on phones never change', () {
      expect(
        {for (final style in AlarmStyleId.values) style.name: style.id},
        {'standard': 'standard', 'minimal': 'minimal'},
      );
    });

    test('ids are used once', () {
      final ids = AlarmStyleId.values.map((style) => style.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('only the standard look is free', () {
      expect(
        AlarmStyleId.values.where((style) => style.isFree),
        [_standard],
      );
    });

    test('an id this build does not know reads as none', () {
      expect(AlarmStyleId.fromId('minimal'), _minimal);
      expect(AlarmStyleId.fromId('red_alert_from_a_newer_build'), isNull);
      expect(AlarmStyleId.fromId(''), isNull);
      expect(AlarmStyleId.fromId(null), isNull);
    });
  });

  group('AlarmStyleAssignments', () {
    test('a topic with no look of its own uses the phone default', () {
      const saved = AlarmStyleAssignments(
        defaultStyleId: 'minimal',
        perTopic: {'prod-db': 'standard'},
      );
      expect(saved.styleIdFor('prod-db'), 'standard');
      expect(saved.styleIdFor('staging'), 'minimal');
      expect(saved.styleIdFor(null), 'minimal');
    });

    test('nothing saved is no id at all', () {
      expect(const AlarmStyleAssignments().styleIdFor('prod-db'), isNull);
    });

    test('changes come back as a new value', () {
      const saved = AlarmStyleAssignments();
      final next = saved
          .withDefault('minimal')
          .withTopicStyle('prod-db', 'standard');
      expect(saved, const AlarmStyleAssignments());
      expect(
        next,
        const AlarmStyleAssignments(
          defaultStyleId: 'minimal',
          perTopic: {'prod-db': 'standard'},
        ),
      );
      expect(
        next.withTopicStyle('prod-db', null),
        const AlarmStyleAssignments(defaultStyleId: 'minimal'),
      );
      expect(next.withDefault(null).defaultStyleId, isNull);
    });
  });

  group('alarmStyleFor', () {
    test('nothing saved draws the standard look on every answer', () {
      for (final decision in [_open, _locked, _confirming, _unread]) {
        expect(
          _draws(saved: const AlarmStyleAssignments(), decision: decision),
          _standard,
          reason: '$decision',
        );
      }
    });

    test('the standard look saved draws on every answer', () {
      const saved = AlarmStyleAssignments(
        defaultStyleId: 'minimal',
        perTopic: {'prod-db': 'standard'},
      );
      for (final decision in [_open, _locked, _confirming, _unread]) {
        expect(
          _draws(saved: saved, decision: decision, wasOpenWhenLastSure: true),
          _standard,
          reason: '$decision',
        );
      }
    });

    test('an id from a newer build draws the standard look', () {
      const saved = AlarmStyleAssignments(
        perTopic: {'prod-db': 'red_alert_from_a_newer_build'},
      );
      expect(_draws(saved: saved, decision: _open), _standard);
    });

    // Every case of a paid look saved, for the topic's own choice and for
    // the phone default alike.
    //   decision, plan read, open when last sure -> drawn
    const table = <(FeatureDecision, bool, bool, AlarmStyleId)>[
      (_open, true, false, _minimal),
      (_open, true, true, _minimal),
      (_open, false, false, _minimal),
      (_open, false, true, _minimal),
      (_confirming, true, false, _minimal),
      (_confirming, true, true, _minimal),
      (_confirming, false, false, _minimal),
      (_confirming, false, true, _minimal),
      // A sure lock draws the standard look, whatever was noted before.
      (_locked, true, false, _standard),
      (_locked, true, true, _standard),
      // A lock from before the plan was read is not sure.
      (_locked, false, false, _standard),
      (_locked, false, true, _minimal),
      // The plan could not be read: nothing is taken away from someone
      // whose last sure answer was open, and nothing is given otherwise.
      (_unread, true, false, _standard),
      (_unread, true, true, _minimal),
      (_unread, false, false, _standard),
      (_unread, false, true, _minimal),
    ];

    for (final (decision, isPlanRead, wasOpen, drawn) in table) {
      final when =
          '$decision, plan ${isPlanRead ? 'read' : 'not read'}, '
          'last sure answer ${wasOpen ? 'open' : 'not open'}';
      test('a paid look, $when: ${drawn.id}', () {
        expect(
          _draws(
            saved: _topicMinimal,
            decision: decision,
            isPlanRead: isPlanRead,
            wasOpenWhenLastSure: wasOpen,
          ),
          drawn,
          reason: 'the topic picked it',
        );
        expect(
          _draws(
            saved: _phoneMinimal,
            decision: decision,
            isPlanRead: isPlanRead,
            wasOpenWhenLastSure: wasOpen,
          ),
          drawn,
          reason: 'the phone default',
        );
        expect(
          _draws(
            saved: _phoneMinimal,
            topic: null,
            decision: decision,
            isPlanRead: isPlanRead,
            wasOpenWhenLastSure: wasOpen,
          ),
          drawn,
          reason: 'asked for the phone itself',
        );
      });
    }

    test('another topic is not touched by one topic choice', () {
      expect(
        _draws(saved: _topicMinimal, topic: 'staging', decision: _open),
        _standard,
      );
    });

    test('without Pro a topic set to Minimal draws Standard, and with Pro '
        'again it draws Minimal with no other step', () {
      // The same saved value all the way through: the rule never
      // rewrites it.
      const saved = _topicMinimal;
      expect(_draws(saved: saved, decision: _open), _minimal);
      expect(_draws(saved: saved, decision: _locked), _standard);
      expect(_draws(saved: saved, decision: _unread), _standard);
      expect(_draws(saved: saved, decision: _open), _minimal);
      expect(saved, _topicMinimal);
    });

    test('a setup alarm always draws the standard look', () {
      for (final decision in [_open, _locked, _confirming, _unread]) {
        expect(
          _draws(
            saved: _phoneMinimal,
            decision: decision,
            wasOpenWhenLastSure: true,
            isSetupAlarm: true,
          ),
          _standard,
          reason: '$decision',
        );
      }
    });
  });

  group('the note of the last sure answer', () {
    final mine = alarmStyleAccountTag('acct_mine');
    final theirs = alarmStyleAccountTag('acct_theirs');

    test('is kept under a hash of the account, never the id', () {
      expect(mine, isNotNull);
      expect(mine, hasLength(16));
      expect(mine, isNot(contains('acct_mine')));
      expect(mine, alarmStyleAccountTag('acct_mine'));
      expect(mine, isNot(theirs));
      expect(alarmStyleAccountTag(null), isNull);
      expect(alarmStyleAccountTag(''), isNull);
    });

    test('counts only for the account the phone is on', () {
      expect(openNoteCountsFor(noteTag: mine, accountTag: mine), isTrue);
      // Restored from a backup onto a phone on another account.
      expect(openNoteCountsFor(noteTag: theirs, accountTag: mine), isFalse);
      // The account is not known yet, or the phone has none.
      expect(openNoteCountsFor(noteTag: mine, accountTag: null), isFalse);
      expect(openNoteCountsFor(noteTag: null, accountTag: mine), isFalse);
      expect(openNoteCountsFor(noteTag: null, accountTag: null), isFalse);
    });

    test('only a sure answer changes it', () {
      for (final written in [mine, theirs, null]) {
        expect(
          openNoteAfter(written: written, decision: _open, accountTag: mine),
          mine,
        );
        expect(
          openNoteAfter(
            written: written,
            decision: _confirming,
            accountTag: mine,
          ),
          mine,
        );
        expect(
          openNoteAfter(written: written, decision: _locked, accountTag: mine),
          isNull,
        );
        expect(
          openNoteAfter(written: written, decision: _unread, accountTag: mine),
          written,
        );
        expect(
          openNoteAfter(written: written, decision: null, accountTag: mine),
          written,
        );
      }
    });

    test('an open answer with no account known leaves no note', () {
      expect(
        openNoteAfter(written: theirs, decision: _open, accountTag: null),
        isNull,
      );
    });
  });
}
