import 'dart:io';

import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'stats report counts, oldest incident, newest sync, and last since',
    () async {
      final store = await LocalStore.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      addTearDown(store.close);
      final opened = DateTime.utc(2026, 9, 20, 12);
      await store.incidents.upsertAll([
        Incident(
          id: 'inc_1',
          topic: 'prod',
          openedAt: opened,
          lastMessageAt: opened,
          messages: [
            Message(
              id: 'msg_1',
              topic: 'prod',
              time: opened.millisecondsSinceEpoch ~/ 1000,
              incidentId: 'inc_1',
            ),
          ],
        ),
        Incident(
          id: 'inc_2',
          topic: 'prod',
          openedAt: opened.add(const Duration(days: 1)),
          lastMessageAt: opened,
        ),
      ]);
      final since = DateTime.utc(2026, 9, 22, 11);
      store.recordLastSince(since);

      final stats = await store.stats();
      expect(stats.incidentCount, 2);
      expect(stats.messageCount, 1);
      expect(stats.oldestIncidentAt, opened);
      expect(stats.lastSyncAt, isNotNull);
      expect(stats.lastSince, '${since.millisecondsSinceEpoch ~/ 1000}');
      expect(stats.databaseBytes, isNull);
    },
  );

  test('stats report positive file size for a file database', () async {
    final directory = await Directory.systemTemp.createTemp('critalarm-debug-');
    addTearDown(() => directory.delete(recursive: true));
    final store = await LocalStore.open(
      factory: databaseFactoryFfi,
      path: '${directory.path}/test.db',
    );
    addTearDown(store.close);

    final stats = await store.stats();
    expect(stats.databaseBytes, greaterThan(0));
  });
}
