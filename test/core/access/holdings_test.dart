import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'access_fakes.dart';

void main() {
  late FakeHoldingSource hosted;
  late FakeHoldingSource pro;
  late Holdings holdings;
  late List<Set<Holding>> heard;

  setUp(() {
    hosted = FakeHoldingSource(Holding.hosted);
    pro = FakeHoldingSource(Holding.pro);
    holdings = Holdings([hosted, pro]);
    heard = [];
    holdings.stream.listen(heard.add);
  });

  tearDown(() => holdings.dispose());

  test('nothing held to start with', () {
    expect(holdings.held, isEmpty);
    expect(holdings.holds(Holding.hosted), isFalse);
    expect(holdings.holds(Holding.pro), isFalse);
    expect(holdings.stateOf(Holding.pro), HoldingState.notHeld);
  });

  test('a person can hold Hosted and Pro at the same time', () {
    hosted.set(HoldingState.held);
    pro.set(HoldingState.held);
    expect(holdings.held, {Holding.hosted, Holding.pro});
  });

  test('holding Hosted does not grant Pro, and Pro does not grant Hosted', () {
    hosted.set(HoldingState.held);
    expect(holdings.held, {Holding.hosted});
    expect(holdings.stateOf(Holding.pro), HoldingState.notHeld);

    hosted.set(HoldingState.notHeld);
    pro.set(HoldingState.held);
    expect(holdings.held, {Holding.pro});
    expect(holdings.stateOf(Holding.hosted), HoldingState.notHeld);
  });

  test('a pending purchase counts as held, and stateOf tells them apart', () {
    pro.set(HoldingState.pending);
    expect(holdings.holds(Holding.pro), isTrue);
    expect(holdings.held, {Holding.pro});
    expect(holdings.stateOf(Holding.pro), HoldingState.pending);
  });

  test('a holding with no source is not held', () {
    final onlyHosted = Holdings([hosted]);
    addTearDown(onlyHosted.dispose);
    expect(onlyHosted.stateOf(Holding.pro), HoldingState.notHeld);
    expect(onlyHosted.holds(Holding.pro), isFalse);
  });

  test('two sources for one holding: the stronger answer stands', () {
    final second = FakeHoldingSource(Holding.pro, HoldingState.held);
    final both = Holdings([pro, second]);
    addTearDown(both.dispose);
    expect(both.stateOf(Holding.pro), HoldingState.held);
    pro.set(HoldingState.pending);
    second.set(HoldingState.notHeld);
    expect(both.stateOf(Holding.pro), HoldingState.pending);
  });

  group('stream', () {
    test('sends the held set when a holding changes', () async {
      pro.set(HoldingState.held);
      await settle();
      hosted.set(HoldingState.held);
      await settle();
      pro.set(HoldingState.notHeld);
      await settle();
      expect(heard, [
        {Holding.pro},
        {Holding.pro, Holding.hosted},
        {Holding.hosted},
      ]);
    });

    test('sends nothing when a source fires with no change', () async {
      pro
        ..ringOnly()
        ..set(HoldingState.notHeld);
      hosted.ringOnly();
      await settle();
      expect(heard, isEmpty);

      pro
        ..set(HoldingState.held)
        ..set(HoldingState.held)
        ..ringOnly();
      await settle();
      expect(heard, hasLength(1));
    });

    test(
      'sends when pending becomes held, though the set is the same',
      () async {
        pro
          ..set(HoldingState.pending)
          ..set(HoldingState.held);
        await settle();
        expect(heard, [
          {Holding.pro},
          {Holding.pro},
        ]);
      },
    );

    test('is quiet after dispose', () async {
      final own = Holdings([pro]);
      final got = <Set<Holding>>[];
      own.stream.listen(got.add);
      await own.dispose();
      pro.set(HoldingState.held);
      await settle();
      expect(got, isEmpty);
    });
  });
}
