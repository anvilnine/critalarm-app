import 'dart:convert';

import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/push/last_push_reader.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/sources/last_push_source.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime.utc(2026, 10, 14, 12);
const _route = 'testRing';

void main() {
  group('state rule', () {
    DateTime ago(Duration d) => _now.subtract(d);

    test('exactly 7 days of silence with a critical topic is still fine', () {
      final check = LastPushSource.lastPushCheckFor(
        now: _now,
        lastPushAt: ago(const Duration(days: 7)),
        watchingSince: ago(const Duration(days: 30)),
        hasCriticalTopic: true,
        testRouteName: _route,
      );
      expect(check.state, ReliabilityState.fine);
    });

    test('one second past 7 days with a critical topic needs a look', () {
      final check = LastPushSource.lastPushCheckFor(
        now: _now,
        lastPushAt: ago(const Duration(days: 7, seconds: 1)),
        watchingSince: ago(const Duration(days: 30)),
        hasCriticalTopic: true,
        testRouteName: _route,
      );
      expect(check.state, ReliabilityState.needsLook);
      expect(check.reason, 'silent');
      expect(check.fix, const OpenRouteFix(_route));
      expect(check.lastKnownGood, ago(const Duration(days: 7, seconds: 1)));
    });

    test('a long silence with no critical topic is fine', () {
      final check = LastPushSource.lastPushCheckFor(
        now: _now,
        lastPushAt: ago(const Duration(days: 90)),
        watchingSince: ago(const Duration(days: 120)),
        hasCriticalTopic: false,
        testRouteName: _route,
      );
      expect(check.state, ReliabilityState.fine);
      expect(check.fix, isNull);
    });

    test('a recent push is fine', () {
      final check = LastPushSource.lastPushCheckFor(
        now: _now,
        lastPushAt: ago(const Duration(hours: 3)),
        watchingSince: ago(const Duration(days: 30)),
        hasCriticalTopic: true,
        testRouteName: _route,
      );
      expect(check.state, ReliabilityState.fine);
    });

    test('never received counts from when the check first looked', () {
      ReliabilityState stateWatchedFor(Duration d) =>
          LastPushSource.lastPushCheckFor(
            now: _now,
            lastPushAt: null,
            watchingSince: ago(d),
            hasCriticalTopic: true,
            testRouteName: _route,
          ).state;
      expect(stateWatchedFor(const Duration(days: 7)), ReliabilityState.fine);
      expect(
        stateWatchedFor(const Duration(days: 8)),
        ReliabilityState.needsLook,
      );
    });
  });

  group('source and reader', () {
    late SharedPreferences prefs;
    late LastPushStore store;
    var now = _now;

    LastPushSource build({
      required bool critical,
      Future<List<Object?>> Function()? nativeRows,
      TargetPlatform platform = TargetPlatform.android,
    }) => LastPushSource(
      reader: LastPushReader(prefs, store, nativeRows: nativeRows),
      capabilities: PlatformCapabilities(isWeb: false, platform: platform),
      hasCriticalTopic: () async => critical,
      testRouteName: _route,
      now: () => now,
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      store = LastPushStore(prefs);
      now = _now;
    });

    test('a push the drain stored counts', () async {
      await store.record(_now.subtract(const Duration(days: 2)));
      final check = (await build(critical: true).read()).single;
      expect(check.state, ReliabilityState.fine);
      expect(check.lastKnownGood, _now.subtract(const Duration(days: 2)));
    });

    test('a push still waiting in the pending list counts', () async {
      await prefs.setString(
        'pending_push_events',
        jsonEncode([
          {
            'name': 'push_received',
            'at_ms': _now
                .subtract(const Duration(hours: 1))
                .millisecondsSinceEpoch,
          },
          {'name': 'push_dropped', 'at_ms': _now.millisecondsSinceEpoch},
        ]),
      );
      final check = (await build(critical: true).read()).single;
      expect(check.lastKnownGood, _now.subtract(const Duration(hours: 1)));
    });

    test(
      'rows the native side reports count, and a failing read is ignored',
      () async {
        final fresh = _now.subtract(const Duration(hours: 4));
        final check = (await build(
          critical: true,
          nativeRows: () async => [
            {'name': 'push_received', 'at_ms': fresh.millisecondsSinceEpoch},
          ],
        ).read()).single;
        expect(check.lastKnownGood, fresh);

        final broken = (await build(
          critical: true,
          nativeRows: () async => throw StateError('no channel'),
        ).read()).single;
        expect(broken.state, ReliabilityState.fine);
      },
    );

    test('with no push ever, silence counts from the first read', () async {
      expect(
        (await build(critical: true).read()).single.state,
        ReliabilityState.fine,
      );
      now = _now.add(const Duration(days: 7));
      expect(
        (await build(critical: true).read()).single.state,
        ReliabilityState.fine,
      );
      now = _now.add(const Duration(days: 7, seconds: 1));
      expect(
        (await build(critical: true).read()).single.state,
        ReliabilityState.needsLook,
      );
    });

    test('the web has no push, so the check is not on this phone', () async {
      final source = LastPushSource(
        reader: LastPushReader(prefs, store),
        capabilities: const PlatformCapabilities(
          isWeb: true,
          platform: TargetPlatform.android,
        ),
        hasCriticalTopic: () async => true,
        testRouteName: _route,
        now: () => _now,
      );
      expect(
        (await source.read()).single.state,
        ReliabilityState.notOnThisPhone,
      );
    });
  });
}
