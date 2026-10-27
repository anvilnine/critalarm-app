import 'dart:async';
import 'dart:io';

import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/features/history/presentation/cubits/history_cubit.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' show Sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../app/access/store_access.dart';

final _now = DateTime.utc(2026, 9, 22, 12);

DateTime _at(int daysAgo) => _now.subtract(Duration(days: daysAgo));

Incident _incident(String id, {required int daysAgo, String topic = 'prod'}) {
  final openedAt = _at(daysAgo);
  return Incident(
    id: id,
    topic: topic,
    state: IncidentStates.closed,
    openedAt: openedAt,
    updatedAt: openedAt,
    lastMessageAt: openedAt,
    messages: [
      Message(
        id: 'msg_$id',
        topic: topic,
        time: openedAt.millisecondsSinceEpoch ~/ 1000,
        priority: 4,
        message: 'disk full',
        incidentId: id,
      ),
    ],
  );
}

/// The account the phone is on, set by hand. A change also rings the identity
/// bell, the way a sign-in, a sign-out or a switch does in the app.
class _Phone {
  _Phone(this.account);

  String? account;
  final changes = AccountIdentityChanges();

  Future<String?> scope() async => account;

  void moveTo(String? next) {
    account = next;
    changes.bump();
  }
}

/// The incidents and messages tables as version 3 left them, one table of each
/// with no scope column, plus the topics table.
Future<void> _createV3(Database db, int version) async {
  await db.execute('''
    CREATE TABLE incidents (
      id TEXT PRIMARY KEY, topic TEXT NOT NULL, state TEXT NOT NULL,
      opened_at INTEGER NOT NULL, acked_at INTEGER, closed_at INTEGER,
      updated_at INTEGER, last_message_at INTEGER NOT NULL, max_ring_s INTEGER,
      priority INTEGER NOT NULL, synced_at INTEGER NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX incidents_opened ON incidents(opened_at DESC)',
  );
  await db.execute('''
    CREATE TABLE messages (
      id TEXT PRIMARY KEY, topic TEXT NOT NULL, incident_id TEXT,
      title TEXT, body TEXT, priority INTEGER NOT NULL, tags TEXT,
      click TEXT, markdown INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL, synced_at INTEGER NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX messages_topic_created ON messages(topic, created_at DESC)',
  );
  await db.execute('''
    CREATE TABLE topics (
      scope TEXT NOT NULL, position INTEGER NOT NULL, name TEXT NOT NULL,
      critical INTEGER NOT NULL DEFAULT 0, repeat_interval_s INTEGER NOT NULL,
      max_ring_s INTEGER NOT NULL, desk_timer_s INTEGER NOT NULL,
      relay_content TEXT NOT NULL, created_at_ms INTEGER,
      synced_at INTEGER NOT NULL,
      PRIMARY KEY (scope, name)
    )
  ''');
}

Future<String> _v3File() async {
  final dir = await Directory.systemTemp.createTemp('critalarm_scope');
  addTearDown(() => dir.delete(recursive: true));
  final path = p.join(dir.path, 'critalarm.db');
  final v3 = await databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(version: 3, onCreate: _createV3),
  );
  await v3.insert('incidents', {
    'id': 'inc_1',
    'topic': 'prod',
    'state': IncidentStates.closed,
    'opened_at': 1000,
    'acked_at': 1100,
    'closed_at': 1200,
    'updated_at': 1300,
    'last_message_at': 1050,
    'max_ring_s': null,
    'priority': 5,
    'synced_at': 1400,
  });
  await v3.insert('incidents', {
    'id': 'inc_2',
    'topic': 'web',
    'state': IncidentStates.open,
    'opened_at': 2000,
    'acked_at': null,
    'closed_at': null,
    'updated_at': 2000,
    'last_message_at': 2000,
    'max_ring_s': null,
    'priority': 3,
    'synced_at': 2100,
  });
  await v3.insert('messages', {
    'id': 'msg_1',
    'topic': 'prod',
    'incident_id': 'inc_1',
    'title': 'Disk',
    'body': 'disk full',
    'priority': 5,
    'tags': '["warning"]',
    'click': null,
    'markdown': 0,
    'created_at': 1050,
    'synced_at': 1400,
  });
  await v3.insert('messages', {
    'id': 'msg_2',
    'topic': 'prod',
    'incident_id': null,
    'title': null,
    'body': 'loose',
    'priority': 3,
    'tags': null,
    'click': null,
    'markdown': 1,
    'created_at': 3000,
    'synced_at': 3100,
  });
  await v3.close();
  return path;
}

class _Spy extends MockApiClient {
  _Spy(super.server);

  final sinceSeen = <DateTime?>[];
  final messageSinceSeen = <String?>[];

  /// Runs inside the next list read, before it answers.
  void Function()? duringRead;

  /// Held open by a test that wants an acknowledge to answer late.
  Completer<void>? ackGate;

  /// Held open by a test that wants a lookup to answer late.
  Completer<void>? lookupGate;

  @override
  Future<Incident> getIncident(String id) async {
    final gate = lookupGate;
    if (gate != null) await gate.future;
    return super.getIncident(id);
  }

  /// Makes list reads answer with nothing, the way a second account that has
  /// no alarms yet would see the server.
  bool listsNothing = false;

  @override
  Future<Incident> ackIncident(String id) async {
    final gate = ackGate;
    if (gate != null) await gate.future;
    return super.ackIncident(id);
  }

  @override
  Future<List<Incident>> getIncidents({
    required int limit,
    String? state,
    String? topic,
    DateTime? since,
  }) async {
    sinceSeen.add(since);
    duringRead?.call();
    if (listsNothing) return const [];
    return super.getIncidents(
      limit: limit,
      state: state,
      topic: topic,
      since: since,
    );
  }

  @override
  Future<List<Message>> pollMessages(
    String topic, {
    required int poll,
    String? since,
  }) async {
    messageSinceSeen.add(since);
    return super.pollMessages(topic, poll: poll, since: since);
  }
}

class _Quiet implements IncidentRepository {
  @override
  Future<AppResult<List<Incident>>> getIncidents({
    required int limit,
    String? state,
    String? topic,
    DateTime? since,
    bool fullRefresh = false,
  }) async => <Incident>[].toSuccess();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Future<String> _scopeOf(LocalStore store, String incidentId) async =>
    (await store.db.query(
          'incidents',
          columns: const ['scope'],
          where: 'id = ?',
          whereArgs: [incidentId],
        )).first['scope']!
        as String;

Future<void> _settle(bool Function() isDone) async {
  for (var i = 0; i < 50 && !isDone(); i++) {
    await pumpEventQueue();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late _Phone phone;
  late LocalStore store;

  setUp(() async {
    phone = _Phone('acc_a');
    store = await LocalStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
      scope: phone.scope,
      identityChanges: phone.changes,
    );
  });

  tearDown(() async => store.close());

  group('reads', () {
    setUp(() async {
      await store.incidents.upsertAll([
        _incident('inc_1', daysAgo: 3),
        _incident('inc_2', daysAgo: 9, topic: 'web'),
      ]);
      await store.messages.upsertAll([
        const Message(id: 'loose', topic: 'prod', time: 5),
      ]);
    });

    test('the account that wrote the rows reads them all', () async {
      expect(await store.incidents.count(), 2);
      expect(await store.messages.count(), 3);
      expect(await store.incidents.newestOpenedAt(), _at(3));
      expect(await store.incidents.oldestOpenedAt(), _at(9));
      expect(await store.incidents.newestUpdatedAt(), _at(3));
      expect(await store.incidents.openedSince(_at(30)), hasLength(2));
      expect(await store.incidents.newestSince(_at(30)), hasLength(2));
      expect(await store.incidents.newestBefore(_now), hasLength(2));
      expect(await store.incidents.countOlderThan(_at(5)), 1);
      expect((await store.incidents.page()).first.messages, hasLength(1));
      expect(await store.messages.newestMessageId('prod'), 'msg_inc_1');
      expect(await store.messages.page(topic: 'prod'), hasLength(2));
      expect(await store.messages.countOlderThan(_now), 3);
    });

    test('another account reads nothing of it', () async {
      phone.moveTo('acc_b');

      expect(await store.incidents.count(), 0);
      expect(await store.messages.count(), 0);
      expect(await store.incidents.page(), isEmpty);
      expect(await store.incidents.page(topic: 'prod'), isEmpty);
      expect(await store.incidents.newestOpenedAt(), isNull);
      expect(await store.incidents.oldestOpenedAt(), isNull);
      // The cursor too: the next sync asks for the whole window.
      expect(await store.incidents.newestUpdatedAt(), isNull);
      expect(await store.incidents.openedSince(_at(30)), isEmpty);
      expect(await store.incidents.newestSince(_at(30)), isEmpty);
      expect(await store.incidents.newestBefore(_now), isEmpty);
      expect(await store.incidents.countOlderThan(_at(5)), 0);
      expect(await store.messages.newestMessageId('prod'), isNull);
      expect(await store.messages.page(topic: 'prod'), isEmpty);
      expect(await store.messages.countOlderThan(_now), 0);
      expect(await store.messages.groupedByIncident(['inc_1']), isEmpty);
      final stats = await store.stats();
      expect(stats.incidentCount, 0);
      expect(stats.messageCount, 0);
    });

    test('signed out reads nothing, and the rows are still there when the '
        'same account signs back in', () async {
      phone.moveTo(null);
      expect(await store.incidents.page(), isEmpty);
      expect(await store.messages.count(), 0);

      phone.moveTo('acc_a');
      expect(await store.incidents.count(), 2);
      expect(await store.messages.count(), 3);
    });

    test('two accounts keep their own copy of the same id', () async {
      phone.moveTo('acc_b');
      await store.incidents.upsertAll([_incident('inc_1', daysAgo: 1)]);
      expect((await store.incidents.page()).single.openedAt, _at(1));

      phone.moveTo('acc_a');
      expect(await store.incidents.count(), 2);
      expect(
        (await store.incidents.page()).map((i) => i.openedAt),
        [_at(3), _at(9)],
      );
    });
  });

  group('delete', () {
    test('deleting an account removes its rows and only its rows', () async {
      await store.incidents.upsertAll([_incident('inc_a', daysAgo: 3)]);
      phone.moveTo('acc_b');
      await store.incidents.upsertAll([_incident('inc_b', daysAgo: 2)]);

      await store.deleteCurrentArchive();

      expect(await store.incidents.count(), 0);
      expect(await store.messages.count(), 0);
      phone.moveTo('acc_a');
      expect((await store.incidents.page()).single.id, 'inc_a');
      expect(await store.messages.count(), 1);
    });

    test('auto-delete covers every account', () async {
      await store.incidents.upsertAll([_incident('inc_a', daysAgo: 30)]);
      phone.moveTo('acc_b');
      await store.incidents.upsertAll([_incident('inc_b', daysAgo: 30)]);

      expect(await store.incidents.deleteOlderThan(_at(10)), 2);
      expect(
        Sqflite.firstIntValue(
          await store.db.rawQuery('SELECT COUNT(*) FROM messages'),
        ),
        0,
      );
    });
  });

  group('writes that land after the account changed', () {
    test(
      'a write begun under one account is not stored under the next',
      () async {
        final ticket = store.incidents.beginWrite();
        phone.moveTo('acc_b');

        await store.incidents.upsertAll([
          _incident('inc_late', daysAgo: 1),
        ], ticket: ticket);

        expect(await store.incidents.count(), 0);
        expect(await store.messages.count(), 0);
        phone.moveTo('acc_a');
        expect(await store.incidents.count(), 0);
      },
    );

    test('the same holds when the identity bell rang and the account came '
        'back', () async {
      final ticket = store.messages.beginWrite();
      phone
        ..moveTo('acc_b')
        ..moveTo('acc_a');

      await store.messages.upsertAll([
        const Message(id: 'late', topic: 'prod', time: 1),
      ], ticket: ticket);

      expect(await store.messages.count(), 0);
    });

    test('a write with no account is not stored', () async {
      phone.moveTo(null);
      await store.incidents.upsertAll([_incident('inc_x', daysAgo: 1)]);
      phone.moveTo('acc_a');

      expect(await store.incidents.count(), 0);
    });

    test('a write begun and finished under one account is stored', () async {
      final ticket = store.incidents.beginWrite();
      await store.incidents.upsertAll([
        _incident('inc_ok', daysAgo: 1),
      ], ticket: ticket);

      expect(await store.incidents.count(), 1);
    });

    test(
      'a scope that cannot be read stores nothing and reads nothing',
      () async {
        final broken = await LocalStore.open(
          factory: databaseFactoryFfi,
          path: inMemoryDatabasePath,
          scope: () async => throw StateError('prefs gone'),
          identityChanges: AccountIdentityChanges(),
        );
        addTearDown(broken.close);

        await broken.incidents.upsertAll([_incident('inc_x', daysAgo: 1)]);

        expect(await broken.incidents.count(), 0);
        expect(await broken.incidents.page(), isEmpty);
      },
    );
  });

  group('delete and merge', () {
    test('a write that is still on its way when the account is deleted does '
        'not bring the rows back', () async {
      final ticket = store.incidents.beginWrite();
      final writing = store.incidents.upsertAll([
        _incident('inc_late', daysAgo: 1),
      ], ticket: ticket);
      final deleting = store.deleteCurrentArchive();
      await Future.wait([writing, deleting]);

      expect(await store.incidents.count(), 0);
      expect(await store.messages.count(), 0);
    });

    test('merging moves incidents and messages to the account they were '
        'folded into and keep the copy already there of a shared id', () async {
      await store.incidents.upsertAll([
        _incident('inc_a', daysAgo: 3),
        _incident('shared', daysAgo: 4, topic: 'old'),
      ]);
      phone.moveTo('acc_b');
      await store.incidents.upsertAll([
        _incident('inc_b', daysAgo: 2),
        _incident('shared', daysAgo: 1, topic: 'kept'),
      ]);
      final b = await _scopeOf(store, 'inc_b');
      phone.moveTo('acc_a');
      final a = await _scopeOf(store, 'inc_a');

      await store.mergeArchive(from: a, into: b);
      phone.moveTo('acc_b');

      expect(
        (await store.incidents.page()).map((i) => i.id).toSet(),
        {'inc_a', 'inc_b', 'shared'},
      );
      final shared = (await store.incidents.page()).firstWhere(
        (i) => i.id == 'shared',
      );
      expect(shared.topic, 'kept');
      expect(await store.messages.count(), 3);
      phone.moveTo('acc_a');
      expect(await store.incidents.count(), 0);
      expect(await store.messages.count(), 0);
    });
  });

  group('the migration', () {
    test('a file from before scopes keeps every row for the account the '
        'phone is on', () async {
      final path = await _v3File();

      final upgraded = await LocalStore.open(
        factory: databaseFactoryFfi,
        path: path,
        scope: phone.scope,
        identityChanges: phone.changes,
      );
      addTearDown(upgraded.close);

      expect(LocalStore.schemaVersion, 4);
      expect(
        Sqflite.firstIntValue(
          await upgraded.db.rawQuery('PRAGMA user_version'),
        ),
        4,
      );
      final page = await upgraded.incidents.page();
      expect(page.map((i) => i.id), ['inc_2', 'inc_1']);
      final first = page.last;
      expect(first.state, IncidentStates.closed);
      expect(first.ackedAt, isNotNull);
      expect(first.messages.single.message, 'disk full');
      expect(first.messages.single.tags, ['warning']);
      expect(await upgraded.messages.count(), 2);
      expect(
        (await upgraded.messages.page(topic: 'prod')).map((m) => m.id),
        ['msg_2', 'msg_1'],
      );
      expect(await upgraded.incidents.newestUpdatedAt(), isNotNull);
    });

    test('the upgraded rows never show to another account', () async {
      final path = await _v3File();
      final upgraded = await LocalStore.open(
        factory: databaseFactoryFfi,
        path: path,
        scope: phone.scope,
        identityChanges: phone.changes,
      );
      addTearDown(upgraded.close);

      phone.moveTo('acc_b');
      expect(await upgraded.incidents.count(), 0);
      expect(await upgraded.messages.count(), 0);
      expect(await upgraded.incidents.page(), isEmpty);

      phone.moveTo('acc_a');
      expect(await upgraded.incidents.count(), 2);
    });

    test('the new key lets two accounts hold the same id', () async {
      final path = await _v3File();
      final upgraded = await LocalStore.open(
        factory: databaseFactoryFfi,
        path: path,
        scope: phone.scope,
        identityChanges: phone.changes,
      );
      addTearDown(upgraded.close);

      phone.moveTo('acc_b');
      await upgraded.incidents.upsertAll([_incident('inc_1', daysAgo: 1)]);

      expect(await upgraded.incidents.count(), 1);
      phone.moveTo('acc_a');
      expect(await upgraded.incidents.count(), 2);
    });

    test('a phone on no account at the upgrade keeps the rows out of '
        'reach of every account', () async {
      final path = await _v3File();
      // No server is saved while the file upgrades. The account signs in
      // after that.
      var upgrading = true;
      final upgraded = await LocalStore.open(
        factory: databaseFactoryFfi,
        path: path,
        scope: () async => upgrading ? null : phone.account,
        identityChanges: phone.changes,
      );
      addTearDown(upgraded.close);
      upgrading = false;

      expect(await upgraded.incidents.count(), 0);
      phone.moveTo('acc_a');
      expect(await upgraded.incidents.count(), 0);
      expect(await upgraded.messages.count(), 0);
      // Still on disk until the server data is cleared.
      expect(
        Sqflite.firstIntValue(
          await upgraded.db.rawQuery('SELECT COUNT(*) FROM incidents'),
        ),
        2,
      );
      await upgraded.clearServerData();
      expect(
        Sqflite.firstIntValue(
          await upgraded.db.rawQuery('SELECT COUNT(*) FROM incidents'),
        ),
        0,
      );
    });

    test('a file from version 1 passes every step', () async {
      final dir = await Directory.systemTemp.createTemp('critalarm_scope');
      addTearDown(() => dir.delete(recursive: true));
      final path = p.join(dir.path, 'critalarm.db');
      final v1 = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE incidents (
                id TEXT PRIMARY KEY, topic TEXT NOT NULL, state TEXT NOT NULL,
                opened_at INTEGER NOT NULL, acked_at INTEGER, closed_at INTEGER,
                last_message_at INTEGER NOT NULL, max_ring_s INTEGER,
                priority INTEGER NOT NULL, synced_at INTEGER NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE messages (
                id TEXT PRIMARY KEY, topic TEXT NOT NULL, incident_id TEXT,
                title TEXT, body TEXT, priority INTEGER NOT NULL, tags TEXT,
                click TEXT, markdown INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL, synced_at INTEGER NOT NULL
              )
            ''');
          },
        ),
      );
      await v1.insert('incidents', {
        'id': 'inc_1',
        'topic': 'prod',
        'state': IncidentStates.closed,
        'opened_at': 1000,
        'acked_at': null,
        'closed_at': 1200,
        'last_message_at': 1050,
        'max_ring_s': null,
        'priority': 4,
        'synced_at': 1400,
      });
      await v1.close();

      final upgraded = await LocalStore.open(
        factory: databaseFactoryFfi,
        path: path,
        scope: phone.scope,
        identityChanges: phone.changes,
      );
      addTearDown(upgraded.close);

      expect((await upgraded.incidents.page()).single.id, 'inc_1');
      phone.moveTo('acc_b');
      expect(await upgraded.incidents.page(), isEmpty);
    });

    test('a file taken back to the old version and upgraded again keeps '
        'the scopes it has', () async {
      final dir = await Directory.systemTemp.createTemp('critalarm_scope');
      addTearDown(() => dir.delete(recursive: true));
      final path = p.join(dir.path, 'critalarm.db');
      final first = await LocalStore.open(
        factory: databaseFactoryFfi,
        path: path,
        scope: phone.scope,
        identityChanges: phone.changes,
      );
      await first.incidents.upsertAll([_incident('inc_a', daysAgo: 1)]);
      await first.db.execute('PRAGMA user_version = 3');
      await first.close();

      phone.moveTo('acc_b');
      final again = await LocalStore.open(
        factory: databaseFactoryFfi,
        path: path,
        scope: phone.scope,
        identityChanges: phone.changes,
      );
      addTearDown(again.close);

      expect(await again.incidents.count(), 0);
      phone.moveTo('acc_a');
      expect(await again.incidents.count(), 1);
    });

    test('a fresh install is on the scoped tables', () async {
      final columns = await store.db.rawQuery('PRAGMA table_info(incidents)');
      expect(columns.map((c) => c['name']), contains('scope'));
      final messageColumns = await store.db.rawQuery(
        'PRAGMA table_info(messages)',
      );
      expect(messageColumns.map((c) => c['name']), contains('scope'));
    });
  });

  group('the repository', () {
    late _Spy api;
    late InMemoryIncidentRepository repository;

    setUp(() {
      api = _Spy(MockServer());
      repository = InMemoryIncidentRepository(api, store: store);
    });

    test('another account asks the server for its whole window and is '
        'handed none of the alarms of the first account', () async {
      await store.incidents.upsertAll([_incident('inc_a', daysAgo: 3)]);
      phone.moveTo('acc_b');

      final result = await repository.getIncidents(limit: 200);

      expect(api.sinceSeen, [null]);
      expect(result.getOrNull(), isEmpty);
    });

    test('another account polling a topic is handed none of the '
        'messages of the first account', () async {
      await store.messages.upsertAll([
        const Message(id: 'm_a', topic: 'prod', time: 5),
      ]);
      phone.moveTo('acc_b');

      final result = await repository.pollMessages('prod', poll: 1);

      expect(api.messageSinceSeen, [null]);
      expect(result.getOrNull(), isEmpty);
    });

    test('an answer that lands after a switch is not stored for the next '
        'account', () async {
      api.server.seedAlarmed();
      api.duringRead = () => phone.moveTo('acc_b');

      final result = await repository.getIncidents(limit: 200);

      // Read for the account the phone is on now: nothing is held for it.
      expect(result.getOrNull(), isEmpty);
      expect(await store.incidents.count(), 0);
      phone.moveTo('acc_a');
      expect(await store.incidents.count(), 0);
    });

    test('an acknowledge answered after a switch is not stored for the next '
        'account', () async {
      api.server.seedAlarmed();
      final pending = repository.ackIncident('inc_alarmed_proddb');
      phone.moveTo('acc_b');

      final result = await pending;

      expect(result.isSuccess(), isTrue);
      expect(await store.incidents.count(), 0);
    });

    test('an alarm saved while signed out is not stored', () async {
      phone.moveTo(null);

      await repository.saveIncident(_incident('inc_push', daysAgo: 0));
      phone.moveTo('acc_a');

      expect(await store.incidents.count(), 0);
    });

    test('an alarm saved mid switch is dropped, and one saved after it is '
        'stored for the account it landed under', () async {
      final saving = repository.saveIncident(_incident('inc_a', daysAgo: 0));
      phone.moveTo('acc_b');
      await saving;
      expect(await store.incidents.count(), 0);

      await repository.saveIncident(_incident('inc_b', daysAgo: 0));
      expect((await store.incidents.page()).single.id, 'inc_b');
      phone.moveTo('acc_a');
      expect(await store.incidents.count(), 0);
    });

    test('a server that is down hands the second account nothing held by '
        'the first', () async {
      await store.incidents.upsertAll([_incident('inc_a', daysAgo: 3)]);
      phone.moveTo('acc_b');
      final down = InMemoryIncidentRepository(
        _Down(MockServer()),
        store: store,
      );

      final result = await down.getIncidents(limit: 200);

      expect(result.isSuccess(), isFalse);
    });
  });

  group('the screens', () {
    test('History shows nothing from the first account after a switch, and '
        'the rows again for that account', () async {
      await store.incidents.upsertAll([
        for (var day = 0; day < 4; day++) _incident('i$day', daysAgo: day),
      ]);
      SharedPreferences.setMockInitialValues({'device_id': 'dev_1'});
      final identity = DeviceIdentityStore(
        await SharedPreferences.getInstance(),
      );
      await identity.saveRegistration(
        deviceToken: 'dv_1',
        accountId: 'acc_a',
        tier: 'relay',
        caps: const AccountCaps(historyDays: 90),
      );
      final shared = IncidentsCubit(
        GetIncidentsUsecase(_Quiet()),
        identityChanges: phone.changes,
      );
      addTearDown(shared.close);
      final history = HistoryCubit(
        shared,
        now: () => _now,
        identityStore: identity,
        featureAccess: accessOver(identity).features,
        store: store,
      );
      addTearDown(history.close);

      await history.load();
      expect(history.state.entries, hasLength(4));

      phone.moveTo('acc_b');
      await history.load();
      expect(history.state.entries, isEmpty);
      expect(history.state.olderCount, 0);

      phone.moveTo('acc_a');
      await history.load();
      await _settle(() => history.state.entries.length == 4);
      expect(history.state.entries, hasLength(4));
    });

    // The cubits that acknowledge mark the shared list first, send the
    // request, and hand the answer back to the shared list, which stores it.
    // Both halves are driven here the way they do.
    Future<
      ({
        InMemoryIncidentRepository repository,
        IncidentsCubit shared,
        _Spy api,
      })
    >
    alarmedPhone() async {
      final api = _Spy(MockServer())..server.seedAlarmed();
      final repository = InMemoryIncidentRepository(api, store: store);
      final shared = IncidentsCubit(
        GetIncidentsUsecase(repository),
        saveIncident: repository.saveIncident,
        isLeftBehind: repository.isLeftBehind,
        identityChanges: phone.changes,
      );
      addTearDown(shared.close);
      await shared.refresh();
      expect(shared.state.incidents.map((i) => i.id), ['inc_alarmed_proddb']);
      return (repository: repository, shared: shared, api: api);
    }

    test('an acknowledge answered in time is stored and drawn', () async {
      final made = await alarmedPhone();
      made.shared.acknowledgeNow(made.shared.state.incidents.single);

      final result = await made.repository.ackIncident('inc_alarmed_proddb');
      made.shared.applyIncident(result.getOrNull()!);
      await pumpEventQueue();

      expect(made.shared.state.incidents.single.state, IncidentStates.acked);
      expect(
        (await store.incidents.page()).single.state,
        IncidentStates.acked,
      );
    });

    test('an acknowledge that answers after the account switched is neither '
        'stored nor drawn for the new account', () async {
      final made = await alarmedPhone();
      made.shared.acknowledgeNow(made.shared.state.incidents.single);
      made.api.ackGate = Completer<void>();
      final answering = made.repository.ackIncident('inc_alarmed_proddb');

      phone.moveTo('acc_b');
      made.api.listsNothing = true;
      await made.shared.refresh();
      expect(made.shared.state.incidents, isEmpty);

      made.api.ackGate!.complete();
      final result = await answering;
      // The cubit's own apply, as every acknowledge path makes it.
      made.shared.applyIncident(result.getOrNull()!);
      await pumpEventQueue();

      expect(made.shared.state.incidents, isEmpty);
      expect(await store.incidents.count(), 0);
      expect(await store.messages.count(), 0);
      // Nothing of it was kept for the account that asked either; its next
      // list read brings the acknowledged copy.
      phone.moveTo('acc_a');
      expect((await store.incidents.page()).single.state, isNot('acked'));
    });

    test('a lookup that answers after the switch is neither stored nor drawn '
        'for the new account', () async {
      final made = await alarmedPhone();
      made.api.lookupGate = Completer<void>();
      final late = made.repository.getIncident('inc_alarmed_proddb');
      phone.moveTo('acc_b');
      made.api.listsNothing = true;
      await made.shared.refresh();
      made.api.lookupGate!.complete();

      made.shared.applyIncidents([(await late).getOrNull()!]);
      await pumpEventQueue();
      expect(made.shared.state.incidents, isEmpty);
      expect(await store.incidents.count(), 0);
    });

    test('the shared incident list and a topic screen read nothing of the '
        'first account after a switch', () async {
      await store.incidents.upsertAll([_incident('inc_a', daysAgo: 1)]);
      await store.messages.upsertAll([
        const Message(id: 'm_a', topic: 'prod', time: 5),
      ]);
      final api = _Spy(MockServer());
      final repository = InMemoryIncidentRepository(api, store: store);
      final shared = IncidentsCubit(
        GetIncidentsUsecase(repository),
        identityChanges: phone.changes,
      );
      addTearDown(shared.close);

      await shared.refresh();
      expect(shared.state.incidents.map((i) => i.id), ['inc_a']);

      phone.moveTo('acc_b');
      await _settle(() => shared.state.incidents.isEmpty);
      expect(shared.state.incidents, isEmpty);
      expect(
        (await repository.pollMessages('prod', poll: 1)).getOrNull(),
        isEmpty,
      );
    });
  });
}

class _Down extends MockApiClient {
  _Down(super.server);

  @override
  Future<List<Incident>> getIncidents({
    required int limit,
    String? state,
    String? topic,
    DateTime? since,
  }) async => throw const ApiException(statusCode: 503, message: 'down');
}
