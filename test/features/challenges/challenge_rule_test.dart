import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/challenges/domain/challenge_rule.dart';
import 'package:flutter_test/flutter_test.dart';

const _open = FeatureDecision.open();
const _locked = FeatureDecision.locked(Holding.pro);
const _confirming = FeatureDecision.confirming(Holding.pro);
const _unread = FeatureDecision.unread(Holding.pro);

const ChallengeKind _kind = ChallengeKind.typeTopicName;
const _hold = ChallengeOwed(_kind, wayOut: ChallengeWayOut.hold);
const _tap = ChallengeOwed(_kind, wayOut: ChallengeWayOut.tap);

ChallengeNotOwed _no(NoChallengeReason reason) => ChallengeNotOwed(reason);

/// One row of the table: what goes in, and what must come out.
typedef _Case = ({
  String name,
  ChallengeKind? choice,
  FeatureDecision decision,
  bool isPlanRead,
  bool wasOwed,
  bool canRun,
  bool reader,
  bool cleared,
  ChallengeDue want,
});

_Case _row(
  String name,
  ChallengeDue want, {
  ChallengeKind? choice = _kind,
  FeatureDecision decision = _open,
  bool isPlanRead = true,
  bool wasOwed = false,
  bool canRun = true,
  bool reader = false,
  bool cleared = false,
}) => (
  name: name,
  choice: choice,
  decision: decision,
  isPlanRead: isPlanRead,
  wasOwed: wasOwed,
  canRun: canRun,
  reader: reader,
  cleared: cleared,
  want: want,
);

final _cases = <_Case>[
  // Off by default: no choice means no challenge, whatever is held.
  _row('no choice, Pro held', _no(NoChallengeReason.noneSet), choice: null),
  _row(
    'no choice, nothing held',
    _no(NoChallengeReason.noneSet),
    choice: null,
    decision: _locked,
  ),
  _row(
    'no choice, plan unread, a flag left over',
    _no(NoChallengeReason.noneSet),
    choice: null,
    decision: _unread,
    wasOwed: true,
  ),

  // Open.
  _row('chosen, Pro held', _hold),
  _row('chosen, Pro held, flag already written', _hold, wasOwed: true),
  _row('chosen, purchase being confirmed', _hold, decision: _confirming),

  // Locked: nothing runs, even with a choice saved from before.
  _row(
    'chosen, nothing held',
    _no(NoChallengeReason.locked),
    decision: _locked,
  ),
  _row(
    'chosen earlier, Pro ended, the flag not cleared yet',
    _no(NoChallengeReason.locked),
    decision: _locked,
    wasOwed: true,
  ),

  // The plan could not be read: owed only if the last sure answer was.
  _row(
    'chosen, plan unread, last sure answer was open',
    _hold,
    decision: _unread,
    wasOwed: true,
  ),
  _row(
    'chosen, plan unread, never a sure open',
    _no(NoChallengeReason.planUnread),
    decision: _unread,
  ),
  // Unread, then locked: the sure "locked" wins over what was written.
  _row(
    'chosen, plan was unread and now reads locked',
    _no(NoChallengeReason.locked),
    decision: _locked,
    wasOwed: true,
  ),

  // A cold start: "locked" before the plan is read is not a sure lock.
  _row(
    'chosen, plan not read yet, says locked, last sure answer was open',
    _hold,
    decision: _locked,
    isPlanRead: false,
    wasOwed: true,
  ),
  _row(
    'chosen, plan not read yet, says locked, never a sure open',
    _no(NoChallengeReason.planUnread),
    decision: _locked,
    isPlanRead: false,
  ),
  _row(
    'chosen, plan not read yet, already says open',
    _hold,
    isPlanRead: false,
  ),

  // A challenge that cannot run for this alarm asks for nothing.
  _row(
    'chosen, cannot run for this alarm',
    _no(NoChallengeReason.cannotRun),
    canRun: false,
  ),
  _row(
    'chosen, cannot run, plan unread with a flag',
    _no(NoChallengeReason.cannotRun),
    canRun: false,
    decision: _unread,
    wasOwed: true,
  ),

  // A screen reader keeps the challenge and makes the way out a tap.
  _row('chosen, Pro held, screen reader on', _tap, reader: true),
  _row(
    'chosen, plan unread with a flag, screen reader on',
    _tap,
    decision: _unread,
    wasOwed: true,
    reader: true,
  ),
  _row(
    'chosen, nothing held, screen reader on',
    _no(NoChallengeReason.locked),
    decision: _locked,
    reader: true,
  ),
  _row(
    'no choice, screen reader on',
    _no(NoChallengeReason.noneSet),
    choice: null,
    reader: true,
  ),

  // Passed or left once: a close that failed is not asked for twice.
  _row(
    'chosen, Pro held, already cleared for this incident',
    _no(NoChallengeReason.alreadyCleared),
    cleared: true,
  ),
];

void main() {
  group('challengeDueFor', () {
    for (final c in _cases) {
      test(c.name, () {
        expect(
          challengeDueFor(
            choice: c.choice,
            decision: c.decision,
            isPlanRead: c.isPlanRead,
            wasOwedWhenLastSure: c.wasOwed,
            canRun: c.canRun,
            isScreenReaderOn: c.reader,
            isCleared: c.cleared,
          ),
          c.want,
        );
      });
    }

    test('every combination either owes the chosen kind or nothing', () {
      for (final choice in [null, _kind]) {
        for (final decision in [_open, _locked, _confirming, _unread]) {
          for (final flags in List.generate(32, (i) => i)) {
            bool bit(int n) => flags & (1 << n) != 0;
            final due = challengeDueFor(
              choice: choice,
              decision: decision,
              isPlanRead: bit(0),
              wasOwedWhenLastSure: bit(1),
              canRun: bit(2),
              isScreenReaderOn: bit(3),
              isCleared: bit(4),
            );
            if (due is! ChallengeOwed) continue;
            // Never without a choice, never on a sure lock, never for a
            // challenge that cannot run, never twice.
            expect(choice, isNotNull);
            expect(due.kind, choice);
            expect(bit(2), isTrue);
            expect(bit(4), isFalse);
            expect(decision is FeatureLocked && bit(0), isFalse);
            // The way out is there in both forms and follows the reader.
            expect(
              due.wayOut,
              bit(3) ? ChallengeWayOut.tap : ChallengeWayOut.hold,
            );
          }
        }
      }
    });
  });

  group('challengeFlagChangesFor', () {
    ChallengeFlagChanges changes({
      required Set<String> chosen,
      required Set<String> written,
      required FeatureDecision? decision,
    }) => challengeFlagChangesFor(
      topicsWithChoice: chosen,
      written: written,
      decision: decision,
    );

    test('open sets a flag for every topic with a choice', () {
      final c = changes(chosen: {'a', 'b'}, written: {}, decision: _open);
      expect(c.set, {'a', 'b'});
      expect(c.clear, isEmpty);
    });

    test('a purchase being confirmed counts as open', () {
      final c = changes(chosen: {'a'}, written: {}, decision: _confirming);
      expect(c.set, {'a'});
    });

    test('open writes nothing that is already written', () {
      final c = changes(chosen: {'a'}, written: {'a'}, decision: _open);
      expect(c.isEmpty, isTrue);
    });

    test('locked clears every flag and sets none', () {
      final c = changes(
        chosen: {'a', 'b'},
        written: {'a', 'b'},
        decision: _locked,
      );
      expect(c.set, isEmpty);
      expect(c.clear, {'a', 'b'});
    });

    test('locked on a phone with no flag writes nothing', () {
      final c = changes(chosen: {'a'}, written: {}, decision: _locked);
      expect(c.isEmpty, isTrue);
    });

    test('unread keeps the flags of topics that still have a choice', () {
      final c = changes(chosen: {'a', 'b'}, written: {'a'}, decision: _unread);
      expect(c.isEmpty, isTrue);
    });

    test('nobody knows keeps them too, and sets none', () {
      final c = changes(chosen: {'a', 'b'}, written: {'a'}, decision: null);
      expect(c.isEmpty, isTrue);
    });

    test('a topic whose choice was taken away is cleared on any answer', () {
      for (final decision in [_open, _locked, _confirming, _unread, null]) {
        final c = changes(chosen: {}, written: {'gone'}, decision: decision);
        expect(c.clear, {'gone'}, reason: '$decision');
        expect(c.set, isEmpty, reason: '$decision');
      }
    });

    test('no answer ever sets a flag for a topic with no choice', () {
      for (final decision in [_open, _locked, _confirming, _unread, null]) {
        final c = changes(chosen: {}, written: {}, decision: decision);
        expect(c.isEmpty, isTrue, reason: '$decision');
      }
    });
  });
}
