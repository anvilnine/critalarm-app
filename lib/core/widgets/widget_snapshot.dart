import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:flutter/foundation.dart';

/// The one document the home and lock screen widgets read.
///
/// Dart, the iOS extensions and the Android widgets all agree on these bytes.
/// `test/fixtures/widget_snapshot_v1.json` is the format, and every
/// platform's tests read that sample. Nothing in Dart reads it back, so there
/// is no `fromJson`.
@immutable
final class WidgetSnapshot {
  const WidgetSnapshot({
    required this.updatedAt,
    required this.connected,
    required this.openCount,
    required this.topics,
  });

  /// What `clear` writes: signed out, nothing to show.
  factory WidgetSnapshot.disconnected(DateTime now) => WidgetSnapshot(
    updatedAt: epochSeconds(now),
    connected: false,
    openCount: 0,
    topics: const [],
  );

  static const version = 1;

  /// Most topics a snapshot carries. The biggest widget shows far fewer.
  static const maxTopics = 50;

  final int updatedAt;
  final bool connected;
  final int openCount;
  final List<WidgetTopic> topics;

  Map<String, Object?> toJson() => {
    'v': version,
    'updated_at': updatedAt,
    'connected': connected,
    'open_count': openCount,
    'topics': [for (final topic in topics) topic.toJson()],
  };
}

@immutable
final class WidgetTopic {
  const WidgetTopic({
    required this.name,
    required this.critical,
    required this.count,
    this.incident,
  });

  final String name;
  final bool critical;

  /// Open plus acked incidents on this topic.
  final int count;

  /// The one incident the widgets show for this topic.
  final WidgetIncident? incident;

  Map<String, Object?> toJson() => {
    'name': name,
    'critical': critical,
    'count': count,
    'incident': incident?.toJson(),
  };
}

@immutable
final class WidgetIncident {
  const WidgetIncident({
    required this.id,
    required this.state,
    required this.title,
    required this.openedAt,
    this.ackedAt,
  });

  final String id;

  /// `open` or `acked`. Closed and expired incidents never make it in.
  final String state;
  final String title;

  /// Epoch seconds, 0 when unknown.
  final int openedAt;

  /// Epoch seconds, null while open.
  final int? ackedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'state': state,
    'title': title,
    'opened_at': openedAt,
    'acked_at': ackedAt,
  };
}

/// Longest title a snapshot carries, in Unicode code points.
const widgetTitleMaxLength = 120;

/// Whole seconds since the epoch, rounded down.
int epochSeconds(DateTime time) => (time.millisecondsSinceEpoch / 1000).floor();

/// The line a widget shows for [incident]: the newest message's title, else
/// its text, else the topic name.
///
/// "Newest" is the largest `time`, so the order the server lists messages in
/// does not matter. The native side reads `messages.last` and the alarm screen
/// reads the first one, and api.md §3.2 promises neither.
String widgetIncidentTitle(Incident incident) {
  Message? newest;
  for (final message in incident.messages) {
    if (newest == null || message.time >= newest.time) newest = message;
  }
  final title = newest?.title?.trim() ?? '';
  return widgetTitle(
    title.isNotEmpty ? title : newest?.message,
    incident.topic,
  );
}

/// [raw] trimmed, else [topic], cut to [widgetTitleMaxLength] code points.
///
/// Swift and Kotlin cut the same way, so an emoji is never split in half and
/// all three agree on where the cut falls.
String widgetTitle(String? raw, String topic) {
  final trimmed = raw?.trim() ?? '';
  final picked = trimmed.isEmpty ? topic : trimmed;
  final runes = picked.runes;
  return runes.length > widgetTitleMaxLength
      ? String.fromCharCodes(runes.take(widgetTitleMaxLength))
      : picked;
}

/// Builds the snapshot from the app's topic and incident lists.
///
/// Rules, the same on every platform:
/// 1. A topic shows one incident: open beats acked, then the newest
///    `opened_at`, then the smaller id.
/// 2. Topics with an open incident come first, then acked, then the rest,
///    each group by name.
/// 3. Counts are open plus acked incidents.
/// 4. Times are whole epoch seconds.
///
/// Incidents on a topic that is not in [topics] are left out.
WidgetSnapshot buildWidgetSnapshot({
  required List<Topic> topics,
  required List<Incident> incidents,
  required bool connected,
  required DateTime now,
}) {
  if (!connected) return WidgetSnapshot.disconnected(now);

  final live = <String, List<Incident>>{};
  for (final incident in incidents) {
    if (!incident.isOpen && !incident.isAcked) continue;
    live.putIfAbsent(incident.topic, () => []).add(incident);
  }

  final built = [
    for (final topic in topics)
      _topicFor(topic, live[topic.name] ?? const <Incident>[]),
  ]..sort(_displayOrder);

  final kept = built.take(WidgetSnapshot.maxTopics).toList(growable: false);
  return WidgetSnapshot(
    updatedAt: epochSeconds(now),
    connected: true,
    openCount: kept.fold(0, (sum, topic) => sum + topic.count),
    topics: kept,
  );
}

WidgetTopic _topicFor(Topic topic, List<Incident> incidents) {
  Incident? shown;
  for (final incident in incidents) {
    if (shown == null || _wins(incident, shown)) shown = incident;
  }
  return WidgetTopic(
    name: topic.name,
    critical: topic.critical,
    count: incidents.length,
    incident: shown == null ? null : _incidentFor(shown),
  );
}

WidgetIncident _incidentFor(Incident incident) {
  final openedAt = incident.openedAt;
  final ackedAt = incident.ackedAt;
  return WidgetIncident(
    id: incident.id,
    state: incident.isOpen ? IncidentStates.open : IncidentStates.acked,
    title: widgetIncidentTitle(incident),
    openedAt: openedAt == null ? 0 : epochSeconds(openedAt),
    ackedAt: incident.isAcked && ackedAt != null ? epochSeconds(ackedAt) : null,
  );
}

/// True when [a] should be shown over [b] (rule 1).
bool _wins(Incident a, Incident b) {
  if (a.isOpen != b.isOpen) return a.isOpen;
  final aOpened = a.openedAt == null ? 0 : epochSeconds(a.openedAt!);
  final bOpened = b.openedAt == null ? 0 : epochSeconds(b.openedAt!);
  if (aOpened != bOpened) return aOpened > bOpened;
  return a.id.compareTo(b.id) < 0;
}

int _group(WidgetTopic topic) => switch (topic.incident?.state) {
  IncidentStates.open => 0,
  IncidentStates.acked => 1,
  _ => 2,
};

/// Rule 2.
int _displayOrder(WidgetTopic a, WidgetTopic b) {
  final byGroup = _group(a).compareTo(_group(b));
  return byGroup != 0 ? byGroup : a.name.compareTo(b.name);
}
