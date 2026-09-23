import 'dart:convert';

/// Immutable, phone-local view of the alarm state shown by Alarm Debug.
///
/// Native timestamps use epoch seconds. Dart's ack queue is adapted at its
/// boundary because it stores epoch milliseconds.
final class AlarmDebugSnapshot {
  AlarmDebugSnapshot({
    required this.takenAt,
    required this.environment,
    Iterable<DebugIncident> incidents = const [],
    Iterable<DebugAckEntry> ackQueue = const [],
    Iterable<DebugAckedMark> ackedSet = const [],
    Iterable<DebugScheduled> scheduled = const [],
    Iterable<DebugPushEvent> pushEvents = const [],
    Iterable<DebugLaunchCall> launchCalls = const [],
    this.store = DebugStoreStats.empty,
    this.permissions = const DebugPermissions(),
    this.ringing = false,
  }) : incidents = List.unmodifiable(incidents),
       ackQueue = List.unmodifiable(ackQueue),
       ackedSet = List.unmodifiable(ackedSet),
       scheduled = List.unmodifiable(scheduled),
       pushEvents = List.unmodifiable(pushEvents),
       launchCalls = List.unmodifiable(launchCalls);

  factory AlarmDebugSnapshot.fromNative(
    Map<String, Object?> native, {
    required DateTime takenAt,
    required DebugEnvironment environment,
    Iterable<DebugAckEntry> dartAckQueue = const [],
    Iterable<DebugPushEvent> pushEvents = const [],
    Iterable<DebugLaunchCall> launchCalls = const [],
    DebugStoreStats store = DebugStoreStats.empty,
  }) {
    final permissionsRaw = native['permissions'];
    final permissions = DebugPermissions.fromMap(
      permissionsRaw is Map ? _stringMap(permissionsRaw) : const {},
    );
    final nativeAcks = _rows(
      native['ack_queue'],
    ).map(DebugAckEntry.fromNative).whereType<DebugAckEntry>();
    final ackQueue = _mergeAcks([...nativeAcks, ...dartAckQueue]);
    final nativePushEvents = _rows(
      native['push_events'],
    ).map(DebugPushEvent.fromJson).whereType<DebugPushEvent>();
    return AlarmDebugSnapshot(
      takenAt: takenAt.toUtc(),
      environment: environment,
      incidents: _rows(
        native['incidents'],
      ).map(DebugIncident.fromNative).whereType<DebugIncident>(),
      ackQueue: ackQueue,
      ackedSet: _rows(
        native['acked_set'],
      ).map(DebugAckedMark.fromNative).whereType<DebugAckedMark>(),
      scheduled: _rows(
        native['scheduled'],
      ).map(DebugScheduled.fromNative).whereType<DebugScheduled>(),
      pushEvents: _mergePushEvents([...nativePushEvents, ...pushEvents]),
      launchCalls: launchCalls,
      store: store,
      permissions: permissions,
      ringing: native['ringing'] == true,
    );
  }

  factory AlarmDebugSnapshot.fromJson(Map<String, Object?> json) {
    final environmentRaw = json['environment'];
    final environment = environmentRaw is Map
        ? DebugEnvironment.fromJson(_stringMap(environmentRaw))
        : const DebugEnvironment();
    final permissionsRaw = json['permissions'];
    final storeRaw = json['store'];
    return AlarmDebugSnapshot(
      takenAt:
          _parseDate(json['taken_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      environment: environment,
      incidents: _rows(
        json['incidents'],
      ).map(DebugIncident.fromJson).whereType<DebugIncident>(),
      ackQueue: _rows(
        json['ack_queue'],
      ).map(DebugAckEntry.fromJson).whereType<DebugAckEntry>(),
      ackedSet: _rows(
        json['acked_set'],
      ).map(DebugAckedMark.fromJson).whereType<DebugAckedMark>(),
      scheduled: _rows(
        json['scheduled'],
      ).map(DebugScheduled.fromJson).whereType<DebugScheduled>(),
      pushEvents: _rows(
        json['push_events'],
      ).map(DebugPushEvent.fromJson).whereType<DebugPushEvent>(),
      launchCalls: _rows(
        json['launch_calls'],
      ).map(DebugLaunchCall.fromJson).whereType<DebugLaunchCall>(),
      store: storeRaw is Map
          ? DebugStoreStats.fromJson(_stringMap(storeRaw))
          : DebugStoreStats.empty,
      permissions: permissionsRaw is Map
          ? DebugPermissions.fromMap(_stringMap(permissionsRaw))
          : const DebugPermissions(),
      ringing: json['ringing'] == true,
    );
  }

  final DateTime takenAt;
  final DebugEnvironment environment;
  final List<DebugIncident> incidents;
  final List<DebugAckEntry> ackQueue;
  final List<DebugAckedMark> ackedSet;
  final List<DebugScheduled> scheduled;
  final List<DebugPushEvent> pushEvents;
  final List<DebugLaunchCall> launchCalls;
  final DebugStoreStats store;
  final DebugPermissions permissions;
  final bool ringing;

  Map<String, Object?> toJson() => {
    'taken_at': takenAt.toUtc().toIso8601String(),
    'environment': environment.toJson(),
    'incidents': incidents.map((row) => row.toJson()).toList(),
    'ack_queue': ackQueue.map((row) => row.toJson()).toList(),
    'acked_set': ackedSet.map((row) => row.toJson()).toList(),
    'scheduled': scheduled.map((row) => row.toJson()).toList(),
    'push_events': pushEvents.map((row) => row.toJson()).toList(),
    'launch_calls': launchCalls.map((row) => row.toJson()).toList(),
    'store': store.toJson(),
    'permissions': permissions.toJson(),
    'ringing': ringing,
  };
}

List<Map<String, Object?>> _rows(Object? value) =>
    value is List ? value.whereType<Map>().map(_stringMap).toList() : const [];

Map<String, Object?> _stringMap(Map<Object?, Object?> value) => {
  for (final entry in value.entries)
    if (entry.key is String) entry.key as String: entry.value,
};

DateTime? _parseDate(Object? value) {
  if (value is DateTime) return value.toUtc();
  if (value is String) return DateTime.tryParse(value)?.toUtc();
  if (value is int)
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  return null;
}

DateTime? _seconds(Object? value) => value is int
    ? DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true)
    : null;

List<DebugAckEntry> _mergeAcks(Iterable<DebugAckEntry> entries) {
  final merged = <String, DebugAckEntry>{};
  for (final entry in entries) {
    final key = '${entry.action}\u0000${entry.incidentId}';
    final previous = merged[key];
    if (previous == null) {
      merged[key] = entry;
      continue;
    }
    final later = entry.nextAttemptAt.isAfter(previous.nextAttemptAt)
        ? entry.nextAttemptAt
        : previous.nextAttemptAt;
    merged[key] = DebugAckEntry(
      action: entry.action,
      incidentId: entry.incidentId,
      attempts: entry.attempts > previous.attempts
          ? entry.attempts
          : previous.attempts,
      nextAttemptAt: later,
      lastError: entry.lastError ?? previous.lastError,
      source: previous.source == entry.source
          ? previous.source
          : DebugAckSource.combined,
    );
  }
  return List.unmodifiable(merged.values);
}

List<DebugPushEvent> _mergePushEvents(Iterable<DebugPushEvent> events) {
  final merged = <String, DebugPushEvent>{};
  for (final event in events) {
    final sortedValues = Map.fromEntries(
      event.values.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    merged.putIfAbsent(jsonEncode(sortedValues), () => event);
  }
  final result = merged.values.toList()
    ..sort((a, b) {
      final aAt = a.at;
      final bAt = b.at;
      if (aAt == null) return bAt == null ? 0 : 1;
      if (bAt == null) return -1;
      return bAt.compareTo(aAt);
    });
  return List.unmodifiable(result);
}

final class DebugEnvironment {
  const DebugEnvironment({
    this.serverMode,
    this.baseUrl,
    this.tier,
    this.historyDays,
    this.quietHoursEnabled = false,
    this.quietHoursHolding = false,
    this.quietHoursStart,
    this.quietHoursEnd,
  });

  final String? serverMode;
  final String? baseUrl;
  final String? tier;
  final int? historyDays;
  final bool quietHoursEnabled;
  final bool quietHoursHolding;
  final String? quietHoursStart;
  final String? quietHoursEnd;

  Map<String, Object?> toJson() => {
    'server_mode': serverMode,
    'base_url': baseUrl,
    'tier': tier,
    'history_days': historyDays,
    'quiet_hours_enabled': quietHoursEnabled,
    'quiet_hours_holding': quietHoursHolding,
    'quiet_hours_start': quietHoursStart,
    'quiet_hours_end': quietHoursEnd,
  };

  factory DebugEnvironment.fromJson(Map<String, Object?> json) =>
      DebugEnvironment(
        serverMode: json['server_mode'] as String?,
        baseUrl: json['base_url'] as String?,
        tier: json['tier'] as String?,
        historyDays: json['history_days'] as int?,
        quietHoursEnabled: json['quiet_hours_enabled'] == true,
        quietHoursHolding: json['quiet_hours_holding'] == true,
        quietHoursStart: json['quiet_hours_start'] as String?,
        quietHoursEnd: json['quiet_hours_end'] as String?,
      );
}

enum DebugAckSource { dart, native, combined }

final class DebugIncident {
  const DebugIncident({
    required this.id,
    this.topic,
    this.phoneState = 'unknown',
    this.ringUntil,
    this.rearmPending = false,
    this.rearmFiresAt,
    this.ackedLocally = false,
    this.deskTimerFiresAt,
    this.lastPushKind,
    this.lastPushAt,
    this.contentCachedAt,
    this.contentLastMessageAt,
  });

  final String id;
  final String? topic;
  final String phoneState;
  final DateTime? ringUntil;
  final bool rearmPending;
  final DateTime? rearmFiresAt;
  final bool ackedLocally;
  final DateTime? deskTimerFiresAt;
  final String? lastPushKind;
  final DateTime? lastPushAt;
  final DateTime? contentCachedAt;
  final DateTime? contentLastMessageAt;

  static DebugIncident? fromNative(Map<String, Object?> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    final rawState = json['phone_state'];
    const knownStates = {
      'ringing',
      'closed',
      'acked here',
      'acked elsewhere',
      'silenced',
      'expired',
      'unknown',
    };
    return DebugIncident(
      id: id,
      topic: json['topic'] is String ? json['topic'] as String : null,
      phoneState: rawState is String && knownStates.contains(rawState)
          ? rawState
          : 'unknown',
      ringUntil: _seconds(json['ring_until']),
      rearmPending: json['rearm_pending'] == true,
      rearmFiresAt: _seconds(json['rearm_fires_at']),
      ackedLocally: json['acked_locally'] == true,
      deskTimerFiresAt: _seconds(json['desk_timer_fires_at']),
      lastPushKind: json['last_push_kind'] is String
          ? json['last_push_kind'] as String
          : null,
      lastPushAt: _seconds(json['last_push_at']),
      contentCachedAt: _seconds(json['content_cached_at']),
      contentLastMessageAt: _seconds(json['content_last_message_at']),
    );
  }

  static DebugIncident? fromJson(Map<String, Object?> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    return DebugIncident(
      id: id,
      topic: json['topic'] as String?,
      phoneState: json['phone_state'] as String? ?? 'unknown',
      ringUntil: _parseDate(json['ring_until']),
      rearmPending: json['rearm_pending'] == true,
      rearmFiresAt: _parseDate(json['rearm_fires_at']),
      ackedLocally: json['acked_locally'] == true,
      deskTimerFiresAt: _parseDate(json['desk_timer_fires_at']),
      lastPushKind: json['last_push_kind'] as String?,
      lastPushAt: _parseDate(json['last_push_at']),
      contentCachedAt: _parseDate(json['content_cached_at']),
      contentLastMessageAt: _parseDate(json['content_last_message_at']),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'topic': topic,
    'phone_state': phoneState,
    'ring_until': ringUntil?.toUtc().toIso8601String(),
    'rearm_pending': rearmPending,
    'rearm_fires_at': rearmFiresAt?.toUtc().toIso8601String(),
    'acked_locally': ackedLocally,
    'desk_timer_fires_at': deskTimerFiresAt?.toUtc().toIso8601String(),
    'last_push_kind': lastPushKind,
    'last_push_at': lastPushAt?.toUtc().toIso8601String(),
    'content_cached_at': contentCachedAt?.toUtc().toIso8601String(),
    'content_last_message_at': contentLastMessageAt?.toUtc().toIso8601String(),
  };
}

final class DebugAckEntry {
  const DebugAckEntry({
    required this.action,
    required this.incidentId,
    required this.attempts,
    required this.nextAttemptAt,
    this.lastError,
    required this.source,
  });

  final String action;
  final String incidentId;
  final int attempts;
  final DateTime nextAttemptAt;
  final String? lastError;
  final DebugAckSource source;

  static DebugAckEntry? fromNative(Map<String, Object?> json) {
    final action = json['action'];
    final id = json['incident_id'];
    final attempts = json['attempts'];
    final next = _seconds(json['next_attempt_at']);
    if (action is! String || id is! String || attempts is! int || next == null)
      return null;
    return DebugAckEntry(
      action: action,
      incidentId: id,
      attempts: attempts,
      nextAttemptAt: next,
      lastError: json['last_error'] is String
          ? json['last_error'] as String
          : null,
      source: DebugAckSource.native,
    );
  }

  static DebugAckEntry? fromJson(Map<String, Object?> json) {
    final action = json['action'];
    final id = json['incident_id'];
    final attempts = json['attempts'];
    final next = _parseDate(json['next_attempt_at']);
    if (action is! String || id is! String || attempts is! int || next == null)
      return null;
    return DebugAckEntry(
      action: action,
      incidentId: id,
      attempts: attempts,
      nextAttemptAt: next,
      lastError: json['last_error'] as String?,
      source: DebugAckSource.values.firstWhere(
        (source) => source.name == json['source'],
        orElse: () => DebugAckSource.dart,
      ),
    );
  }

  Map<String, Object?> toJson() => {
    'action': action,
    'incident_id': incidentId,
    'attempts': attempts,
    'next_attempt_at': nextAttemptAt.toUtc().toIso8601String(),
    'last_error': lastError,
    'source': source.name,
  };
}

final class DebugAckedMark {
  const DebugAckedMark({required this.incidentId, required this.markedAt});
  final String incidentId;
  final DateTime? markedAt;

  static DebugAckedMark? fromNative(Map<String, Object?> json) {
    final id = json['incident_id'];
    if (id is! String || id.isEmpty) return null;
    return DebugAckedMark(
      incidentId: id,
      markedAt: _seconds(json['marked_at']),
    );
  }

  static DebugAckedMark? fromJson(Map<String, Object?> json) {
    final id = json['incident_id'];
    if (id is! String || id.isEmpty) return null;
    return DebugAckedMark(
      incidentId: id,
      markedAt: _parseDate(json['marked_at']),
    );
  }

  Map<String, Object?> toJson() => {
    'incident_id': incidentId,
    'marked_at': markedAt?.toUtc().toIso8601String(),
  };
}

final class DebugScheduled {
  const DebugScheduled({
    required this.kind,
    required this.identifier,
    this.firesAt,
  });
  final String kind;
  final String identifier;
  final DateTime? firesAt;

  static DebugScheduled? fromNative(Map<String, Object?> json) {
    final kind = json['kind'];
    final identifier = json['identifier'];
    if (kind is! String || identifier is! String) return null;
    return DebugScheduled(
      kind: kind,
      identifier: identifier,
      firesAt: _seconds(json['fires_at']),
    );
  }

  static DebugScheduled? fromJson(Map<String, Object?> json) {
    final kind = json['kind'];
    final identifier = json['identifier'];
    if (kind is! String || identifier is! String) return null;
    return DebugScheduled(
      kind: kind,
      identifier: identifier,
      firesAt: _parseDate(json['fires_at']),
    );
  }

  Map<String, Object?> toJson() => {
    'kind': kind,
    'identifier': identifier,
    'fires_at': firesAt?.toUtc().toIso8601String(),
  };
}

final class DebugPermissions {
  const DebugPermissions({
    this.notifications = 'unsupported',
    this.alarmkit = 'unsupported',
    this.batteryExempt,
  });
  final String notifications;
  final String alarmkit;
  final bool? batteryExempt;

  factory DebugPermissions.fromMap(Map<String, Object?> json) =>
      DebugPermissions(
        notifications: json['notifications'] is String
            ? json['notifications'] as String
            : 'unsupported',
        alarmkit: json['alarmkit'] is String
            ? json['alarmkit'] as String
            : 'unsupported',
        batteryExempt: json['battery_exempt'] is bool
            ? json['battery_exempt'] as bool
            : null,
      );

  Map<String, Object?> toJson() => {
    'notifications': notifications,
    'alarmkit': alarmkit,
    'battery_exempt': batteryExempt,
  };
}

final class DebugPushEvent {
  DebugPushEvent(Map<String, Object?> values)
    : values = Map.unmodifiable(values);
  final Map<String, Object?> values;
  String? get name => values['name'] as String?;
  DateTime? get at => _parseDate(
    values['at'] ?? values['time'] ?? values['timestamp'] ?? values['at_ms'],
  );
  Map<String, Object?> toJson() => Map.of(values);

  static DebugPushEvent? fromJson(Map<String, Object?> json) =>
      json['name'] is String ? DebugPushEvent(json) : null;
}

final class DebugLaunchCall {
  const DebugLaunchCall({
    required this.name,
    required this.at,
    this.attempt,
    this.error,
  });
  final String name;
  final DateTime at;
  final int? attempt;
  final String? error;
  bool get succeeded => error == null;

  static DebugLaunchCall? fromJson(Map<String, Object?> json) {
    final name = json['name'];
    final at = _parseDate(json['at']);
    if (name is! String || at == null) return null;
    return DebugLaunchCall(
      name: name,
      at: at,
      attempt: json['attempt'] as int?,
      error: json['error'] as String?,
    );
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'at': at.toUtc().toIso8601String(),
    'attempt': attempt,
    'error': error,
  };
}

final class DebugStoreStats {
  const DebugStoreStats({
    this.incidentCount = 0,
    this.messageCount = 0,
    this.oldestIncidentAt,
    this.databaseBytes,
    this.lastSyncAt,
    this.lastSince,
  });
  static const empty = DebugStoreStats();
  final int incidentCount;
  final int messageCount;
  final DateTime? oldestIncidentAt;
  final int? databaseBytes;
  final DateTime? lastSyncAt;
  final String? lastSince;

  factory DebugStoreStats.fromJson(Map<String, Object?> json) =>
      DebugStoreStats(
        incidentCount: json['incident_count'] is int
            ? json['incident_count'] as int
            : 0,
        messageCount: json['message_count'] is int
            ? json['message_count'] as int
            : 0,
        oldestIncidentAt: _parseDate(json['oldest_incident_at']),
        databaseBytes: json['database_bytes'] as int?,
        lastSyncAt: _parseDate(json['last_sync_at']),
        lastSince: json['last_since'] as String?,
      );

  Map<String, Object?> toJson() => {
    'incident_count': incidentCount,
    'message_count': messageCount,
    'oldest_incident_at': oldestIncidentAt?.toUtc().toIso8601String(),
    'database_bytes': databaseBytes,
    'last_sync_at': lastSyncAt?.toUtc().toIso8601String(),
    'last_since': lastSince,
  };
}
