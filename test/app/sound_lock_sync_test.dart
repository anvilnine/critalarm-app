import 'dart:async';

import 'package:critalarm/app/sound_lock_sync.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/access/access_fakes.dart';

void main() {
  late bool? written;
  late List<bool> writes;
  late int publishes;

  /// What the next publish answers. A test sets it to fail one.
  late Future<bool> Function() publishAnswer;

  SoundLockSync build({
    required Future<bool> Function() isLocked,
    Stream<Object?>? changes,
    Future<void> Function({required bool locked})? write,
    bool? Function()? readWritten,
  }) {
    final sync = SoundLockSync(
      isLocked: isLocked,
      changes: changes ?? const Stream<Object?>.empty(),
      readWritten: readWritten ?? () => written,
      write:
          write ??
          ({required locked}) async {
            written = locked;
            writes.add(locked);
          },
      publish: () {
        publishes++;
        return publishAnswer();
      },
    );
    addTearDown(sync.dispose);
    return sync;
  }

  setUp(() {
    written = null;
    writes = [];
    publishes = 0;
    publishAnswer = () async => true;
  });

  group('a publish that did not land', () {
    test('answering false is tried again on the next check', () async {
      publishAnswer = () async => false;
      final sync = build(isLocked: () async => false);
      await sync.check();
      expect(writes, [false]);
      expect(publishes, 1);
      expect(sync.isPublishOwed, isTrue);

      // Nothing to write now: the value already matches. The copy for
      // the extension is still owed, so it is made again.
      await sync.check();
      expect(writes, [false]);
      expect(publishes, 2);
      expect(sync.isPublishOwed, isTrue);

      publishAnswer = () async => true;
      await sync.check();
      expect(publishes, 3);
      expect(sync.isPublishOwed, isFalse);

      await sync.check();
      expect(publishes, 3);
      expect(writes, [false]);
    });

    test('throwing is tried again on the next check', () async {
      publishAnswer = () async => throw StateError('channel');
      final sync = build(isLocked: () async => true);
      await sync.check();
      expect(writes, [true]);
      expect(sync.isPublishOwed, isTrue);

      publishAnswer = () async => true;
      await sync.check();
      expect(publishes, 2);
      expect(sync.isPublishOwed, isFalse);
    });

    test('a change event retries it too', () async {
      final changes = StreamController<Object?>.broadcast();
      addTearDown(changes.close);
      publishAnswer = () async => false;
      final sync = build(isLocked: () async => false, changes: changes.stream)
        ..start();
      await settle();
      expect(sync.isPublishOwed, isTrue);

      publishAnswer = () async => true;
      changes.add(null);
      await settle();
      expect(publishes, 2);
      expect(sync.isPublishOwed, isFalse);
    });

    test('an owed publish waits while the plan cannot be read', () async {
      publishAnswer = () async => false;
      var unreadable = false;
      final sync = build(
        isLocked: () async =>
            unreadable ? throw const HoldingUnreadable(Holding.pro) : false,
      );
      await sync.check();
      unreadable = true;
      publishAnswer = () async => true;
      await sync.check();
      expect(publishes, 1);
      expect(sync.isPublishOwed, isTrue);

      unreadable = false;
      await sync.check();
      expect(publishes, 2);
      expect(sync.isPublishOwed, isFalse);
    });

    test('a newer answer is written and one publish carries it', () async {
      publishAnswer = () async => false;
      var locked = false;
      final sync = build(isLocked: () async => locked);
      await sync.check();
      locked = true;
      publishAnswer = () async => true;
      await sync.check();
      expect(writes, [false, true]);
      expect(publishes, 2);
      expect(sync.isPublishOwed, isFalse);
    });
  });

  group('a flag that is not a boolean', () {
    test('counts as never written and is written over', () async {
      Object? stored = 'yes';
      final sync = build(
        isLocked: () async => true,
        // What SharedPreferences.getBool does with a string under the key.
        readWritten: () => stored as bool?,
        write: ({required locked}) async {
          stored = locked;
          writes.add(locked);
        },
      );
      await sync.check();
      expect(writes, [true]);
      expect(stored, isTrue);
      expect(publishes, 1);

      await sync.check();
      expect(writes, [true]);
    });

    test('still writes nothing while the plan cannot be read', () async {
      await build(
        isLocked: () async => throw const HoldingUnreadable(Holding.pro),
        readWritten: () => throw TypeError(),
      ).check();
      expect(writes, isEmpty);
      expect(publishes, 0);
    });
  });

  group('one check', () {
    test('a sure locked is written and published', () async {
      await build(isLocked: () async => true).check();
      expect(writes, [true]);
      expect(publishes, 1);
    });

    test('a sure open is written on a phone with no flag yet', () async {
      await build(isLocked: () async => false).check();
      expect(writes, [false]);
      expect(publishes, 1);
    });

    test('the same answer as last time writes nothing', () async {
      written = true;
      await build(isLocked: () async => true).check();
      expect(writes, isEmpty);
      expect(publishes, 0);
    });

    test('a plan that could not be read leaves locked as it was', () async {
      written = true;
      await build(
        isLocked: () async => throw const HoldingUnreadable(Holding.pro),
      ).check();
      expect(written, isTrue);
      expect(writes, isEmpty);
      expect(publishes, 0);
    });

    test('a plan that could not be read leaves open as it was', () async {
      written = false;
      await build(
        isLocked: () async => throw const HoldingUnreadable(Holding.pro),
      ).check();
      expect(written, isFalse);
      expect(writes, isEmpty);
    });

    test('a plan that could not be read never writes a first flag', () async {
      await build(
        isLocked: () async => throw const HoldingUnreadable(Holding.pro),
      ).check();
      expect(written, isNull);
      expect(writes, isEmpty);
    });

    test('any other failure of the question writes nothing', () async {
      written = false;
      await build(isLocked: () async => throw StateError('no')).check();
      expect(written, isFalse);
      expect(writes, isEmpty);
    });

    test('a write that fails does not break the next one', () async {
      var fail = true;
      final sync = build(
        isLocked: () async => true,
        write: ({required locked}) async {
          if (fail) throw StateError('disk');
          written = locked;
          writes.add(locked);
        },
      );
      await sync.check();
      expect(written, isNull);
      expect(publishes, 0);

      fail = false;
      await sync.check();
      expect(writes, [true]);
      expect(publishes, 1);
    });
  });

  group('not ready yet', () {
    test('nothing is written until the answer lands', () async {
      final answer = Completer<bool>();
      final sync = build(isLocked: () => answer.future)..start();
      await settle();
      expect(writes, isEmpty);
      expect(written, isNull);

      answer.complete(true);
      await settle();
      expect(writes, [true]);
      await sync.dispose();
    });

    test('a change during a check is checked again after it', () async {
      final first = Completer<bool>();
      var asked = 0;
      final sync = build(
        isLocked: () {
          asked++;
          return asked == 1 ? first.future : Future.value(false);
        },
      );
      final running = sync.check();
      await sync.check();
      first.complete(true);
      await running;
      expect(asked, 2);
      // The last answer is the one left written.
      expect(writes, [true, false]);
      expect(written, isFalse);
    });
  });

  group('following the access layer', () {
    late TestAccess access;

    SoundLockSync follow() => build(
      isLocked: () async =>
          !await access.features.canOnceReady(AppFeature.ownSounds),
      changes: access.features.changes.where(
        (feature) => feature == AppFeature.ownSounds,
      ),
    );

    tearDown(() => access.dispose());

    test('launch without Pro writes locked', () async {
      access = TestAccess();
      follow().start();
      await settle();
      expect(writes, [true]);
    });

    test('launch with Pro writes open', () async {
      access = TestAccess(held: {Holding.pro});
      follow().start();
      await settle();
      expect(writes, [false]);
    });

    test('Hosted alone does not open own sounds', () async {
      access = TestAccess(held: {Holding.hosted});
      follow().start();
      await settle();
      expect(writes, [true]);
    });

    test('own sounds need Pro on a server of the user own too', () async {
      access = TestAccess(serverMode: ServerMode.selfhosted);
      follow().start();
      await settle();
      expect(writes, [true]);
    });

    test('Pro ending writes locked, Pro coming back writes open', () async {
      access = TestAccess(held: {Holding.pro});
      follow().start();
      await settle();
      access.pro.set(HoldingState.notHeld);
      await settle();
      access.pro.set(HoldingState.held);
      await settle();
      expect(writes, [false, true, false]);
      expect(publishes, 3);
    });

    test('a purchase being confirmed counts as open', () async {
      access = TestAccess();
      follow().start();
      await settle();
      access.pro.set(HoldingState.pending);
      await settle();
      expect(writes, [true, false]);
    });

    test('a plan that turns unreadable keeps the last value', () async {
      access = TestAccess(held: {Holding.pro});
      follow().start();
      await settle();
      expect(written, isFalse);

      access.pro.set(HoldingState.unknown);
      await settle();
      expect(written, isFalse);
      expect(writes, [false]);
    });

    test('unreadable at launch never writes locked', () async {
      access = TestAccess()..pro.set(HoldingState.unknown);
      written = false;
      follow().start();
      await settle();
      expect(written, isFalse);
      expect(writes, isEmpty);

      // Once it can be read and says no, that is a sure answer.
      access.pro.set(HoldingState.notHeld);
      await settle();
      expect(writes, [true]);
    });
  });
}
