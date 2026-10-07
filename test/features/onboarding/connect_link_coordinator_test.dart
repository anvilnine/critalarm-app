import 'dart:async';

import 'package:critalarm/core/links/app_link.dart';
import 'package:critalarm/core/links/connect_link_holder.dart';
import 'package:critalarm/features/onboarding/domain/connect/connect_link_coordinator.dart';
import 'package:critalarm/features/onboarding/domain/connect/connect_sheet_rules.dart';
import 'package:flutter_test/flutter_test.dart';

ConnectLink _link(String host, [String token = 'tk_secret']) => ConnectLink(
  serverUrl: Uri.parse('https://$host'),
  token: token,
);

void main() {
  late ConnectLinkHolder holder;
  late ConnectSheetSituation now;
  late List<ConnectLink> shown;
  late List<Completer<ConnectSheetEnd>> sheets;
  late List<bool> holderEmptyWhileUp;
  late ConnectLinkCoordinator coordinator;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  /// `check` completes when the sheet it opens closes, so it is not awaited.
  Future<void> poke() {
    unawaited(coordinator.check());
    return settle();
  }

  setUp(() {
    holder = ConnectLinkHolder();
    now = const ConnectSheetSituation(
      setupDone: true,
      onConnectStep: false,
      alarmOn: false,
      sheetUp: false,
    );
    shown = [];
    sheets = [];
    holderEmptyWhileUp = [];
    coordinator = ConnectLinkCoordinator(
      links: holder,
      readSituation: () async => now,
      showSheet: (link) {
        shown.add(link);
        holderEmptyWhileUp.add(holder.pending == null);
        final done = Completer<ConnectSheetEnd>();
        sheets.add(done);
        return done.future;
      },
    );
  });

  tearDown(() async {
    await coordinator.dispose();
    await holder.dispose();
  });

  void situation({
    bool setupDone = true,
    bool onConnectStep = false,
    bool alarmOn = false,
    bool sheetUp = false,
  }) => now = ConnectSheetSituation(
    setupDone: setupDone,
    onConnectStep: onConnectStep,
    alarmOn: alarmOn,
    sheetUp: sheetUp,
  );

  group('when the sheet opens', () {
    test('a link held before start opens a sheet and leaves the holder '
        'empty', () async {
      holder.offer(_link('a.example.com'));
      coordinator.start();
      await settle();
      expect(shown.map((l) => l.serverUrl.host), ['a.example.com']);
      expect(holderEmptyWhileUp, [true]);
      expect(holder.pending, isNull);
      expect(coordinator.isShowing, isTrue);
    });

    test('a link that arrives later opens a sheet', () async {
      coordinator.start();
      await settle();
      expect(shown, isEmpty);
      holder.offer(_link('a.example.com'));
      await settle();
      expect(shown, hasLength(1));
    });

    test('nothing opens without a link', () async {
      coordinator.start();
      await coordinator.check();
      expect(shown, isEmpty);
    });
  });

  group('a link waits in the holder', () {
    test('while an alarm has focus, then shows when it ends', () async {
      situation(alarmOn: true);
      holder.offer(_link('a.example.com'));
      coordinator.start();
      await settle();
      expect(shown, isEmpty);
      expect(holder.pending, _link('a.example.com'));

      situation();
      await poke();
      expect(shown, hasLength(1));
      expect(holder.pending, isNull);
    });

    test('during setup before the connect step, then shows there', () async {
      situation(setupDone: false);
      holder.offer(_link('a.example.com'));
      coordinator.start();
      await settle();
      expect(shown, isEmpty);
      expect(holder.pending, isNotNull);

      situation(setupDone: false, onConnectStep: true);
      await poke();
      expect(shown, hasLength(1));
    });

    test('during setup, past the connect step, until setup is done', () async {
      situation(setupDone: false);
      holder.offer(_link('a.example.com'));
      coordinator.start();
      await settle();
      situation(setupDone: false);
      await poke();
      expect(shown, isEmpty);
      situation();
      await poke();
      expect(shown, hasLength(1));
    });

    test('behind another sheet, then shows when it closes', () async {
      situation(sheetUp: true);
      holder.offer(_link('a.example.com'));
      coordinator.start();
      await settle();
      expect(shown, isEmpty);
      situation();
      await poke();
      expect(shown, hasLength(1));
    });

    test('a change that lands while the rule is being read is not '
        'missed', () async {
      final gate = Completer<void>();
      var reads = 0;
      final slow = ConnectLinkCoordinator(
        links: holder,
        readSituation: () async {
          reads++;
          final snapshot = now;
          await gate.future;
          return snapshot;
        },
        showSheet: (link) async {
          shown.add(link);
          return ConnectSheetEnd.left;
        },
      );
      addTearDown(slow.dispose);
      situation(alarmOn: true);
      holder.offer(_link('a.example.com'));
      unawaited(slow.check());
      await settle();
      situation();
      unawaited(slow.check());
      gate.complete();
      await settle();
      await settle();
      expect(reads, greaterThanOrEqualTo(2));
      expect(shown, hasLength(1));
    });
  });

  group('the holder is clear after each way a sheet ends', () {
    for (final end in [
      ConnectSheetEnd.connected,
      ConnectSheetEnd.left,
      ConnectSheetEnd.interruptedWhileConnecting,
    ]) {
      test('${end.name}: nothing is left to show again', () async {
        holder.offer(_link('a.example.com'));
        coordinator.start();
        await settle();
        sheets.single.complete(end);
        await settle();
        expect(holder.pending, isNull);
        expect(coordinator.isShowing, isFalse);
        await coordinator.check();
        expect(shown, hasLength(1));
      });
    }

    test('a sheet that threw is spent, and nothing is left to show', () async {
      final broken = ConnectLinkCoordinator(
        links: holder,
        readSituation: () async => now,
        showSheet: (link) => throw StateError('no overlay'),
      );
      addTearDown(broken.dispose);
      holder.offer(_link('a.example.com'));
      await broken.check();
      expect(holder.pending, isNull);
      expect(broken.isShowing, isFalse);
    });

    test('an alarm that closed the sheet before a tap puts the link back, '
        'and it shows again when the alarm ends', () async {
      holder.offer(_link('a.example.com'));
      coordinator.start();
      await settle();
      situation(alarmOn: true);
      sheets.single.complete(ConnectSheetEnd.interrupted);
      await settle();
      expect(holder.pending, _link('a.example.com'));
      expect(shown, hasLength(1));

      situation();
      await poke();
      expect(shown, hasLength(2));
      expect(holder.pending, isNull);
    });

    test('an interrupted link does not replace a newer one', () async {
      holder.offer(_link('a.example.com'));
      coordinator.start();
      await settle();
      situation(alarmOn: true);
      holder.offer(_link('b.example.com', 'tk_newer'));
      sheets.single.complete(ConnectSheetEnd.interrupted);
      await settle();
      expect(holder.pending?.serverUrl.host, 'b.example.com');
    });
  });

  group('a second link while a sheet is up', () {
    test('is held until the sheet closes, and the sheet keeps what it '
        'shows', () async {
      holder.offer(_link('a.example.com', 'tk_first'));
      coordinator.start();
      await settle();

      holder.offer(_link('b.example.com', 'tk_second'));
      await settle();
      // The first sheet is still the only one, and it was never handed the
      // second link.
      expect(shown.map((l) => l.serverUrl.host), ['a.example.com']);
      expect(holder.pending?.serverUrl.host, 'b.example.com');

      sheets.first.complete(ConnectSheetEnd.left);
      await settle();
      expect(shown.map((l) => l.serverUrl.host), [
        'a.example.com',
        'b.example.com',
      ]);
      expect(shown.last.token, 'tk_second');
      expect(holder.pending, isNull);
    });

    test('a third link replaces the second while they wait', () async {
      holder.offer(_link('a.example.com'));
      coordinator.start();
      await settle();
      holder
        ..offer(_link('b.example.com'))
        ..offer(_link('c.example.com'));
      sheets.first.complete(ConnectSheetEnd.connected);
      await settle();
      expect(shown.map((l) => l.serverUrl.host), [
        'a.example.com',
        'c.example.com',
      ]);
    });
  });

  group('a link is never lost without a reason', () {
    test('an alarm that starts between the check and the sheet holds the '
        'link back', () async {
      var allowed = false;
      final late = ConnectLinkCoordinator(
        links: holder,
        readSituation: () async => now,
        checkAgain: () => allowed,
        showSheet: (link) async {
          shown.add(link);
          return ConnectSheetEnd.left;
        },
      );
      addTearDown(late.dispose);
      holder.offer(_link('a.example.com'));
      await late.check();
      expect(shown, isEmpty);
      expect(holder.pending, _link('a.example.com'));

      allowed = true;
      await late.check();
      expect(shown, hasLength(1));
      expect(holder.pending, isNull);
    });

    test('a sheet that failed to open is put back once, and shows on the '
        'second try', () async {
      var attempts = 0;
      final flaky = ConnectLinkCoordinator(
        links: holder,
        readSituation: () async => now,
        showSheet: (link) async {
          attempts++;
          if (attempts == 1) throw StateError('no overlay');
          shown.add(link);
          return ConnectSheetEnd.connected;
        },
      );
      addTearDown(flaky.dispose);
      holder.offer(_link('a.example.com'));
      await flaky.check();
      expect(attempts, 2);
      expect(shown.map((l) => l.serverUrl.host), ['a.example.com']);
      expect(holder.pending, isNull);
    });

    test('a sheet that fails twice drops the link, and only then', () async {
      var attempts = 0;
      final broken = ConnectLinkCoordinator(
        links: holder,
        readSituation: () async => now,
        showSheet: (link) {
          attempts++;
          throw StateError('no overlay');
        },
      );
      addTearDown(broken.dispose);
      holder.offer(_link('a.example.com'));
      await broken.check();
      await settle();
      expect(attempts, 2);
      expect(holder.pending, isNull);
      expect(broken.isShowing, isFalse);
    });

    test('a failed sheet does not put its link over a newer one', () async {
      var attempts = 0;
      final seen = <String>[];
      late final ConnectLinkCoordinator flaky;
      flaky = ConnectLinkCoordinator(
        links: holder,
        readSituation: () async => now,
        showSheet: (link) async {
          attempts++;
          seen.add(link.serverUrl.host);
          if (attempts == 1) {
            // A newer link lands while the first sheet is failing.
            holder.offer(_link('b.example.com', 'tk_newer'));
            throw StateError('no overlay');
          }
          return ConnectSheetEnd.left;
        },
      );
      addTearDown(flaky.dispose);
      holder.offer(_link('a.example.com'));
      await flaky.check();
      expect(seen, ['a.example.com', 'b.example.com']);
    });

    test('newest wins on purpose: an interrupted link is dropped when a '
        'newer one is waiting, and the older one never shows', () async {
      holder.offer(_link('a.example.com'));
      coordinator.start();
      await settle();
      situation(alarmOn: true);
      holder.offer(_link('b.example.com', 'tk_newer'));
      sheets.single.complete(ConnectSheetEnd.interrupted);
      await settle();

      situation();
      await poke();
      expect(shown.map((l) => l.serverUrl.host), [
        'a.example.com',
        'b.example.com',
      ]);
      sheets.last.complete(ConnectSheetEnd.left);
      await settle();
      expect(holder.pending, isNull);
      await poke();
      expect(shown, hasLength(2));
    });
  });

  test('a disposed coordinator opens nothing', () async {
    situation(alarmOn: true);
    holder.offer(_link('a.example.com'));
    coordinator.start();
    await settle();
    await coordinator.dispose();
    situation();
    await coordinator.check();
    expect(shown, isEmpty);
  });
}
