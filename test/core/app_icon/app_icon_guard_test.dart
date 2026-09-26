import 'dart:async';

import 'package:critalarm/core/app_icon/app_icon.dart';
import 'package:critalarm/core/app_icon/app_icon_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppIcon? current;
  late bool unlocked;
  late bool applyOk;
  late List<AppIcon> applied;
  late int unlockedReads;

  AppIconGuard guard({Future<bool> Function()? readUnlocked}) => AppIconGuard(
    readCurrent: () async => current,
    apply: (icon) async {
      applied.add(icon);
      return applyOk;
    },
    readUnlocked:
        readUnlocked ??
        () async {
          unlockedReads++;
          return unlocked;
        },
  );

  setUp(() {
    current = AppIcon.crowned;
    unlocked = true;
    applyOk = true;
    applied = [];
    unlockedReads = 0;
  });

  test('a Pro icon stays while Pro does', () async {
    expect(await guard().check(), isNull);
    expect(applied, isEmpty);
  });

  test('a Pro icon goes back to the default when Pro has ended', () async {
    unlocked = false;

    expect(await guard().check(), AppIcon.standard);
    expect(applied, [AppIcon.standard]);
  });

  test('every Pro icon is covered', () async {
    unlocked = false;
    for (final icon in AppIcon.values.where((icon) => icon.isPro)) {
      current = icon;
      applied = [];

      expect(await guard().check(), AppIcon.standard);
      expect(applied, [AppIcon.standard]);
    }
  });

  test('the default icon never asks about the plan', () async {
    current = AppIcon.standard;
    unlocked = false;

    expect(await guard().check(), isNull);
    expect(unlockedReads, 0);
    expect(applied, isEmpty);
  });

  test('a platform with no icon to change does nothing', () async {
    current = null;
    unlocked = false;

    expect(await guard().check(), isNull);
    expect(unlockedReads, 0);
    expect(applied, isEmpty);
  });

  test('a plan it cannot read leaves the icon alone', () async {
    final result = await guard(
      readUnlocked: () async => throw StateError('offline'),
    ).check();

    expect(result, isNull);
    expect(applied, isEmpty);
  });

  test('a refused switch reports nothing changed', () async {
    unlocked = false;
    applyOk = false;

    expect(await guard().check(), isNull);
    expect(applied, [AppIcon.standard]);
  });

  test('two checks at once switch only once', () async {
    unlocked = false;
    final gate = Completer<bool>();
    final g = guard(readUnlocked: () => gate.future);

    final first = g.check();
    final second = g.check();
    gate.complete(false);

    expect(await first, AppIcon.standard);
    expect(await second, isNull);
    expect(applied, [AppIcon.standard]);
  });
}
