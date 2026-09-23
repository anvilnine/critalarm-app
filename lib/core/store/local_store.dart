import 'dart:convert';
import 'dart:io';

import 'package:critalarm/core/alarm/alarm_debug_snapshot.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// The phone's own copy of every incident and message it has ever seen.
///
/// api.md §4.2: a hosted or relay server deletes rows older than the
/// account's `history_days` and stops returning them. That makes this file
/// the archive, not a cache: nothing here is dropped because a plan changed,
/// and only the user asking for auto-delete ever removes a row.
///
/// Times are stored as whole seconds since the epoch, the same unit the
/// contract uses on the wire.
class LocalStore {
  LocalStore(this.db)
    : incidents = IncidentStore(db),
      messages = MessageStore(db);

  /// Bumped whenever a table changes, with a matching step in [_upgrade].
  static const schemaVersion = 2;

  static const fileName = 'critalarm.db';

  final Database db;
  final IncidentStore incidents;
  final MessageStore messages;
  String? _lastSinceSent;

  /// Opens `critalarm.db` in the app documents directory.
  ///
  /// Pass [factory] and [path] to open somewhere else. A unit test hands in
  /// `databaseFactoryFfi` and `inMemoryDatabasePath`.
  static Future<LocalStore> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final resolved =
        path ??
        p.join((await getApplicationDocumentsDirectory()).path, fileName);
    final db = await (factory ?? databaseFactory).openDatabase(
      resolved,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) => _create(db),
        onUpgrade: _upgrade,
      ),
    );
    return LocalStore(db);
  }

  Future<void> close() => db.close();

  /// Remembers the incident cursor immediately before it is sent to the API.
  void recordLastSince(DateTime? since) {
    _lastSinceSent = since == null
        ? null
        : '${since.toUtc().millisecondsSinceEpoch ~/ 1000}';
  }

  /// Aggregate diagnostics only; never exposes the database or message text.
  Future<DebugStoreStats> stats() async {
    final incidentRows = await db.rawQuery('''
      SELECT COUNT(*) AS row_count, MIN(opened_at) AS oldest
      FROM incidents
    ''');
    final messageCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM messages'),
        ) ??
        0;
    final syncRows = await db.rawQuery('''
      SELECT MAX(synced_at) AS latest FROM (
        SELECT MAX(synced_at) AS synced_at FROM incidents
        UNION ALL
        SELECT MAX(synced_at) AS synced_at FROM messages
      )
    ''');
    final path = db.path;
    int? databaseBytes;
    if (path.isNotEmpty && path != inMemoryDatabasePath) {
      final file = File(path);
      if (file.existsSync()) databaseBytes = file.lengthSync();
    }
    final incidents = incidentRows.first;
    final count = (incidents['row_count'] as num?)?.toInt() ?? 0;
    return DebugStoreStats(
      incidentCount: count,
      messageCount: messageCount,
      oldestIncidentAt: _time(incidents['oldest']),
      databaseBytes: databaseBytes,
      lastSyncAt: _time(syncRows.first['latest']),
      lastSince: _lastSinceSent,
    );
  }

  static Future<void> _create(Database db) async {
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

  static Future<void> _upgrade(Database db, int from, int to) async {
    if (from < 2) {
      await db.execute('ALTER TABLE incidents ADD COLUMN updated_at INTEGER');
      await db.execute(
        'UPDATE incidents '
        'SET updated_at = COALESCE(closed_at, acked_at, opened_at)',
      );
    }
  }
}

/// Seconds since the epoch, the unit both tables store.
int? _epoch(DateTime? value) =>
    value == null ? null : value.toUtc().millisecondsSinceEpoch ~/ 1000;

DateTime? _time(Object? seconds) => seconds == null
    ? null
    : DateTime.fromMillisecondsSinceEpoch(
        (seconds as int) * 1000,
        isUtc: true,
      );

/// The highest priority any message on the incident carried.
///
/// Auto-delete needs it to tell a P5 alarm from the rest, and the incident
/// itself has no priority in the contract.
int incidentPriority(Incident incident) {
  var highest = 3;
  for (final message in incident.messages) {
    if (message.priority > highest) highest = message.priority;
  }
  return highest;
}

/// Incidents on the phone, newest first.
class IncidentStore {
  IncidentStore(this._db);

  final Database _db;

  /// Writes [incidents], replacing any row with the same id.
  ///
  /// Server ids are the primary key, so syncing the same incident twice
  /// leaves one row. Messages carried on an incident are written too.
  Future<void> upsertAll(Iterable<Incident> incidents) async {
    if (incidents.isEmpty) return;
    final syncedAt = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final batch = _db.batch();
    final messages = <Message>[];

    for (final incident in incidents) {
      final openedAt = _epoch(incident.openedAt ?? incident.lastMessageAt);
      batch.insert('incidents', {
        'id': incident.id,
        'topic': incident.topic,
        'state': incident.state,
        'opened_at': openedAt ?? syncedAt,
        'acked_at': _epoch(incident.ackedAt),
        'closed_at': _epoch(incident.closedAt),
        'updated_at': _epoch(incident.updatedAt),
        'last_message_at':
            _epoch(incident.lastMessageAt) ?? openedAt ?? syncedAt,
        'max_ring_s': null,
        'priority': incidentPriority(incident),
        'synced_at': syncedAt,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      messages.addAll(incident.messages);
    }

    await batch.commit(noResult: true);
    await MessageStore(_db).upsertAll(messages);
  }

  /// The newest `opened_at` held, or null when the store is empty.
  Future<DateTime?> newestOpenedAt() async {
    final rows = await _db.rawQuery(
      'SELECT MAX(opened_at) AS newest FROM incidents',
    );
    return _time(rows.first['newest']);
  }

  /// The newest `updated_at` held, or null when the store is empty.
  ///
  /// This is what goes on the wire as `since` (api.md §3.2), which is
  /// exclusive, so the server answers with what this phone has not seen.
  Future<DateTime?> newestUpdatedAt() async {
    final rows = await _db.rawQuery(
      'SELECT MAX(updated_at) AS newest FROM incidents',
    );
    return _time(rows.first['newest']);
  }

  /// One page, newest first, of the incidents at or after [window].
  ///
  /// A null [window] means everything on the phone, which is what every tier
  /// except free gets.
  Future<List<Incident>> page({
    DateTime? window,
    int limit = 50,
    int offset = 0,
    String? topic,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (window != null) {
      where.add('opened_at >= ?');
      args.add(_epoch(window));
    }
    if (topic != null) {
      where.add('topic = ?');
      args.add(topic);
    }

    final rows = await _db.query(
      'incidents',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'opened_at DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    if (rows.isEmpty) return const [];

    final byIncident = await MessageStore(_db).groupedByIncident(
      rows.map((r) => r['id']! as String),
    );
    return [
      for (final row in rows)
        _toIncident(row, byIncident[row['id']] ?? const <Message>[]),
    ];
  }

  /// How many incidents sit before [window]. Zero when [window] is null,
  /// because then nothing is hidden.
  Future<int> countOlderThan(DateTime? window) async {
    if (window == null) return 0;
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM incidents WHERE opened_at < ?',
      [_epoch(window)],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// Deletes incidents that opened before [cutoff], and their messages.
  ///
  /// Only the user asking for auto-delete calls this. A tier change never
  /// does. With [keepP5] on, an incident whose highest priority was 5 stays.
  /// An incident still `open` or `acked` stays whatever its age, the same
  /// rule the server prunes by (api.md §4.2).
  Future<int> deleteOlderThan(DateTime cutoff, {bool keepP5 = true}) async {
    final seconds = _epoch(cutoff);
    final where = StringBuffer(
      'opened_at < ? AND state NOT IN (?, ?)',
    );
    final args = <Object?>[
      seconds,
      IncidentStates.open,
      IncidentStates.acked,
    ];
    if (keepP5) where.write(' AND priority < 5');

    final doomed = await _db.query(
      'incidents',
      columns: const ['id'],
      where: where.toString(),
      whereArgs: args,
    );
    if (doomed.isEmpty) return 0;

    final ids = doomed.map((r) => r['id']! as String).toList();
    final holes = List.filled(ids.length, '?').join(',');
    await _db.delete(
      'messages',
      where: 'incident_id IN ($holes)',
      whereArgs: ids,
    );
    return _db.delete('incidents', where: 'id IN ($holes)', whereArgs: ids);
  }

  Future<int> count() async => Sqflite.firstIntValue(
    await _db.rawQuery('SELECT COUNT(*) FROM incidents'),
  )!;

  Incident _toIncident(Map<String, Object?> row, List<Message> messages) {
    return Incident(
      id: row['id']! as String,
      topic: row['topic']! as String,
      state: row['state']! as String,
      openedAt: _time(row['opened_at']),
      ackedAt: _time(row['acked_at']),
      closedAt: _time(row['closed_at']),
      updatedAt: _time(row['updated_at']),
      lastMessageAt: _time(row['last_message_at']),
      messages: messages,
    );
  }
}

/// Messages on the phone, newest first per topic.
class MessageStore {
  MessageStore(this._db);

  final Database _db;

  Future<void> upsertAll(Iterable<Message> messages) async {
    if (messages.isEmpty) return;
    final syncedAt = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final batch = _db.batch();
    for (final message in messages) {
      batch.insert('messages', {
        'id': message.id,
        'topic': message.topic,
        'incident_id': message.incidentId,
        'title': message.title,
        'body': message.message,
        'priority': message.priority,
        'tags': jsonEncode(message.tags),
        'click': message.click,
        'markdown': message.markdown ? 1 : 0,
        'created_at': message.time,
        'synced_at': syncedAt,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// The id of the newest message held on [topic], or null when there is
  /// none. This is the `since` the poll route takes (api.md §2).
  Future<String?> newestMessageId(String topic) async {
    final rows = await _db.query(
      'messages',
      columns: const ['id'],
      where: 'topic = ?',
      whereArgs: [topic],
      orderBy: 'created_at DESC, id DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['id'] as String?;
  }

  /// One page of [topic], newest first, at or after [window].
  Future<List<Message>> page({
    required String topic,
    DateTime? window,
    int limit = 50,
    int offset = 0,
  }) async {
    final where = StringBuffer('topic = ?');
    final args = <Object?>[topic];
    if (window != null) {
      where.write(' AND created_at >= ?');
      args.add(_epoch(window));
    }
    final rows = await _db.query(
      'messages',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(_toMessage).toList();
  }

  /// How many messages on [topic] sit before [window].
  Future<int> countOlderThan(DateTime? window, {String? topic}) async {
    if (window == null) return 0;
    final where = StringBuffer('created_at < ?');
    final args = <Object?>[_epoch(window)];
    if (topic != null) {
      where.write(' AND topic = ?');
      args.add(topic);
    }
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM messages WHERE $where',
      args,
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// Deletes messages created before [cutoff] that belong to no incident.
  /// Messages on an incident go when the incident goes.
  Future<int> deleteOlderThan(DateTime cutoff, {bool keepP5 = true}) async {
    final where = StringBuffer('created_at < ? AND incident_id IS NULL');
    if (keepP5) where.write(' AND priority < 5');
    return _db.delete(
      'messages',
      where: where.toString(),
      whereArgs: [_epoch(cutoff)],
    );
  }

  Future<Map<String, List<Message>>> groupedByIncident(
    Iterable<String> incidentIds,
  ) async {
    final ids = incidentIds.toList();
    if (ids.isEmpty) return const {};
    final holes = List.filled(ids.length, '?').join(',');
    final rows = await _db.query(
      'messages',
      where: 'incident_id IN ($holes)',
      whereArgs: ids,
      orderBy: 'created_at ASC, id ASC',
    );
    final grouped = <String, List<Message>>{};
    for (final row in rows) {
      final key = row['incident_id']! as String;
      (grouped[key] ??= <Message>[]).add(_toMessage(row));
    }
    return grouped;
  }

  Future<int> count() async => Sqflite.firstIntValue(
    await _db.rawQuery('SELECT COUNT(*) FROM messages'),
  )!;

  Message _toMessage(Map<String, Object?> row) {
    final tags = row['tags'] as String?;
    return Message(
      id: row['id']! as String,
      topic: row['topic']! as String,
      time: row['created_at']! as int,
      title: row['title'] as String?,
      message: (row['body'] as String?) ?? '',
      priority: row['priority']! as int,
      tags: tags == null
          ? const []
          : (jsonDecode(tags) as List<dynamic>).cast<String>(),
      click: row['click'] as String?,
      markdown: (row['markdown']! as int) == 1,
      incidentId: row['incident_id'] as String?,
    );
  }
}
