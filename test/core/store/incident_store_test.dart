import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DateTime _at(int daysAgo) =>
    DateTime.utc(2026, 9, 22, 12).subtract(Duration(days: daysAgo));

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
