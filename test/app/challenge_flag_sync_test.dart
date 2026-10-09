import 'dart:async';

import 'package:critalarm/app/challenge_flag_sync.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/access/access_fakes.dart';

const _open = FeatureDecision.open();
const _locked = FeatureDecision.locked(Holding.pro);

void main() {
  /// The topics that have a challenge chosen.
  late Set<String> chosen;

  /// The flags on the phone.
  late Set<String> written;

  /// Every write, in order: `+topic` sets, `-topic` clears.
  late List<String> writes;
  late int publishes;
  late int redraws;

  /// What the next publish answers. A test sets it to fail one.
  late Future<bool> Function() publishAnswer;

  ChallengeFlagSync build({
    required Future<FeatureDecision> Function() decide,
    List<Stream<Object?>> changes = const [],
    Future<void> Function(String topic, {required bool isOwed})? write,
    Set<String> Function()? readWritten,
    Set<String> Function()? readChoices,
  }) {
    final sync = ChallengeFlagSync(
      decide: decide,
      changes: changes,
      readChoices: readChoices ?? () => chosen,
      readWritten: readWritten ?? () => {...written},
      write:
          write ??
          (topic, {required isOwed}) async {
            if (isOwed) {
              written.add(topic);
            } else {
              written.remove(topic);
            }
            writes.add('${isOwed ? '+' : '-'}$topic');
          },
      publish: () {
        publishes++;
        return publishAnswer();
      },
      redraw: () => redraws++,
    );
    addTearDown(sync.dispose);
    return sync;
  }

  setUp(() {
    chosen = {'prod'};
    written = {};
    writes = [];
    publishes = 0;
    redraws = 0;
    publishAnswer = () async => true;
  });

  group('one check', () {
    test('a sure open sets the flag and publishes it', () async {
      await build(decide: () async => _open).check();
      expect(writes, ['+prod']);
      expect(written, {'prod'});
      expect(publishes, 1);
    });

    test('a sure locked on a phone with no flag writes nothing', () async {
      await build(decide: () async => _locked).check();
      expect(writes, isEmpty);
      expect(publishes, 0);
    });

    test('a sure locked clears a flag that was set', () async {
      written = {'prod'};
      await build(decide: () async => _locked).check();
      expect(writes, ['-prod']);
      expect(written, isEmpty);
      expect(publishes, 1);
    });

    test('a purchase being confirmed counts as open', () async {
      await build(
        decide: () async => const FeatureDecision.confirming(Holding.pro),
      ).check();
      expect(writes, ['+prod']);
    });

    test('the same answer as last time writes nothing', () async {
      written = {'prod'};
      await build(decide: () async => _open).check();
      expect(writes, isEmpty);
      expect(publishes, 0);
    });

    test('only topics with a challenge chosen are flagged', () async {
      chosen = {'prod', 'db'};
      await build(decide: () async => _open).check();
      expect(written, {'prod', 'db'});
    });

    test('no topic has a challenge: open writes nothing', () async {
      chosen = {};
      await build(decide: () async => _open).check();
      expect(writes, isEmpty);
      expect(written, isEmpty);
    });

    test('a plan that could not be read leaves a set flag as it was', () async {
      written = {'prod'};
      await build(
        decide: () async => throw const HoldingUnreadable(Holding.pro),
      ).check();
      expect(writes, isEmpty);
      expect(written, {'prod'});
    });

    test('a plan that could not be read never sets a first flag', () async {
      await build(
        decide: () async => throw const HoldingUnreadable(Holding.pro),
      ).check();
      expect(writes, isEmpty);
      expect(written, isEmpty);
    });

    test('an unread decision is treated the same', () async {
      written = {'prod'};
      chosen = {'prod', 'db'};
      await build(
        decide: () async => const FeatureDecision.unread(Holding.pro),
      ).check();
      expect(writes, isEmpty);
      expect(written, {'prod'});
    });

    test('any other failure of the question sets nothing', () async {
      await build(decide: () async => throw StateError('boom')).check();
      expect(writes, isEmpty);
    });

    test('a challenge switched off clears its flag even while the plan '
        'cannot be read', () async {
      written = {'prod'};
      chosen = {};
      await build(
        decide: () async => throw const HoldingUnreadable(Holding.pro),
      ).check();
      expect(writes, ['-prod']);
      expect(written, isEmpty);
    });

    test('choices that cannot be read change nothing', () async {
      written = {'prod'};
      await build(
        decide: () async => _locked,
        readChoices: () => throw StateError('prefs'),
      ).check();
      expect(writes, isEmpty);
      expect(written, {'prod'});
    });

    test('flags that cannot be read count as none written', () async {
      await build(
        decide: () async => _open,
        readWritten: () => throw StateError('prefs'),
      ).check();
      expect(writes, ['+prod']);
    });

    test('a write that fails does not break the next one', () async {
      var failing = true;
      final sync = build(
        decide: () async => _open,
        write: (topic, {required isOwed}) async {
          if (failing) throw StateError('disk');
          written.add(topic);
          writes.add('+$topic');
        },
      );
      await sync.check();
      expect(written, isEmpty);
      expect(sync.isPublishOwed, isFalse);

      failing = false;
      await sync.check();
      expect(writes, ['+prod']);
      expect(publishes, 1);
    });
  });

  group('a publish that did not land', () {
    test('answering false is tried again on the next check', () async {
      publishAnswer = () async => false;
      final sync = build(decide: () async => _open);
      await sync.check();
      expect(writes, ['+prod']);
      expect(publishes, 1);
      expect(sync.isPublishOwed, isTrue);

      // Nothing to write now. The copy is still owed, so it is made again.
      await sync.check();
      expect(writes, ['+prod']);
      expect(publishes, 2);

      publishAnswer = () async => true;
      await sync.check();
      expect(publishes, 3);
      expect(sync.isPublishOwed, isFalse);

      await sync.check();
      expect(publishes, 3);
    });

    test('throwing is tried again on the next check', () async {
      publishAnswer = () async => throw StateError('channel');
      final sync = build(decide: () async => _open);
      await sync.check();
      expect(sync.isPublishOwed, isTrue);
      publishAnswer = () async => true;
      await sync.check();
      expect(sync.isPublishOwed, isFalse);
      expect(publishes, 2);
    });

    test('an owed publish is still made while the plan cannot be '
        'read', () async {
      publishAnswer = () async => false;
      var unreadable = false;
      final sync = build(
        decide: () async {
          if (unreadable) throw const HoldingUnreadable(Holding.pro);
          return _open;
        },
      );
      await sync.check();
      expect(sync.isPublishOwed, isTrue);

      // The copy is of what is already written, which was sure when it
      // was written. Making it guesses nothing.
      unreadable = true;
      publishAnswer = () async => true;
      await sync.check();
      expect(writes, ['+prod']);
      expect(sync.isPublishOwed, isFalse);
    });
  });

  group('redrawing what shows a Done button', () {
    test('a flag that was set is followed by one redraw', () async {
      await build(decide: () async => _open).check();
      expect(redraws, 1);
    });

    test('a flag that was cleared is followed by one redraw', () async {
      written = {'prod'};
      await build(decide: () async => _locked).check();
      expect(redraws, 1);
    });

    test('nothing written, nothing redrawn', () async {
      written = {'prod'};
      final sync = build(decide: () async => _open);
      await sync.check();
      await sync.check();
      expect(redraws, 0);
    });

    test('a plan that could not be read redraws nothing', () async {
      written = {'prod'};
      await build(
        decide: () async => throw const HoldingUnreadable(Holding.pro),
      ).check();
      expect(redraws, 0);
    });

    test('the redraw waits until the copy for native is made', () async {
      publishAnswer = () async => false;
      final sync = build(decide: () async => _open);
      await sync.check();
      expect(redraws, 0);

      publishAnswer = () async => true;
      await sync.check();
      expect(redraws, 1);

      await sync.check();
      expect(redraws, 1);
    });

    test('a redraw that throws breaks nothing', () async {
      final sync = ChallengeFlagSync(
        decide: () async => _open,
        changes: const [],
        readChoices: () => chosen,
        readWritten: () => {...written},
        write: (topic, {required isOwed}) async => written.add(topic),
        publish: () async => true,
        redraw: () => throw StateError('widgets'),
      );
      await sync.check();
      expect(written, {'prod'});
      expect(sync.isPublishOwed, isFalse);
    });
  });

  group('not ready yet', () {
    test('nothing is written until the answer lands', () async {
      final answer = Completer<FeatureDecision>();
      final sync = build(decide: () => answer.future);
      final running = sync.check();
      await settle();
      expect(writes, isEmpty);
      answer.complete(_open);
      await running;
      expect(writes, ['+prod']);
    });

    test('a change during a check is checked again after it', () async {
      final first = Completer<FeatureDecision>();
      var asked = 0;
      final sync = build(
        decide: () {
          asked++;
          return asked == 1 ? first.future : Future.value(_locked);
        },
      );
      final running = sync.check();
      await settle();
      await sync.check();
      first.complete(_open);
      await running;
      expect(asked, 2);
      // The last answer is the one left written.
      expect(writes, ['+prod', '-prod']);
      expect(written, isEmpty);
    });
  });

  group('following the access layer and the choices', () {
    late TestAccess access;
    late StreamController<void> choiceChanges;

    ChallengeFlagSync follow() {
      choiceChanges = StreamController<void>.broadcast();
      addTearDown(choiceChanges.close);
      return build(
        decide: () =>
            access.features.decideOnceReady(AppFeature.wakeUpChallenges),
        changes: [
          access.features.changes.where(
            (feature) => feature == AppFeature.wakeUpChallenges,
          ),
          choiceChanges.stream,
        ],
      );
    }

    tearDown(() => access.dispose());

    test('launch without Pro sets no flag', () async {
      access = TestAccess();
      follow().start();
      await settle();
      expect(writes, isEmpty);
      expect(written, isEmpty);
    });

    test('launch with Pro sets the flag', () async {
      access = TestAccess(held: {Holding.pro});
      follow().start();
      await settle();
      expect(writes, ['+prod']);
    });

    test('Hosted alone does not open challenges', () async {
      access = TestAccess(held: {Holding.hosted});
      follow().start();
      await settle();
      expect(written, isEmpty);
    });

    test('challenges need Pro on a server of the user own too', () async {
      access = TestAccess(serverMode: ServerMode.selfhosted);
      follow().start();
      await settle();
      expect(written, isEmpty);
    });

    test('Pro ending clears the flag, Pro coming back sets it', () async {
      access = TestAccess(held: {Holding.pro});
      follow().start();
      await settle();
      access.pro.set(HoldingState.notHeld);
      await settle();
      access.pro.set(HoldingState.held);
      await settle();
      expect(writes, ['+prod', '-prod', '+prod']);
      expect(publishes, 3);
    });

    test('a purchase being confirmed sets the flag', () async {
      access = TestAccess();
      follow().start();
      await settle();
      access.pro.set(HoldingState.pending);
      await settle();
      expect(writes, ['+prod']);
    });

    test('a plan that turns unreadable keeps the flag', () async {
      access = TestAccess(held: {Holding.pro});
      follow().start();
      await settle();
      access.pro.set(HoldingState.unknown);
      await settle();
      expect(written, {'prod'});
      expect(writes, ['+prod']);
    });

    test('unreadable at launch never sets and never clears', () async {
      access = TestAccess()..pro.set(HoldingState.unknown);
      written = {'prod'};
      follow().start();
      await settle();
      expect(writes, isEmpty);
      expect(written, {'prod'});

      // Once it can be read and says no, that is a sure answer.
      access.pro.set(HoldingState.notHeld);
      await settle();
      expect(writes, ['-prod']);
    });

    test('picking a challenge for a topic sets its flag', () async {
      access = TestAccess(held: {Holding.pro});
      chosen = {};
      follow().start();
      await settle();
      expect(written, isEmpty);

      chosen = {'db'};
      choiceChanges.add(null);
      await settle();
      expect(writes, ['+db']);
    });

    test('switching a challenge off clears its flag', () async {
      access = TestAccess(held: {Holding.pro});
      follow().start();
      await settle();
      chosen = {};
      choiceChanges.add(null);
      await settle();
      expect(writes, ['+prod', '-prod']);
    });

    test('picking a challenge without Pro sets nothing', () async {
      access = TestAccess();
      chosen = {};
      follow().start();
      await settle();
      chosen = {'db'};
      choiceChanges.add(null);
      await settle();
      expect(written, isEmpty);
    });
  });
}
