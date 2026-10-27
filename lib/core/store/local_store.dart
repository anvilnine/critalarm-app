import 'dart:convert';
import 'dart:io';

import 'package:critalarm/core/alarm/alarm_debug_snapshot.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/store/archive_scope.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// The phone's own copy of every incident and message it has ever seen, and
/// the last topic list the server gave.
///
/// api.md §4.2: a hosted or relay server deletes rows older than the
/// account's `history_days` and stops returning them. That makes this file
/// the archive, not a cache: nothing here is dropped because a plan changed,
/// and only the user asking for auto-delete ever removes a row.
///
/// The topic list is the exception. It is a copy the server replaces on
/// every answer, kept so the app opens with the topics it already knows.
///
/// Incidents and messages carry the scope of the account they were read for
/// ([ArchiveScope]). Every read returns the current scope's rows only, so a
/// phone that signs out and signs in as somebody else never shows the first
/// account's history. Signing out keeps the rows. Deleting the account removes
/// them ([deleteArchiveOf]).
///
/// Times are stored as whole seconds since the epoch, the same unit the
/// contract uses on the wire.
class LocalStore {
  /// [scope] names the account the archive is read and written for. Leave it
  /// out only where one account is all there is (a unit test, a capture):
  /// every row then shares one scope.
  LocalStore(
    Database db, {
    Future<String?> Function()? scope,
  }) : this._(db, ArchiveScope(current: scope));

  LocalStore._(this.db, this._scope)
    : incidents = IncidentStore(db, _scope),
      messages = MessageStore(db, _scope),
      topics = TopicStore(db);

  /// Bumped whenever a table changes, with a matching step in [_upgrade].
  static const schemaVersion = 4;

  static const fileName = 'critalarm.db';

  final Database db;
  final ArchiveScope _scope;
  final IncidentStore incidents;
  final MessageStore messages;
  final TopicStore topics;
  String? _lastSinceSent;

  /// Opens `critalarm.db` in the app documents directory.
  ///
  /// Pass [factory] and [path] to open somewhere else. A unit test hands in
  /// `databaseFactoryFfi` and `inMemoryDatabasePath`.
  ///
  /// [scope] names the account the phone is on now (`heldScopeFor`). A file
  /// from before rows were scoped is upgraded by giving every row that
  /// scope, so nobody loses history on update. It is read once, during that
  /// upgrade, and must not touch this database.
  static Future<LocalStore> open({
    DatabaseFactory? factory,
    String? path,
    Future<String?> Function()? scope,
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
        onUpgrade: (db, from, to) async {
          String? legacy;
          if (from < 4) {
            try {
              legacy = scope == null ? ArchiveScope.single : await scope();
            } on Object catch (_) {}
          }
          await _upgrade(db, from, to, legacy);
        },
      ),
    );
    return LocalStore(db, scope: scope);
  }

  Future<void> close() => db.close();

  /// Remembers the incident cursor immediately before it is sent to the API.
  void recordLastSince(DateTime? since) {
    _lastSinceSent = since == null
        ? null
        : '${since.toUtc().millisecondsSinceEpoch ~/ 1000}';
  }

  /// Deletes every incident, message and held topic of every scope, and
  /// forgets the `since` cursor.
  ///
  /// For a phone that connects to a different server: what is held belongs
  /// to the old one, and the incident cursor is the newest timestamp the old
  /// one gave. Nothing else on the phone is touched.
  Future<void> clearServerData() async {
    _scope.invalidate();
    await db.transaction((txn) async {
      await txn.delete('messages');
      await txn.delete('incidents');
      await txn.delete('topics');
    });
    _lastSinceSent = null;
  }

  /// Deletes the incidents and messages kept for [scope] and nothing else.
  ///
  /// For an account delete: the account is gone, so the copy of its history
  /// goes with it. A sign-out does not call this, because the same account
  /// can sign in again.
  Future<void> deleteArchiveOf(String scope) async {
    _scope.invalidate();
    await db.transaction((txn) async {
      await txn.delete('messages', where: 'scope = ?', whereArgs: [scope]);
      await txn.delete('incidents', where: 'scope = ?', whereArgs: [scope]);
    });
  }

  /// Moves the incidents and messages kept for [from] to [into].
  ///
  /// For a merge: the phone's account was folded into another, so its history
  /// belongs there now and nothing reads [from] again. A row that [into]
  /// already holds under the same id stays as it is, and the copy under
  /// [from] is dropped.
  Future<void> mergeArchive({
    required String from,
    required String into,
  }) async {
    if (from == into) return;
    _scope.invalidate();
    await db.transaction((txn) async {
      for (final table in const ['incidents', 'messages']) {
        await txn.rawUpdate(
          'UPDATE OR IGNORE $table SET scope = ? WHERE scope = ?',
          [into, from],
        );
        await txn.delete(table, where: 'scope = ?', whereArgs: [from]);
      }
    });
  }

  /// Deletes the incidents and messages of the account the phone is on now.
  /// A phone on no scope has nothing of its own to delete.
  Future<void> deleteCurrentArchive() async {
    final scope = await _scope.current();
    if (scope != null) await deleteArchiveOf(scope);
  }

  /// Aggregate diagnostics only; never exposes the database or message text.
  /// It counts the current scope, like every other read.
  Future<DebugStoreStats> stats() async {
    final scope = await _scope.current() ?? '';
    final incidentRows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS row_count, MIN(opened_at) AS oldest
      FROM incidents WHERE scope = ?
    ''',
      [scope],
    );
    final messageCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM messages WHERE scope = ?',
            [scope],
          ),
        ) ??
        0;
    final syncRows = await db.rawQuery(
      '''
      SELECT MAX(synced_at) AS latest FROM (
        SELECT MAX(synced_at) AS synced_at FROM incidents WHERE scope = ?
        UNION ALL
        SELECT MAX(synced_at) AS synced_at FROM messages WHERE scope = ?
      )
    ''',
      [scope, scope],
    );
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
    await _createIncidents(db);
    await _createMessages(db);
    await _createTopics(db);
  }

  static Future<void> _createIncidents(Database db) async {
    await db.execute('''
      CREATE TABLE incidents (
        scope TEXT NOT NULL,
        id TEXT NOT NULL, topic TEXT NOT NULL, state TEXT NOT NULL,
        opened_at INTEGER NOT NULL, acked_at INTEGER, closed_at INTEGER,
        updated_at INTEGER, last_message_at INTEGER NOT NULL, max_ring_s INTEGER,
        priority INTEGER NOT NULL, synced_at INTEGER NOT NULL,
        PRIMARY KEY (scope, id)
      )
    ''');
    await db.execute(
      'CREATE INDEX incidents_opened ON incidents(scope, opened_at DESC)',
    );
  }

  static Future<void> _createMessages(Database db) async {
    await db.execute('''
      CREATE TABLE messages (
        scope TEXT NOT NULL,
        id TEXT NOT NULL, topic TEXT NOT NULL, incident_id TEXT,
        title TEXT, body TEXT, priority INTEGER NOT NULL, tags TEXT,
        click TEXT, markdown INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL, synced_at INTEGER NOT NULL,
        PRIMARY KEY (scope, id)
      )
    ''');
    await db.execute(
      'CREATE INDEX messages_topic_created '
      'ON messages(scope, topic, created_at DESC)',
    );
  }

  static Future<void> _createTopics(Database db) => db.execute('''
    CREATE TABLE topics (
      scope TEXT NOT NULL, position INTEGER NOT NULL, name TEXT NOT NULL,
      critical INTEGER NOT NULL DEFAULT 0, repeat_interval_s INTEGER NOT NULL,
      max_ring_s INTEGER NOT NULL, desk_timer_s INTEGER NOT NULL,
      relay_content TEXT NOT NULL, created_at_ms INTEGER,
      synced_at INTEGER NOT NULL,
      PRIMARY KEY (scope, name)
    )
  ''');

  static Future<void> _upgrade(
    Database db,
    int from,
    int to,
    String? legacyScope,
  ) async {
    if (from < 2) {
      await db.execute('ALTER TABLE incidents ADD COLUMN updated_at INTEGER');
      await db.execute(
        'UPDATE incidents '
        'SET updated_at = COALESCE(closed_at, acked_at, opened_at)',
      );
    }
    if (from < 3) await _createTopics(db);
    if (from < 4) await _scopeArchive(db, legacyScope);
  }

  /// Gives every incident and message already on the phone to [scope], the
  /// account it is on at the upgrade. The primary key becomes the scope and
  /// the id, which SQLite can only do by building the table again.
  ///
  /// A phone with no saved server at the upgrade has no account to give the
  /// rows to. They keep the empty scope, which no read ever asks for.
  ///
  /// Tables that already have the column are left alone. A file that was taken
  /// back to an older version and upgraded again keeps the scopes it has.
  static Future<void> _scopeArchive(Database db, String? scope) async {
    final columns = await db.rawQuery('PRAGMA table_info(incidents)');
    if (columns.any((column) => column['name'] == 'scope')) return;
    final stamp = scope ?? '';
    await db.execute('DROP INDEX IF EXISTS incidents_opened');
    await db.execute('DROP INDEX IF EXISTS messages_topic_created');
    await db.execute('ALTER TABLE incidents RENAME TO incidents_before_scope');
    await db.execute('ALTER TABLE messages RENAME TO messages_before_scope');
    await _createIncidents(db);
    await _createMessages(db);
    await db.execute(
      '''
      INSERT INTO incidents (
        scope, id, topic, state, opened_at, acked_at, closed_at, updated_at,
        last_message_at, max_ring_s, priority, synced_at
      )
      SELECT ?, id, topic, state, opened_at, acked_at, closed_at, updated_at,
        last_message_at, max_ring_s, priority, synced_at
      FROM incidents_before_scope
    ''',
      [stamp],
    );
    await db.execute(
      '''
      INSERT INTO messages (
        scope, id, topic, incident_id, title, body, priority, tags, click,
        markdown, created_at, synced_at
      )
      SELECT ?, id, topic, incident_id, title, body, priority, tags, click,
        markdown, created_at, synced_at
      FROM messages_before_scope
    ''',
      [stamp],
    );
    await db.execute('DROP TABLE incidents_before_scope');
    await db.execute('DROP TABLE messages_before_scope');
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
///
/// Every read is for the current scope ([ArchiveScope]) and every write is
/// stored under the scope it was started for. A write names the moment it
/// started with an [ArchiveTicket] ([beginWrite]); one that landed after the
/// account changed is not stored.
class IncidentStore {
  IncidentStore(this._db, this._scope);

  final Database _db;
  final ArchiveScope _scope;

  /// Starts a write. Take it before the request the data comes from.
  ArchiveTicket beginWrite() => _scope.begin();

  /// Writes [incidents], replacing any row with the same id in the same
  /// scope.
  ///
  /// Server ids are the key within a scope, so syncing the same incident twice
  /// leaves one row. Messages carried on an incident are written too.
  ///
  /// [ticket] is the write's claim from before its request went out. Without
  /// one the write claims the account it is called under.
  Future<void> upsertAll(
    Iterable<Incident> incidents, {
    ArchiveTicket? ticket,
  }) async {
    if (incidents.isEmpty) return;
    final claim = ticket ?? _scope.begin();
    final scope = await claim.settle();
    if (scope == null) return;
    final syncedAt = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

    // The check and the inserts share one transaction, so a delete of this
    // scope that follows the check waits for the inserts and removes them.
    await _db.transaction((txn) async {
      if (!claim.holds) return;
      final batch = txn.batch();
      final messages = <Message>[];
      for (final incident in incidents) {
        final openedAt = _epoch(incident.openedAt ?? incident.lastMessageAt);
        batch.insert('incidents', {
          'scope': scope,
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
      MessageStore._add(batch, scope, messages, syncedAt);
      await batch.commit(noResult: true);
    });
  }

  /// The newest `opened_at` held, or null when the store is empty.
  Future<DateTime?> newestOpenedAt() async {
    final scope = await _scope.current();
    if (scope == null) return null;
    final rows = await _db.rawQuery(
      'SELECT MAX(opened_at) AS newest FROM incidents WHERE scope = ?',
      [scope],
    );
    return _time(rows.first['newest']);
  }

  /// The oldest `opened_at` held, or null when the store is empty.
  Future<DateTime?> oldestOpenedAt() async {
    final scope = await _scope.current();
    if (scope == null) return null;
    final rows = await _db.rawQuery(
      'SELECT MIN(opened_at) AS oldest FROM incidents WHERE scope = ?',
      [scope],
    );
    return _time(rows.first['oldest']);
  }

  /// Every incident that opened at or after [since], newest first, with
  /// only what a count needs. Times are UTC, as the store holds them.
  Future<List<({String id, DateTime openedAt, bool isAcked})>> openedSince(
    DateTime since,
  ) async {
    final scope = await _scope.current();
    if (scope == null) return const [];
    final rows = await _db.query(
      'incidents',
      columns: const ['id', 'opened_at', 'acked_at'],
      where: 'scope = ? AND opened_at >= ?',
      whereArgs: [scope, _epoch(since)],
      orderBy: 'opened_at DESC, id DESC',
    );
    return [
      for (final row in rows)
        (
          id: row['id']! as String,
          openedAt: _time(row['opened_at'])!,
          isAcked: row['acked_at'] != null,
        ),
    ];
  }

  /// The incidents that opened at or after [from], newest first, as a topic
  /// and a time, at most [limit]. Times are UTC. For the history picture on
  /// a paywall.
  Future<List<({String topic, DateTime openedAt})>> newestSince(
    DateTime from, {
    int limit = 200,
  }) => _topicRows('opened_at >= ?', from, limit);

  /// The incidents that opened before [before], newest first, as a topic
  /// and a time, at most [limit]. The same table as [newestSince].
  Future<List<({String topic, DateTime openedAt})>> newestBefore(
    DateTime before, {
    int limit = 200,
  }) => _topicRows('opened_at < ?', before, limit);

  Future<List<({String topic, DateTime openedAt})>> _topicRows(
    String where,
    DateTime at,
    int limit,
  ) async {
    final scope = await _scope.current();
    if (scope == null) return const [];
    final rows = await _db.query(
      'incidents',
      columns: const ['topic', 'opened_at'],
      where: 'scope = ? AND $where',
      whereArgs: [scope, _epoch(at)],
      orderBy: 'opened_at DESC, id DESC',
      limit: limit,
    );
    return [
      for (final row in rows)
        (topic: row['topic']! as String, openedAt: _time(row['opened_at'])!),
    ];
  }

  /// The newest `updated_at` held, or null when the store is empty.
  ///
  /// This is what goes on the wire as `since` (api.md §3.2), which is
  /// exclusive, so the server answers with what this phone has not seen.
  /// It is the current scope's newest, so an account that signs in on a phone
  /// another account used asks for its whole window.
  Future<DateTime?> newestUpdatedAt() async {
    final scope = await _scope.current();
    if (scope == null) return null;
    final rows = await _db.rawQuery(
      'SELECT MAX(updated_at) AS newest FROM incidents WHERE scope = ?',
      [scope],
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
    final scope = await _scope.current();
    if (scope == null) return const [];
    final where = <String>['scope = ?'];
    final args = <Object?>[scope];
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
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'opened_at DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    if (rows.isEmpty) return const [];

    final byIncident = await MessageStore(_db, _scope)._groupedByIncident(
      scope,
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
    final scope = await _scope.current();
    if (scope == null) return 0;
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM incidents WHERE scope = ? AND opened_at < ?',
      [scope, _epoch(window)],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// Deletes incidents that opened before [cutoff], and their messages.
  ///
  /// Only the user asking for auto-delete calls this. A tier change never
  /// does. With [keepP5] on, an incident whose highest priority was 5 stays.
  /// An incident still `open` or `acked` stays whatever its age, the same
  /// rule the server prunes by (api.md §4.2).
  ///
  /// This covers every scope, not only the current one. The setting is about
  /// how long the phone keeps alarms, and an account that left its rows here
  /// would otherwise keep them for good.
  Future<int> deleteOlderThan(DateTime cutoff, {bool keepP5 = true}) async {
    final where = StringBuffer(
      'opened_at < ? AND state NOT IN (?, ?)',
    );
    final args = <Object?>[
      _epoch(cutoff),
      IncidentStates.open,
      IncidentStates.acked,
    ];
    if (keepP5) where.write(' AND priority < 5');

    return _db.transaction((txn) async {
      await txn.rawDelete(
        'DELETE FROM messages WHERE incident_id IS NOT NULL AND EXISTS ( '
        'SELECT 1 FROM incidents '
        'WHERE incidents.scope = messages.scope '
        'AND incidents.id = messages.incident_id AND $where)',
        args,
      );
      return txn.delete('incidents', where: where.toString(), whereArgs: args);
    });
  }

  Future<int> count() async {
    final scope = await _scope.current();
    if (scope == null) return 0;
    return Sqflite.firstIntValue(
      await _db.rawQuery(
        'SELECT COUNT(*) FROM incidents WHERE scope = ?',
        [scope],
      ),
    )!;
  }

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
///
/// Scoped like [IncidentStore]: reads return the current scope only, and a
/// write that started before the account changed is not stored.
class MessageStore {
  MessageStore(this._db, this._scope);

  final Database _db;
  final ArchiveScope _scope;

  /// Starts a write. Take it before the request the data comes from.
  ArchiveTicket beginWrite() => _scope.begin();

  /// Writes [messages], replacing any row with the same id in the same
  /// scope. See [IncidentStore.upsertAll] for [ticket].
  Future<void> upsertAll(
    Iterable<Message> messages, {
    ArchiveTicket? ticket,
  }) async {
    if (messages.isEmpty) return;
    final claim = ticket ?? _scope.begin();
    final scope = await claim.settle();
    if (scope == null) return;
    final syncedAt = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    await _db.transaction((txn) async {
      if (!claim.holds) return;
      final batch = txn.batch();
      _add(batch, scope, messages, syncedAt);
      await batch.commit(noResult: true);
    });
  }

  static void _add(
    Batch batch,
    String scope,
    Iterable<Message> messages,
    int syncedAt,
  ) {
    for (final message in messages) {
      batch.insert('messages', {
        'scope': scope,
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
  }

  /// The id of the newest message held on [topic], or null when there is
  /// none. This is the `since` the poll route takes (api.md §2).
  Future<String?> newestMessageId(String topic) async {
    final scope = await _scope.current();
    if (scope == null) return null;
    final rows = await _db.query(
      'messages',
      columns: const ['id'],
      where: 'scope = ? AND topic = ?',
      whereArgs: [scope, topic],
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
    final scope = await _scope.current();
    if (scope == null) return const [];
    final where = StringBuffer('scope = ? AND topic = ?');
    final args = <Object?>[scope, topic];
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
    final scope = await _scope.current();
    if (scope == null) return 0;
    final where = StringBuffer('scope = ? AND created_at < ?');
    final args = <Object?>[scope, _epoch(window)];
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
  /// Messages on an incident go when the incident goes. Like
  /// [IncidentStore.deleteOlderThan], this covers every scope.
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
    final scope = await _scope.current();
    if (scope == null) return const {};
    return _groupedByIncident(scope, incidentIds);
  }

  Future<Map<String, List<Message>>> _groupedByIncident(
    String scope,
    Iterable<String> incidentIds,
  ) async {
    final ids = incidentIds.toList();
    if (ids.isEmpty) return const {};
    final holes = List.filled(ids.length, '?').join(',');
    final rows = await _db.query(
      'messages',
      where: 'scope = ? AND incident_id IN ($holes)',
      whereArgs: [scope, ...ids],
      orderBy: 'created_at ASC, id ASC',
    );
    final grouped = <String, List<Message>>{};
    for (final row in rows) {
      final key = row['incident_id']! as String;
      (grouped[key] ??= <Message>[]).add(_toMessage(row));
    }
    return grouped;
  }

  Future<int> count() async {
    final scope = await _scope.current();
    if (scope == null) return 0;
    return Sqflite.firstIntValue(
      await _db.rawQuery(
        'SELECT COUNT(*) FROM messages WHERE scope = ?',
        [scope],
      ),
    )!;
  }

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

/// The topic list the server last gave, for one server and one account.
///
/// Every row carries a `scope`: a hash of the server and the account the list
/// was read for (`heldScopeFor`). A read names the scope it wants and gets
/// nothing for any other, so a list from another account or server is never
/// handed back, whatever else is in the table.
///
/// Only what the list route returns is stored: the name, Critical delivery,
/// the three timers, the relay content setting and when the topic was made.
/// A topic token, its id and its name are never written. The server shows a
/// token once, on creation, and the phone does not keep it.
///
/// An empty list is stored as no rows, which reads as "nothing held". The app
/// then asks the server before it says a person has no topics.
class TopicStore {
  TopicStore(this._db);

  final Database _db;

  /// Replaces everything held with [topics] for [scope], in order.
  ///
  /// The server's list is the whole truth, so a topic missing from it is
  /// deleted here. Rows of any other scope go too: only one list is kept.
  Future<void> replaceAll(String scope, Iterable<Topic> topics) async {
    final syncedAt = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    await _db.transaction((txn) async {
      await txn.delete('topics');
      var position = 0;
      for (final topic in topics) {
        await txn.insert('topics', {
          'scope': scope,
          'position': position++,
          'name': topic.name,
          'critical': topic.critical ? 1 : 0,
          'repeat_interval_s': topic.repeatIntervalS,
          'max_ring_s': topic.maxRingS,
          'desk_timer_s': topic.deskTimerS,
          'relay_content': topic.relayContent,
          'created_at_ms': topic.createdAt?.toUtc().millisecondsSinceEpoch,
          'synced_at': syncedAt,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// The list held for [scope], or null when none is held for it.
  ///
  /// Rows of another scope are deleted on the way, so a list that belonged to
  /// somebody else does not sit on the phone once it is known to be theirs.
  Future<List<Topic>?> read(String scope) async {
    final rows = await _db.query(
      'topics',
      where: 'scope = ?',
      whereArgs: [scope],
      orderBy: 'position ASC',
    );
    if (rows.isEmpty) {
      await _db.delete('topics');
      return null;
    }
    await _db.delete('topics', where: 'scope <> ?', whereArgs: [scope]);
    return [for (final row in rows) _toTopic(row)];
  }

  /// Deletes every held topic.
  Future<void> clear() => _db.delete('topics');

  Future<int> count() async => Sqflite.firstIntValue(
    await _db.rawQuery('SELECT COUNT(*) FROM topics'),
  )!;

  Topic _toTopic(Map<String, Object?> row) {
    final createdMs = row['created_at_ms'] as int?;
    return Topic(
      name: row['name']! as String,
      critical: (row['critical']! as int) == 1,
      repeatIntervalS: row['repeat_interval_s']! as int,
      maxRingS: row['max_ring_s']! as int,
      deskTimerS: row['desk_timer_s']! as int,
      relayContent: row['relay_content']! as String,
      createdAt: createdMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(createdMs, isUtc: true),
    );
  }
}
