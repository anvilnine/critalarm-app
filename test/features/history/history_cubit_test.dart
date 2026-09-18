import 'dart:convert';

import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/features/history/presentation/cubits/history_cubit.dart';
import 'package:critalarm/features/history/presentation/cubits/history_state.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers with the list it was handed, cut to whatever the caller asked for,
/// the way the server cuts to `limit`.
class _FixedIncidents implements IncidentRepository {
  _FixedIncidents(this.all);

  final List<Incident> all;

  @override
  Future<AppResult<List<Incident>>> getIncidents({
    required int limit,
    String? state,
    String? topic,
  }) async => all.take(limit).toList().toSuccess();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// A server that is not answering.
class _FailingIncidents implements IncidentRepository {
  @override
  Future<AppResult<List<Incident>>> getIncidents({
    required int limit,
    String? state,
    String? topic,
  }) async => const Failure.api(statusCode: 500).toFailure();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// A paid account: no cap on how many alarms it may show, 90 days of them.
const _paid = AccountCaps(devices: 5, p4Daily: 1000, historyDays: 90);

Incident _incident({
  required String id,
  required String topic,
  required DateTime openedAt,
  String state = IncidentStates.acked,
  DateTime? ackedAt,
  DateTime? closedAt,
}) => Incident(
  id: id,
  topic: topic,
  state: state,
  openedAt: openedAt,
  ackedAt: ackedAt,
  closedAt: closedAt,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 9, 11, 9, 44);

  /// Alarms a minute apart, newest first, all well inside every window.
  List<Incident> manyIncidents(int count) => [
    for (var i = 0; i < count; i++)
      _incident(
        id: 'i$i',
        topic: 'prod-db',
        openedAt: now.subtract(Duration(minutes: i + 1)),
      ),
  ];

  /// A History tab reading [incidents] on an account with [caps].
  Future<HistoryCubit> historyFor(
    List<Incident> incidents,
    AccountCaps caps,
  ) async {
    SharedPreferences.setMockInitialValues({
      'device_id': 'dev_1',
      'account_id': 'acc_1',
      'account_tier': 'paid',
      'account_caps': jsonEncode(caps.toJson()),
    });
    final prefs = await SharedPreferences.getInstance();
    final shared = IncidentsCubit(
      GetIncidentsUsecase(_FixedIncidents(incidents)),
    );
    addTearDown(shared.close);
    final history = HistoryCubit(
      shared,
      now: () => now,
      identityStore: DeviceIdentityStore(prefs),
    );
    addTearDown(history.close);
    await history.load();
    return history;
  }

  group('HistoryCubit.toEntries', () {
    test('drops incidents older than the 30 day window', () {
      final entries = HistoryCubit.toEntries([
        _incident(
          id: 'i1',
          topic: 'prod-db',
          openedAt: now.subtract(const Duration(days: 2)),
        ),
        _incident(
          id: 'i2',
          topic: 'old-one',
          openedAt: now.subtract(const Duration(days: 31)),
        ),
      ], now);

      expect(entries.map((e) => e.id), ['i1']);
    });

    test('drops incidents with no start time', () {
      final entries = HistoryCubit.toEntries([
        const Incident(id: 'i1', topic: 'prod-db'),
      ], now);

      expect(entries, isEmpty);
    });

    test('ring time runs from opened to acknowledged', () {
      final opened = now.subtract(const Duration(minutes: 10));
      final entries = HistoryCubit.toEntries([
        _incident(
          id: 'i1',
          topic: 'prod-db',
          openedAt: opened,
          ackedAt: opened.add(const Duration(minutes: 2, seconds: 14)),
        ),
      ], now);

      expect(
        entries.single.ringDuration,
        const Duration(minutes: 2, seconds: 14),
      );
    });

    test('an open incident is still ringing, so it counts up to now', () {
      final entries = HistoryCubit.toEntries([
        _incident(
          id: 'i1',
          topic: 'prod-db',
          state: IncidentStates.open,
          openedAt: now.subtract(const Duration(seconds: 44)),
        ),
      ], now);

      expect(entries.single.ringDuration, const Duration(seconds: 44));
    });

    test('newest first', () {
      final entries = HistoryCubit.toEntries([
        _incident(
          id: 'older',
          topic: 'a',
          openedAt: now.subtract(const Duration(days: 3)),
        ),
        _incident(
          id: 'newer',
          topic: 'b',
          openedAt: now.subtract(const Duration(hours: 6)),
        ),
      ], now);

      expect(entries.map((e) => e.id), ['newer', 'older']);
    });
  });

  group('what each tier sees', () {
    test('a free user sees 20 of them', () async {
      final history = await historyFor(manyIncidents(250), AccountCaps.free);

      expect(history.state.entries, hasLength(20));
      expect(history.state.isCapped, isTrue);
    });

    test('a paid user sees 200, which is all the app can fetch', () async {
      final history = await historyFor(manyIncidents(250), _paid);

      expect(history.state.entries, hasLength(200));
      expect(history.state.isCapped, isTrue);
    });

    test('a paid user with fewer alarms sees all of them, uncapped', () async {
      final history = await historyFor(manyIncidents(30), _paid);

      expect(history.state.entries, hasLength(30));
      expect(history.state.isCapped, isFalse);
    });

    test('a free user below the cap is not capped', () async {
      final history = await historyFor(manyIncidents(5), AccountCaps.free);

      expect(history.state.entries, hasLength(5));
      expect(history.state.isCapped, isFalse);
    });

    test('the ceiling is the lower of the plan and what one call reads', () {
      expect(HistoryCubit.ceilingFor(AccountCaps.free), 20);
      expect(HistoryCubit.ceilingFor(_paid), 200);
      expect(
        HistoryCubit.ceilingFor(const AccountCaps(historyIncidents: 500)),
        200,
      );
    });
  });

  group('HistoryCubit.groupByDay', () {
    test('puts two alarms from the same day in one group', () {
      final entries = HistoryCubit.toEntries([
        _incident(id: 'a', topic: 'x', openedAt: DateTime(2026, 9, 9, 4, 41)),
        _incident(id: 'b', topic: 'y', openedAt: DateTime(2026, 9, 9, 21, 8)),
        _incident(id: 'c', topic: 'z', openedAt: DateTime(2026, 9, 8, 13, 55)),
      ], now);

      final days = HistoryCubit.groupByDay(entries);

      expect(days.length, 2);
      expect(days.first.day, DateTime(2026, 9, 9));
      expect(days.first.entries.map((e) => e.id), ['b', 'a']);
      expect(days.last.entries.map((e) => e.id), ['c']);
    });
  });

  group('HistoryState', () {
    test('counts alarms across every day', () {
      final entries = HistoryCubit.toEntries([
        _incident(id: 'a', topic: 'x', openedAt: DateTime(2026, 9, 9, 4, 41)),
        _incident(id: 'b', topic: 'y', openedAt: DateTime(2026, 9, 8, 21, 8)),
      ], now);

      final state = HistoryState(days: HistoryCubit.groupByDay(entries));

      expect(state.alarmCount, 2);
    });

    test('longest ring is the biggest of them', () {
      final entries = HistoryCubit.toEntries([
        _incident(
          id: 'a',
          topic: 'x',
          openedAt: DateTime(2026, 9, 9, 4, 41),
          ackedAt: DateTime(2026, 9, 9, 4, 47, 2),
        ),
        _incident(
          id: 'b',
          topic: 'y',
          openedAt: DateTime(2026, 9, 8, 21, 8),
          ackedAt: DateTime(2026, 9, 8, 21, 8, 18),
        ),
      ], now);

      final state = HistoryState(days: HistoryCubit.groupByDay(entries));

      expect(state.longestRing, const Duration(minutes: 6, seconds: 2));
    });

    test('longest ring is null when nothing rang', () {
      const state = HistoryState();
      expect(state.longestRing, isNull);
    });
  });

  group('HistoryCubit.refresh', () {
    test('reports true when the list loads', () async {
      final history = await historyFor(manyIncidents(3), _paid);
      expect(await history.refresh(), isTrue);
    });

    test('reports false when the server does not answer', () async {
      final shared = IncidentsCubit(GetIncidentsUsecase(_FailingIncidents()));
      addTearDown(shared.close);
      final history = HistoryCubit(shared, now: () => now);
      addTearDown(history.close);
      expect(await history.refresh(), isFalse);
    });
  });
}
