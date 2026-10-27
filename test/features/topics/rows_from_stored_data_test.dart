import 'dart:async';

import 'package:critalarm/app/state/held_rows.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/store/held_scope.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/history/presentation/cubits/history_cubit.dart';
import 'package:critalarm/features/history/presentation/cubits/history_state.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';
import 'package:critalarm/features/topics/domain/home_card/inbox_order.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/update_topic_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_state.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_state.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_glances.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/access/access_fakes.dart';

/// The topic list the server gives, held back until the test lets it go.
class _GatedTopics implements TopicRepository {
  _GatedTopics(this._inner);

  final TopicRepository _inner;
  final gate = Completer<void>();

  @override
  Future<AppResult<List<Topic>>> getTopics() async {
    await gate.future;
    return _inner.getTopics();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Counts every request that goes to the server per topic.
class _CountingIncidents extends InMemoryIncidentRepository {
  _CountingIncidents(super._client, this.polled, {super.store});

  final List<String> polled;

  @override
  Future<AppResult<List<Message>>> pollMessages(
    String topic, {
    required int poll,
    String? since,
  }) {
    polled.add(topic);
    return super.pollMessages(topic, poll: poll, since: since);
  }
}

final DateTime _created = DateTime.utc(2026);

/// Whole seconds, because the server's messages carry no more.
final DateTime _now = DateTime.fromMillisecondsSinceEpoch(
  DateTime.now().millisecondsSinceEpoch ~/ 1000 * 1000,
);

int _secondsAgo(int s) => _now.millisecondsSinceEpoch ~/ 1000 - s;

void main() {
  sqfliteFfiInit();

  final scope = heldScopeFor(
    serverUrl: 'https://api.example',
    accountId: 'a1',
  )!;
  late LocalStore store;
  late MockServer server;
  late MockApiClient api;
  late _CountingIncidents repo;
  final polled = <String>[];
  late IncidentsCubit incidents;
  late _GatedTopics gatedTopics;
  late TopicsCubit topics;
  late AccountIdentityChanges identity;
  late TopicGlances glances;
  late HeldRows held;

  final storedMessage = Message(
    id: 'm-ringing',
    topic: 'ringing',
    time: _secondsAgo(120),
    priority: 5,
    title: 'Disk full',
    message: 'Disk is full',
    incidentId: 'i-ringing',
  );
  final calmMessage = Message(
    id: 'm-calm',
    topic: 'calm',
    time: _secondsAgo(3600),
    message: 'Backup done',
  );

  /// The alarm as the phone stored it: still open.
  final storedOpen = Incident(
    id: 'i-ringing',
    topic: 'ringing',
    openedAt: _now.subtract(const Duration(minutes: 2)),
    updatedAt: _now.subtract(const Duration(minutes: 2)),
    lastMessageAt: _now.subtract(const Duration(minutes: 2)),
    messages: [storedMessage],
  );

  /// The same alarm as the server has it now: closed while the phone was off.
  final closedOnServer = storedOpen.copyWith(
    state: IncidentStates.closed,
    closedAt: _now.subtract(const Duration(minutes: 1)),
    updatedAt: _now.subtract(const Duration(minutes: 1)),
  );

  setUp(() async {
    store = await LocalStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    server = MockServer()..reset();
    api = MockApiClient(server);
    polled.clear();
    repo = _CountingIncidents(api, polled, store: store);
    identity = AccountIdentityChanges();
    // Each call is later than the one before, so an update applied after a
    // request started is always newer than that request.
    var tick = 0;
    incidents = IncidentsCubit(
      GetIncidentsUsecase(repo),
      identityChanges: identity,
      now: () => DateTime.utc(2030).add(Duration(seconds: tick++)),
    );
    gatedTopics = _GatedTopics(InMemoryTopicRepository(api));
    topics = TopicsCubit(
      GetTopicsUsecase(gatedTopics),
      held: store.topics,
      heldScope: () async => scope,
      identityChanges: identity,
    );
    glances = TopicGlances();
    held = HeldRows(
      repo,
      topics,
      incidents,
      glances: glances,
      readPlan: () async =>
          const HeldPlan(hasLongHistory: false, historyDays: 7),
      identityChanges: identity,
    );

    // The server has the alarm closed. The phone stored it open.
    server.seedState(
      topics: [
        Topic(name: 'calm', createdAt: _created),
        Topic(name: 'ringing', critical: true, createdAt: _created),
      ],
      incidents: [closedOnServer],
      messages: [storedMessage, calmMessage],
    );
    await store.topics.replaceAll(scope, [
      Topic(name: 'calm', createdAt: _created),
      Topic(name: 'ringing', critical: true, createdAt: _created),
    ]);
    await store.incidents.upsertAll([storedOpen]);
    await store.messages.upsertAll([calmMessage]);
  });

  tearDown(() async {
    if (!gatedTopics.gate.isCompleted) gatedTopics.gate.complete();
    await topics.writesDone;
    await held.dispose();
    await incidents.close();
    await topics.close();
    await store.close();
  });

  HomeCubit home({Duration tick = const Duration(seconds: 5)}) {
    final cubit = HomeCubit(
      incidents,
      topics,
      repo,
      null,
      null,
      null,
      tick,
      null,
      glances,
      null,
      held,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  Future<void> readPhone() async {
    await topics.loadHeld();
    await held.load();
  }

  group('Home from the stored alarms and messages', () {
    test(
      'draws the rows in the first frame and asks nothing per topic',
      () async {
        await readPhone();
        expect(held.snapshot, isNotNull);
        final cubit = home();

        final load = cubit.load();
        // Not one await since the call: this is the state the first frame gets.
        expect(cubit.state.status, HomeStatus.success);
        expect(cubit.state.topicItems.map((t) => t.name).toSet(), {
          'calm',
          'ringing',
        });
        final calm = cubit.state.topicItems.firstWhere((t) => t.name == 'calm');
        expect(calm.preview, 'Backup done');

        await pumpEventQueue();
        // The server's topic list is still on its way, and no topic was asked
        // for its messages.
        expect(topics.state.isKept, isTrue);
        expect(polled, isEmpty);

        gatedTopics.gate.complete();
        await load;

        // The refresh asks each topic once, and only after the list answered.
        expect(polled.toList()..sort(), ['calm', 'ringing']);
        expect(cubit.state.status, HomeStatus.success);
      },
    );

    test('a failed refresh keeps the rows and calls them old', () async {
      await readPhone();
      final failing = TopicsCubit(
        GetTopicsUsecase(_Failing()),
        held: store.topics,
        heldScope: () async => scope,
        identityChanges: identity,
      );
      addTearDown(failing.close);
      await failing.loadHeld();
      final cubit = HomeCubit(
        incidents,
        failing,
        repo,
        null,
        null,
        null,
        const Duration(seconds: 5),
        null,
        glances,
        null,
        held,
      );
      addTearDown(cubit.close);

      final load = cubit.load();
      expect(cubit.state.topicItems, isNotEmpty);
      await load;
      await pumpEventQueue();

      expect(cubit.state.status, HomeStatus.failure);
      expect(cubit.state.topicItems, isNotEmpty);
      expect(cubit.state.isStale, isTrue);
      expect(cubit.state.ringingIncidentId, isNull);
    });

    test('a topic list the server answered first still draws the alarms the '
        'phone holds until the incidents answer', () async {
      await readPhone();
      gatedTopics.gate.complete();
      await topics.refresh();
      expect(topics.state.isKept, isFalse);

      final cubit = home();
      final load = cubit.load();
      expect(cubit.state.status, HomeStatus.success);
      expect(cubit.state.ringingIncidentId, isNull);
      await load;
    });

    test('once the incidents have answered nothing is seeded', () async {
      await readPhone();
      await incidents.refresh();
      await pumpEventQueue();

      final cubit = home();
      final load = cubit.load();
      expect(cubit.state.status, HomeStatus.loading);
      gatedTopics.gate.complete();
      await load;
    });
  });

  group('an alarm closed on the server while the phone was off', () {
    test('shows open as stored, hands over to nothing, then closes', () async {
      await readPhone();
      final cubit = home(tick: const Duration(milliseconds: 5));
      final seen = <HomeState>[];
      final sub = cubit.stream.listen(seen.add);
      addTearDown(sub.cancel);

      final load = cubit.load();
      final seed = cubit.state;
      // The store says open, so the row says open.
      expect(
        seed.topicItems.firstWhere((t) => t.name == 'ringing').rowKind,
        InboxRowKind.ringing,
      );
      // But nothing hands over to the alarm screen from a copy, not in the
      // first frame and not on the timer's repaints that follow.
      expect(seed.ringingIncidentId, isNull);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(cubit.state.ringingIncidentId, isNull);

      gatedTopics.gate.complete();
      await load;
      await pumpEventQueue();

      // The first refresh closed it.
      final row = cubit.state.topicItems.firstWhere((t) => t.name == 'ringing');
      expect(row.rowKind, isNot(InboxRowKind.ringing));
      expect(cubit.state.facts.ringing, isNull);
      expect(incidents.state.openIncidents, isEmpty);
      // At no point did any state carry a ringing incident.
      expect(seen.every((s) => s.ringingIncidentId == null), isTrue);
      expect(cubit.state.ringingIncidentId, isNull);
    });

    test('the timer repainting the copy does not hand over either', () async {
      // An acknowledged alarm on another topic keeps the timer running.
      await store.incidents.upsertAll([
        Incident(
          id: 'i-acked',
          topic: 'calm',
          state: IncidentStates.acked,
          openedAt: _now.subtract(const Duration(minutes: 5)),
          // Older than the alarm above, so the next request still asks for
          // what changed since that one.
          ackedAt: _now.subtract(const Duration(seconds: 150)),
          updatedAt: _now.subtract(const Duration(seconds: 150)),
        ),
      ]);
      await readPhone();
      final cubit = home(tick: const Duration(milliseconds: 5));
      final seen = <HomeState>[];
      final sub = cubit.stream.listen(seen.add);
      addTearDown(sub.cancel);

      unawaited(cubit.load());
      expect(cubit.state.facts.acknowledged, isNotNull);
      expect(cubit.state.facts.ringing, isNotNull);
      // Several ticks of the timer.
      seen.clear();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(seen, isNotEmpty);
      expect(seen.every((s) => s.ringingIncidentId == null), isTrue);
      expect(cubit.state.ringingIncidentId, isNull);
    });

    test('the shared list is never filled from the stored copy', () async {
      await readPhone();
      // What rings, badges and hands over reads this list.
      expect(incidents.state.incidents, isEmpty);
      expect(incidents.state.isReady, isFalse);
    });

    test(
      'the Topic screen opens with the stored rows, then the server',
      () async {
        await readPhone();
        final cubit = TopicDetailCubit(
          incidents,
          topics,
          UpdateTopicUsecase(InMemoryTopicRepository(api)),
          repo,
          glances: glances,
          held: held,
        );
        addTearDown(cubit.close);

        final load = cubit.load('ringing');
        final seed = cubit.state;
        expect(seed.status, TopicDetailStatus.success);
        expect(seed.isMessagesLoading, isFalse);
        expect(seed.messages.map((m) => m.title), ['Disk full']);
        expect(seed.openIncidentIds, ['i-ringing']);
        await pumpEventQueue();
        expect(polled, isEmpty);

        gatedTopics.gate.complete();
        await load;
        expect(cubit.state.openIncidentIds, isEmpty);
        expect(polled, ['ringing']);
      },
    );

    test('History opens with the stored alarms, then the server', () async {
      await readPhone();
      final cubit = HistoryCubit(
        incidents,
        store: store,
        held: held,
      );
      addTearDown(cubit.close);

      final load = cubit.load();
      expect(cubit.state.status, HistoryStatus.success);
      final first = cubit.state.entries.single;
      expect(first.id, 'i-ringing');
      expect(first.state, IncidentState.open);

      await load;
      expect(cubit.state.entries.single.state, IncidentState.closed);
    });
  });

  group('an alarm that lands before the first answer', () {
    final ringingNow = Incident(
      id: 'i-new',
      topic: 'ringing',
      openedAt: _now,
      updatedAt: _now,
      lastMessageAt: _now,
      messages: [
        Message(
          id: 'm-new',
          topic: 'ringing',
          time: _secondsAgo(1),
          priority: 5,
          incidentId: 'i-new',
        ),
      ],
    );

    /// The phone stored a calm picture: the alarm is closed.
    Future<void> storeCalm() async {
      await store.incidents.upsertAll([closedOnServer]);
    }

    test('Home shows it, not the calm copy', () async {
      await storeCalm();
      await readPhone();
      final cubit = home();
      final load = cubit.load();
      expect(cubit.state.facts.ringing, isNull);
      expect(cubit.state.ringingIncidentId, isNull);

      // The alarm screen applies the incident while the first request is out.
      incidents.applyIncident(ringingNow);
      await pumpEventQueue();

      expect(held.snapshot, isNull);
      expect(cubit.state.facts.ringing?.incidentId, 'i-new');
      expect(cubit.state.ringingIncidentId, 'i-new');
      expect(
        cubit.state.topicItems.firstWhere((t) => t.name == 'ringing').rowKind,
        InboxRowKind.ringing,
      );
      // The request that was out is older than the alarm and is dropped, so
      // the shared list never became ready: the copy must not come back.
      expect(incidents.state.isReady, isFalse);

      gatedTopics.gate.complete();
      await load;
    });

    test('the Topic screen shows it, not the calm copy', () async {
      await storeCalm();
      await readPhone();
      final cubit = TopicDetailCubit(
        incidents,
        topics,
        UpdateTopicUsecase(InMemoryTopicRepository(api)),
        repo,
        glances: glances,
        held: held,
      );
      addTearDown(cubit.close);

      final load = cubit.load('ringing');
      expect(cubit.state.openIncidentIds, isEmpty);

      incidents.applyIncident(ringingNow);
      await pumpEventQueue();

      expect(cubit.state.openIncidentIds, ['i-new']);
      expect(cubit.state.severity, SeverityMode.crit);

      gatedTopics.gate.complete();
      await load;
    });
  });

  group('the launch', () {
    test('skips the read for an alarm screen and for nothing else', () {
      expect(HeldRows.skipsLaunchAt('/incidents/i-1'), isTrue);
      expect(HeldRows.skipsLaunchAt('/alarm'), isTrue);
      expect(HeldRows.skipsLaunchAt('/'), isFalse);
      expect(HeldRows.skipsLaunchAt('/topics/prod-db'), isFalse);
    });

    test('an abandoned read leaves no snapshot and no glance', () async {
      await topics.loadHeld();
      final read = held.load();
      held.abandon();
      await read;
      expect(held.snapshot, isNull);
      expect(glances.of('calm', createdAt: _created), isNull);
    });

    test('the plan is never waited for', () async {
      SharedPreferences.setMockInitialValues({
        'device_id': 'd1',
        'device_token': 't1',
        'account_id': 'acc',
        'account_caps': '{"history_days":7}',
      });
      final prefs = await SharedPreferences.getInstance();
      final identities = DeviceIdentityStore(prefs);
      final pending = Completer<void>();
      final source = FakeHoldingSource(Holding.hosted)..ready = pending.future;
      final holdings = Holdings([source]);
      final access = FeatureAccess(holdings: holdings);
      addTearDown(access.dispose);
      addTearDown(holdings.dispose);

      // Not read yet: answers at once with nothing instead of waiting.
      final early = await heldPlanFrom(
        access: access,
        identities: identities,
      ).timeout(const Duration(milliseconds: 100));
      expect(early, isNull);

      pending.complete();
      await access.ready;
      final plan = await heldPlanFrom(access: access, identities: identities);
      expect(plan?.historyDays, 7);
      expect(plan?.hasLongHistory, isFalse);
    });
  });

  group('the snapshot', () {
    test('is dropped by the first answer for the incidents', () async {
      await readPhone();
      expect(held.snapshot, isNotNull);
      await incidents.refresh();
      await pumpEventQueue();
      expect(held.snapshot, isNull);
    });

    test('is dropped by an incident applied before any answer', () async {
      await readPhone();
      incidents.applyIncident(storedOpen);
      await pumpEventQueue();
      expect(held.snapshot, isNull);
    });

    test('is dropped when the account changes', () async {
      await readPhone();
      identity.bump();
      expect(held.snapshot, isNull);
      await pumpEventQueue();
    });

    test('is not taken for a topic list the server already answered', () async {
      gatedTopics.gate.complete();
      await topics.refresh();
      await held.load();
      expect(held.snapshot, isNull);
    });

    test('is not taken when the plan cannot be read', () async {
      final unknown = HeldRows(
        repo,
        topics,
        incidents,
        glances: glances,
        readPlan: () async => null,
        identityChanges: identity,
      );
      addTearDown(unknown.dispose);
      await topics.loadHeld();
      await unknown.load();
      expect(unknown.snapshot, isNull);
    });

    test('shows only what the plan shows', () async {
      final old = Incident(
        id: 'i-old',
        topic: 'calm',
        state: IncidentStates.closed,
        openedAt: _now.subtract(const Duration(days: 30)),
        updatedAt: _now.subtract(const Duration(days: 30)),
      );
      await store.incidents.upsertAll([old]);
      await readPhone();
      final snapshot = held.snapshot!;
      expect(snapshot.plan.shownDays, 7);
      expect(snapshot.olderCount, 1);

      final cubit = HistoryCubit(
        incidents,
        store: store,
        held: held,
      );
      addTearDown(cubit.close);
      final load = cubit.load();
      expect(cubit.state.entries.map((e) => e.id), [
        'i-ringing',
      ]);
      expect(cubit.state.olderCount, 1);
      await load;
    });
  });
}

class _Failing implements TopicRepository {
  @override
  Future<AppResult<List<Topic>>> getTopics() async =>
      const Failure.api(statusCode: 500).toFailure();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
