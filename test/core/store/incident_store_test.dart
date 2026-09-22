import 'dart:io';

import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DateTime _at(int daysAgo) =>
    DateTime.utc(2026, 9, 22, 12).subtract(Duration(days: daysAgo));

int _secs(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

/// The incidents and messages tables as version 1 laid them out, so a test can
/// build a database that predates `updated_at`.
Future<void> _createV1(Database db, int version) async {
  final batch = db.batch()
    ..execute('''
      CREATE TABLE incidents (
        id TEXT PRIMARY KEY, topic TEXT NOT NULL, state TEXT NOT NULL,
        opened_at INTEGER NOT NULL, acked_at INTEGER, closed_at INTEGER,
        last_message_at INTEGER NOT NULL, max_ring_s INTEGER,
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
    ''');
  await batch.commit(noResult: true);
}

Incident _incident(
  String id, {
  required int daysAgo,
  String topic = 'prod',
  String state = IncidentStates.closed,
  int priority = 4,
}) {
  final openedAt = _at(daysAgo);
  return Incident(
    id: id,
    topic: topic,
    state: state,
    openedAt: openedAt,
    updatedAt: openedAt,
    lastMessageAt: openedAt,
    messages: [
      Message(
        id: 'msg_$id',
        topic: topic,
        time: openedAt.millisecondsSinceEpoch ~/ 1000,
        priority: priority,
        message: 'disk full',
        tags: const ['warning'],
        incidentId: id,
      ),
    ],
  );
}

void main() {
  sqfliteFfiInit();

  late LocalStore store;

  setUp(() async {
    store = await LocalStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
  });

  tearDown(() async => store.close());

  test('upserting the same incident twice leaves one row', () async {
    await store.incidents.upsertAll([_incident('inc_1', daysAgo: 1)]);
    await store.incidents.upsertAll([
      _incident('inc_1', daysAgo: 1, state: IncidentStates.expired),
    ]);

    expect(await store.incidents.count(), 1);
    final page = await store.incidents.page();
    expect(page.single.state, IncidentStates.expired);
    expect(page.single.messages.single.message, 'disk full');
    expect(page.single.messages.single.tags, ['warning']);
    expect(await store.messages.count(), 1);
  });

  test('newestOpenedAt returns the newest row, null when empty', () async {
    expect(await store.incidents.newestOpenedAt(), isNull);

    await store.incidents.upsertAll([
      _incident('inc_old', daysAgo: 9),
      _incident('inc_new', daysAgo: 2),
    ]);

    expect(await store.incidents.newestOpenedAt(), _at(2));
  });

  test(
    'newestUpdatedAt returns the newest updated row, null when empty',
    () async {
      expect(await store.incidents.newestUpdatedAt(), isNull);

      await store.incidents.upsertAll([
        _incident('inc_old', daysAgo: 9),
        _incident('inc_new', daysAgo: 2),
      ]);

      expect(await store.incidents.newestUpdatedAt(), _at(2));
    },
  );

  test('upgrade from version 1 keeps rows and backfills updated_at', () async {
    final dir = await Directory.systemTemp.createTemp('critalarm_store');
    addTearDown(() => dir.delete(recursive: true));
    final path = p.join(dir.path, 'critalarm.db');

    // A version 1 database with one closed incident and no updated_at column.
    final v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 1, onCreate: _createV1),
    );
    await v1.insert('incidents', {
      'id': 'inc_1',
      'topic': 'prod',
      'state': IncidentStates.closed,
      'opened_at': _secs(_at(5)),
      'acked_at': _secs(_at(3)),
      'closed_at': _secs(_at(1)),
      'last_message_at': _secs(_at(5)),
      'max_ring_s': null,
      'priority': 4,
      'synced_at': _secs(_at(0)),
    });
    await v1.close();

    // Opening at the current version runs the upgrade in place.
    final upgraded = await LocalStore.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    addTearDown(upgraded.close);

    final row = (await upgraded.incidents.page()).single;
    expect(row.id, 'inc_1');
    // COALESCE takes closed_at, the newest of the three held.
    expect(row.updatedAt, _at(1));
  });

  test('page returns newest first and honours offset', () async {
    await store.incidents.upsertAll([
      for (var day = 1; day <= 5; day++) _incident('inc_$day', daysAgo: day),
    ]);

    final first = await store.incidents.page(limit: 2);
    expect(first.map((i) => i.id), ['inc_1', 'inc_2']);

    final second = await store.incidents.page(limit: 2, offset: 2);
    expect(second.map((i) => i.id), ['inc_3', 'inc_4']);
  });

  test('page with a window drops rows before it', () async {
    await store.incidents.upsertAll([
      _incident('inc_recent', daysAgo: 3),
      _incident('inc_old', daysAgo: 30),
    ]);

    final inside = await store.incidents.page(window: _at(7));
    expect(inside.map((i) => i.id), ['inc_recent']);

    final everything = await store.incidents.page();
    expect(everything.map((i) => i.id), ['inc_recent', 'inc_old']);
  });

  test('countOlderThan counts what the window hides', () async {
    await store.incidents.upsertAll([
      _incident('inc_recent', daysAgo: 3),
      _incident('inc_old', daysAgo: 30),
      _incident('inc_older', daysAgo: 60),
    ]);

    expect(await store.incidents.countOlderThan(_at(7)), 2);
    expect(await store.incidents.countOlderThan(null), 0);
  });

  test('deleteOlderThan skips P5 rows when asked', () async {
    await store.incidents.upsertAll([
      _incident('inc_p4', daysAgo: 40),
      _incident('inc_p5', daysAgo: 40, priority: 5),
      _incident('inc_new', daysAgo: 2),
    ]);

    final removed = await store.incidents.deleteOlderThan(_at(30));

    expect(removed, 1);
    final left = await store.incidents.page();
    expect(left.map((i) => i.id), ['inc_new', 'inc_p5']);
    // The P4 incident took its message with it.
    expect(await store.messages.count(), 2);
  });

  test('deleteOlderThan removes P5 rows when the switch is off', () async {
    await store.incidents.upsertAll([
      _incident('inc_p5', daysAgo: 40, priority: 5),
    ]);

    expect(
      await store.incidents.deleteOlderThan(_at(30), keepP5: false),
      1,
    );
    expect(await store.incidents.count(), 0);
    expect(await store.messages.count(), 0);
  });

  test('deleteOlderThan never removes an open or acked incident', () async {
    await store.incidents.upsertAll([
      _incident('inc_open', daysAgo: 90, state: IncidentStates.open),
      _incident('inc_acked', daysAgo: 90, state: IncidentStates.acked),
    ]);

    expect(
      await store.incidents.deleteOlderThan(_at(30), keepP5: false),
      0,
    );
    expect(await store.incidents.count(), 2);
  });

  group('MessageStore', () {
    test('newestMessageId is per topic', () async {
      await store.messages.upsertAll([
        const Message(id: 'm1', topic: 'prod', time: 100),
        const Message(id: 'm2', topic: 'prod', time: 300),
        const Message(id: 'm3', topic: 'staging', time: 200),
      ]);

      expect(await store.messages.newestMessageId('prod'), 'm2');
      expect(await store.messages.newestMessageId('staging'), 'm3');
      expect(await store.messages.newestMessageId('nothing'), isNull);
    });

    test('page is newest first, windowed, and pages', () async {
      await store.messages.upsertAll([
        for (var day = 1; day <= 4; day++)
          Message(
            id: 'm$day',
            topic: 'prod',
            time: _at(day).millisecondsSinceEpoch ~/ 1000,
          ),
      ]);

      final first = await store.messages.page(topic: 'prod', limit: 2);
      expect(first.map((m) => m.id), ['m1', 'm2']);

      final windowed = await store.messages.page(
        topic: 'prod',
        window: _at(2),
      );
      expect(windowed.map((m) => m.id), ['m1', 'm2']);
    });

    test('upserting the same message twice leaves one row', () async {
      const message = Message(id: 'm1', topic: 'prod', time: 100);
      await store.messages.upsertAll([message]);
      await store.messages.upsertAll([
        message.copyWith(message: 'changed'),
      ]);

      expect(await store.messages.count(), 1);
      final page = await store.messages.page(topic: 'prod');
      expect(page.single.message, 'changed');
    });
  });
}
