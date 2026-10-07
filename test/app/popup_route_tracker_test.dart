import 'package:critalarm/app/popup_route_tracker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late PopupRouteTracker tracker;

  Route<void> sheet() => RawDialogRoute<void>(
    pageBuilder: (context, animation, secondary) => const SizedBox.shrink(),
  );
  Route<void> page() => MaterialPageRoute<void>(
    builder: (context) => const SizedBox.shrink(),
  );

  setUp(() => tracker = PopupRouteTracker());

  test('a sheet or dialog opening and closing moves it', () {
    expect(tracker.isUp, isFalse);
    final route = sheet();
    tracker.didPush(route, null);
    expect(tracker.isUp, isTrue);
    tracker.didPop(route, null);
    expect(tracker.isUp, isFalse);
  });

  test('a screen is not counted', () {
    final route = page();
    tracker.didPush(route, null);
    expect(tracker.isUp, isFalse);
    tracker.didPop(route, null);
    expect(tracker.isUp, isFalse);
  });

  test('two sheets need two closes', () {
    final first = sheet();
    final second = sheet();
    tracker
      ..didPush(first, null)
      ..didPush(second, first)
      ..didPop(second, first);
    expect(tracker.isUp, isTrue);
    tracker.didRemove(first, null);
    expect(tracker.isUp, isFalse);
  });

  test('a replace swaps one for the other', () {
    final first = sheet();
    final second = sheet();
    tracker
      ..didPush(first, null)
      ..didReplace(newRoute: second, oldRoute: first);
    expect(tracker.isUp, isTrue);
    tracker.didPop(second, null);
    expect(tracker.isUp, isFalse);
  });

  test('it never goes below none, and it tells listeners', () {
    var heard = 0;
    tracker.changes.addListener(() => heard++);
    final route = sheet();
    tracker.didPop(route, null);
    expect(tracker.isUp, isFalse);
    tracker.didPush(route, null);
    expect(heard, 1);
  });
}
