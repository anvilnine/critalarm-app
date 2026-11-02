import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/features/paywall/domain/history_own.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/paywall_door.dart';
import 'package:critalarm/features/paywall/presentation/widgets/access_lock.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/access/access_fakes.dart';

const _own = HistoryOwn(
  inside: [HistoryOwnRow('prod-db', 1)],
  beyond: [HistoryOwnRow('nas', 12)],
);

enum _Read { rows, throws, hangs }

/// Puts a door that opens the proof layout and a feature access in
/// `getIt`, the way a sheet that closes itself reaches them.
TestAccess _install({
  required _Read read,
  Set<Holding> held = const {},
}) {
  final access = TestAccess(held: held);
  final door = PaywallDoor(
    developer: (_) => null,
    hasSeenFalseAlarm: () => true,
    markFalseAlarmSeen: () async {},
    readHistoryOwn: () async {
      if (read == _Read.throws) throw StateError('no store');
      if (read == _Read.hangs) return Completer<HistoryOwn?>().future;
      return _own;
    },
  );
  getIt
    ..registerSingleton<FeatureAccess>(access.features)
    ..registerSingleton<PaywallDoor>(door);
  addTearDown(() async {
    await getIt.reset();
    await access.dispose();
  });
  return access;
}

void main() {
  const wait = Duration(milliseconds: 40);

  test('a longer History window opens with the rows the phone holds', () async {
    _install(read: _Read.rows);
    final location = await paywallLocationForFeature(
      AppFeature.longHistory,
      LockSource.history,
      ownWait: wait,
    );
    expect(location, isNotNull);
    final uri = Uri.parse(location!);
    expect(uri.path, '/plans/proof');
    final back = HistoryOwn.fromQuery(uri.queryParameters);
    expect(back, isNotNull);
    expect(back!.beyond.single.topic, 'nas');
    expect(back.beyond.single.ageDays, 12);
  });

  test('a read that fails still opens, with sample rows', () async {
    _install(read: _Read.throws);
    final location = await paywallLocationForFeature(
      AppFeature.longHistory,
      LockSource.history,
      ownWait: wait,
    );
    expect(
      location,
      '/plans/proof?product=hosted&source=history'
      '&thanks=party&outro=cloud_climb&lead=history',
    );
  });

  test('a read that is too slow still opens, with sample rows', () async {
    _install(read: _Read.hangs);
    final location = await paywallLocationForFeature(
      AppFeature.longHistory,
      LockSource.history,
      ownWait: wait,
    );
    expect(
      location,
      '/plans/proof?product=hosted&source=history'
      '&thanks=party&outro=cloud_climb&lead=history',
    );
  });

  test('a feature that is not locked opens nothing', () async {
    _install(read: _Read.rows, held: {Holding.hosted});
    expect(
      await paywallLocationForFeature(
        AppFeature.longHistory,
        LockSource.history,
        ownWait: wait,
      ),
      isNull,
    );
  });
}
