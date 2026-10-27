import 'dart:io';

import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/store/held_scope.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show Sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The incidents and messages tables as version 2 laid them out: `updated_at`
/// is there and the `topics` table is not.
Future<void> _createV2(Database db, int version) async {
  final batch = db.batch()
    ..execute('''
      CREATE TABLE incidents (
        id TEXT PRIMARY KEY, topic TEXT NOT NULL, state TEXT NOT NULL,
        opened_at INTEGER NOT NULL, acked_at INTEGER, closed_at INTEGER,
        updated_at INTEGER, last_message_at INTEGER NOT NULL, max_ring_s INTEGER,
        priority INTEGER NOT NULL, synced_at INTEGER NOT NULL
      )
    ''')
    ..execute('CREATE INDEX incidents_opened ON incidents(opened_at DESC)')
    ..execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY, topic TEXT NOT NULL, incident_id TEXT,
        title TEXT, body TEXT, priority INTEGER NOT NULL, tags TEXT,
        click TEXT, markdown INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL, synced_at INTEGER NOT NULL
      )
    ''')
    ..execute(
      'CREATE INDEX messages_topic_created '
      'ON messages(topic, created_at DESC)',
    );
  await batch.commit(noResult: true);
}

final String _scope = heldScopeFor(
  serverUrl: 'https://api.example',
  accountId: 'a1',
)!;
final String _otherAccount = heldScopeFor(
  serverUrl: 'https://api.example',
  accountId: 'a2',
)!;
final String _otherServer = heldScopeFor(
  serverUrl: 'https://other.example',
  accountId: 'a1',
)!;

/// Every field the list route returns, none of them at its default, and the
/// three a created topic carries on top.
final _full = Topic(
  name: 'prod-db',
  critical: true,
  repeatIntervalS: 45,
  maxRingS: 900,
  deskTimerS: 300,
  relayContent: 'title',
  createdAt: DateTime.utc(2026, 9, 1, 8, 30, 15, 250),
  token: 'tk_secret',
  tokenId: 'tok_1',
  tokenName: 'CI server',
);

void main() {
  sqfliteFfiInit();

  group('upgrade to version 3', () {
    test(
      'keeps every incident and message and adds the topics table',
      () async {
        final dir = await Directory.systemTemp.createTemp('critalarm_store');
        addTearDown(() => dir.delete(recursive: true));
        final path = p.join(dir.path, 'critalarm.db');

        final v2 = await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(version: 2, onCreate: _createV2),
        );
        await v2.insert('incidents', {
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
        await v2.insert('messages', {
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
        await v2.insert('messages', {
          'id': 'msg_2',
          'topic': 'prod',
          'incident_id': null,
          'title': null,
          'body': 'loose',
          'priority': 3,
          'tags': null,
          'click': null,
          'markdown': 1,
          'created_at': 2000,
          'synced_at': 2100,
        });
        await v2.close();

        final upgraded = await LocalStore.open(
          factory: databaseFactoryFfi,
          path: path,
        );
        addTearDown(upgraded.close);

        expect(LocalStore.schemaVersion, 4);
        expect(
          Sqflite.firstIntValue(
            await upgraded.db.rawQuery('PRAGMA user_version'),
          ),
          4,
        );

        // The old rows are untouched.
        final incident = (await upgraded.incidents.page()).single;
        expect(incident.id, 'inc_1');
        expect(incident.state, IncidentStates.closed);
        expect(
          incident.updatedAt,
          DateTime.fromMillisecondsSinceEpoch(1300 * 1000, isUtc: true),
        );
        expect(incident.messages.single.message, 'disk full');
        expect(incident.messages.single.tags, ['warning']);
        expect(await upgraded.messages.count(), 2);
        expect(
          (await upgraded.messages.page(topic: 'prod')).map((m) => m.id),
          ['msg_2', 'msg_1'],
        );

        // The new table is there, empty, and works.
        expect(await upgraded.topics.count(), 0);
        expect(await upgraded.topics.read(_scope), isNull);
        await upgraded.topics.replaceAll(_scope, [_full]);
        expect((await upgraded.topics.read(_scope))!.single.name, 'prod-db');
        expect(await upgraded.incidents.count(), 1);
      },
    );

    test('a database from version 1 passes both steps', () async {
      final dir = await Directory.systemTemp.createTemp('critalarm_store');
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
      );
      addTearDown(upgraded.close);

      expect(await upgraded.incidents.count(), 1);
      expect(await upgraded.topics.count(), 0);
    });

    test('a fresh install has the topics table', () async {
      final store = await LocalStore.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      addTearDown(store.close);

      expect(await store.topics.count(), 0);
    });
  });

  group('the held topic list', () {
    late LocalStore store;

    setUp(() async {
      store = await LocalStore.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
    });

    tearDown(() async => store.close());

    test('round trips every field the list route returns', () async {
      await store.topics.replaceAll(_scope, [_full]);

      final back = (await store.topics.read(_scope))!.single;
      expect(back.name, 'prod-db');
      expect(back.critical, isTrue);
      expect(back.repeatIntervalS, 45);
      expect(back.maxRingS, 900);
      expect(back.deskTimerS, 300);
      expect(back.relayContent, 'title');
      // Milliseconds survive: the Topic screen matches what it remembered
      // about a topic by this exact time.
      expect(back.createdAt, DateTime.utc(2026, 9, 1, 8, 30, 15, 250));
      expect(back.createdAt!.isUtc, isTrue);
    });

    test('round trips a topic at its defaults with no created time', () async {
      await store.topics.replaceAll(_scope, [const Topic(name: 'calm')]);

      final back = (await store.topics.read(_scope))!.single;
      expect(back, const Topic(name: 'calm'));
      expect(back.critical, isFalse);
      expect(back.createdAt, isNull);
    });

    test('never keeps a token, its id or its name', () async {
      await store.topics.replaceAll(_scope, [_full]);

      final back = (await store.topics.read(_scope))!.single;
      expect(back.token, isNull);
      expect(back.tokenId, isNull);
      expect(back.tokenName, isNull);

      // And not as a column either.
      final columns = (await store.db.rawQuery(
        'PRAGMA table_info(topics)',
      )).map((row) => row['name']! as String).toSet();
      expect(columns, isNot(contains('token')));
      expect(columns.where((c) => c.contains('token')), isEmpty);
      final rows = await store.db.query('topics');
      expect(rows.toString(), isNot(contains('tk_secret')));
      expect(rows.toString(), isNot(contains('tok_1')));
      expect(rows.toString(), isNot(contains('CI server')));
    });

    test('keeps the order the server gave', () async {
      await store.topics.replaceAll(_scope, [
        const Topic(name: 'zeta'),
        const Topic(name: 'alpha'),
        const Topic(name: 'mid'),
      ]);

      expect((await store.topics.read(_scope))!.map((t) => t.name), [
        'zeta',
        'alpha',
        'mid',
      ]);
    });

    test('a new list replaces the old one, so a deleted topic goes', () async {
      await store.topics.replaceAll(_scope, [
        const Topic(name: 'a'),
        const Topic(name: 'b'),
      ]);
      await store.topics.replaceAll(_scope, [
        const Topic(name: 'b', critical: true),
      ]);

      final back = (await store.topics.read(_scope))!;
      expect(back.map((t) => t.name), ['b']);
      expect(back.single.critical, isTrue);
      expect(await store.topics.count(), 1);
    });

    test('an empty list is nothing held', () async {
      await store.topics.replaceAll(_scope, [const Topic(name: 'a')]);
      await store.topics.replaceAll(_scope, const []);

      expect(await store.topics.read(_scope), isNull);
      expect(await store.topics.count(), 0);
    });

    test('a list is handed back to its own scope only', () async {
      await store.topics.replaceAll(_scope, [const Topic(name: 'mine')]);

      expect(await store.topics.read(_otherAccount), isNull);
      expect(await store.topics.read(_otherServer), isNull);
    });

    test('reading for another scope deletes what was held', () async {
      await store.topics.replaceAll(_scope, [const Topic(name: 'mine')]);

      expect(await store.topics.read(_otherAccount), isNull);

      expect(await store.topics.count(), 0);
      expect(await store.topics.read(_scope), isNull);
    });

    test("writing for a new scope drops the old scope's rows", () async {
      await store.topics.replaceAll(_scope, [const Topic(name: 'old')]);
      await store.topics.replaceAll(_otherAccount, [const Topic(name: 'new')]);

      expect(await store.topics.count(), 1);
      expect(
        (await store.topics.read(_otherAccount))!.map((t) => t.name),
        ['new'],
      );
      expect(await store.topics.read(_scope), isNull);
    });

    test('clear empties the table', () async {
      await store.topics.replaceAll(_scope, [const Topic(name: 'a')]);

      await store.topics.clear();

      expect(await store.topics.read(_scope), isNull);
    });

    test('clearServerData drops the topics with the archive', () async {
      await store.topics.replaceAll(_scope, [const Topic(name: 'a')]);
      await store.messages.upsertAll([
        const Message(id: 'm1', topic: 'a', time: 1),
      ]);

      await store.clearServerData();

      expect(await store.topics.count(), 0);
      expect(await store.messages.count(), 0);
    });

    test('a topic list write leaves incidents and messages alone', () async {
      await store.messages.upsertAll([
        const Message(id: 'm1', topic: 'a', time: 1),
      ]);

      await store.topics.replaceAll(_scope, [const Topic(name: 'a')]);
      await store.topics.clear();

      expect(await store.messages.count(), 1);
    });
  });

  group('heldScopeFor', () {
    test('differs by server and by account', () {
      expect(_scope, isNot(_otherAccount));
      expect(_scope, isNot(_otherServer));
    });

    test('ignores case and a trailing slash in the address', () {
      expect(
        heldScopeFor(serverUrl: 'HTTPS://API.EXAMPLE/', accountId: 'a1'),
        _scope,
      );
    });

    test(
      'is null with no server, and a self-hosted server needs no account',
      () {
        expect(heldScopeFor(serverUrl: null, accountId: 'a1'), isNull);
        expect(heldScopeFor(serverUrl: '  ', accountId: 'a1'), isNull);
        expect(
          heldScopeFor(serverUrl: 'https://own.example', accountId: null),
          isNotNull,
        );
      },
    );

    test('does not contain the address or the account id', () {
      final scope = heldScopeFor(
        serverUrl: 'https://api.example',
        accountId: 'acc_nine',
      )!;
      expect(scope, isNot(contains('example')));
      expect(scope, isNot(contains('acc_nine')));
      expect(scope, hasLength(16));
    });
  });
}
