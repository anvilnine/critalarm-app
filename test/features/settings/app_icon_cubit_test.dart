import 'dart:async';

import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/core/app_icon/app_icon.dart';
import 'package:critalarm/features/settings/presentation/cubits/app_icon_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/app_icon_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppIcon? current;
  late bool unlocked;
  late bool applyOk;
  late List<AppIcon> applied;
  late PlanChanges plan;

  AppIconCubit build({Future<bool> Function()? readUnlocked}) => AppIconCubit(
    readCurrent: () async => current,
    apply: (icon) async {
      applied.add(icon);
      if (applyOk) current = icon;
      return applyOk;
    },
    readUnlocked: readUnlocked ?? () async => unlocked,
    planChanges: plan,
  );

  Future<AppIconCubit> loaded({Future<bool> Function()? readUnlocked}) async {
    final cubit = build(readUnlocked: readUnlocked);
    await cubit.load();
    return cubit;
  }

  setUp(() {
    current = AppIcon.standard;
    unlocked = false;
    applyOk = true;
    applied = [];
    plan = PlanChanges();
  });

  test('starts loading, then shows the icon on the home screen', () async {
    current = AppIcon.shades;
    unlocked = true;
    final cubit = build();
    expect(cubit.state.status, AppIconStatus.loading);

    await cubit.load();

    expect(cubit.state.status, AppIconStatus.ready);
    expect(cubit.state.current, AppIcon.shades);
    expect(cubit.state.unlocked, isTrue);
    await cubit.close();
  });

  test('a platform that cannot change its icon is unavailable', () async {
    current = null;
    final cubit = await loaded();

    expect(cubit.state.status, AppIconStatus.unavailable);
    await cubit.close();
  });

  test('Free sees the Pro icons locked', () async {
    final cubit = await loaded();

    expect(cubit.state.isLocked(AppIcon.standard), isFalse);
    expect(cubit.state.isLocked(AppIcon.crowned), isTrue);
    expect(cubit.state.isLocked(AppIcon.shades), isTrue);
    expect(cubit.state.isLocked(AppIcon.shadesCrown), isTrue);
    await cubit.close();
  });

  test('a plan it cannot read shows the Pro icons locked', () async {
    final cubit = await loaded(
      readUnlocked: () async => throw StateError('offline'),
    );

    expect(cubit.state.status, AppIconStatus.ready);
    expect(cubit.state.unlocked, isFalse);
    await cubit.close();
  });

  test('Free picking a Pro icon is sent to the paywall', () async {
    final cubit = await loaded();

    expect(await cubit.pick(AppIcon.crowned), AppIconPick.locked);
    expect(applied, isEmpty);
    expect(cubit.state.current, AppIcon.standard);
    await cubit.close();
  });

  test('Pro can pick each Pro icon', () async {
    unlocked = true;
    final cubit = await loaded();

    for (final icon in [
      AppIcon.crowned,
      AppIcon.shades,
      AppIcon.shadesCrown,
      AppIcon.standard,
    ]) {
      expect(await cubit.pick(icon), AppIconPick.changed);
      expect(cubit.state.current, icon);
      expect(cubit.state.saving, isNull);
    }
    expect(applied, [
      AppIcon.crowned,
      AppIcon.shades,
      AppIcon.shadesCrown,
      AppIcon.standard,
    ]);
    await cubit.close();
  });

  test('picking the icon already showing does nothing', () async {
    unlocked = true;
    current = AppIcon.shades;
    final cubit = await loaded();

    expect(await cubit.pick(AppIcon.shades), AppIconPick.unchanged);
    expect(applied, isEmpty);
    await cubit.close();
  });

  test('a refused switch keeps the old icon and says so', () async {
    unlocked = true;
    applyOk = false;
    final cubit = await loaded();

    expect(await cubit.pick(AppIcon.crowned), AppIconPick.failed);
    expect(cubit.state.current, AppIcon.standard);
    expect(cubit.state.failed, isTrue);

    applyOk = true;
    expect(await cubit.pick(AppIcon.crowned), AppIconPick.changed);
    expect(cubit.state.failed, isFalse);
    await cubit.close();
  });

  test('a purchase unlocks the Pro icons without leaving the screen', () async {
    final cubit = await loaded();
    expect(cubit.state.unlocked, isFalse);

    unlocked = true;
    plan.bump();
    await pumpEventQueue();

    expect(cubit.state.unlocked, isTrue);
    expect(await cubit.pick(AppIcon.shadesCrown), AppIconPick.changed);
    await cubit.close();
  });

  test('a second tap while switching is ignored', () async {
    unlocked = true;
    final gate = Completer<bool>();
    final cubit = AppIconCubit(
      readCurrent: () async => current,
      apply: (icon) {
        applied.add(icon);
        return gate.future;
      },
      readUnlocked: () async => unlocked,
      planChanges: plan,
    );
    await cubit.load();

    final first = cubit.pick(AppIcon.crowned);
    expect(cubit.state.saving, AppIcon.crowned);
    expect(await cubit.pick(AppIcon.shades), AppIconPick.unchanged);
    gate.complete(true);

    expect(await first, AppIconPick.changed);
    expect(applied, [AppIcon.crowned]);
    await cubit.close();
  });
}
