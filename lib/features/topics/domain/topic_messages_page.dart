import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/time/calendar_days.dart';
import 'package:flutter/foundation.dart';

// The pure rules behind a topic's full messages page: the seven day bars, the
// day groups, and the line on a message that rang. Nothing here reads a
// widget or the clock, so each rule is tested on its own.

/// How many days the bars show, today included.
const int kMessageBarDays = 7;

/// A message as the bars see it: when it arrived and whether it rang.
typedef MessageMoment = ({DateTime at, bool rang});

/// One day of the bars.
@immutable
class MessageDayBar {
  const MessageDayBar({
    required this.day,
    required this.count,
    required this.hasRang,
    required this.fraction,
    required this.isToday,
  });

  /// Local midnight of the day.
  final DateTime day;

  /// Messages that arrived this day.
  final int count;

  /// An alarm rang for at least one of them.
  final bool hasRang;

  /// [count] as a share of the busiest day, 0 to 1. Zero for a quiet day.
  final double fraction;

  final bool isToday;

  @override
  bool operator ==(Object other) =>
      other is MessageDayBar &&
      other.day == day &&
      other.count == count &&
      other.hasRang == hasRang &&
      other.fraction == fraction &&
      other.isToday == isToday;

  @override
  int get hashCode => Object.hash(day, count, hasRang, fraction, isToday);
}

/// The [kMessageBarDays] days ending on [now]'s day, oldest first, with how
/// many messages each held.
///
/// Days are calendar days on the phone's clock. A message older than the
/// first day is not counted, and one dated after [now] counts as today, so a
/// clock that runs a little ahead never loses a message.
List<MessageDayBar> messageDayBars({
  required Iterable<MessageMoment> messages,
  required DateTime now,
}) {
  final today = now.toLocal();
  final counts = List<int>.filled(kMessageBarDays, 0);
  final rang = List<bool>.filled(kMessageBarDays, false);

  for (final message in messages) {
    final back = calendarDaysBetween(message.at.toLocal(), today);
    if (back >= kMessageBarDays) continue;
    final index = kMessageBarDays - 1 - (back < 0 ? 0 : back);
    counts[index]++;
    if (message.rang) rang[index] = true;
  }

  var busiest = 0;
  for (final count in counts) {
    if (count > busiest) busiest = count;
  }

  return [
    for (var i = 0; i < kMessageBarDays; i++)
      MessageDayBar(
        day: DateTime(
          today.year,
          today.month,
          today.day - (kMessageBarDays - 1 - i),
        ),
        count: counts[i],
        hasRang: rang[i],
        fraction: busiest == 0 ? 0 : counts[i] / busiest,
        isToday: i == kMessageBarDays - 1,
      ),
  ];
}

/// How a day group is named.
enum MessageDayKind { today, yesterday, earlier }

/// The messages of one day, newest first.
@immutable
class MessageDay<T> {
  const MessageDay({
    required this.day,
    required this.kind,
    required this.items,
  });

  /// Local midnight of the day.
  final DateTime day;
  final MessageDayKind kind;
  final List<T> items;
}

/// [items] cut into days, in the order given. A new group starts whenever the
/// day changes, so a list that is newest first stays newest first.
///
/// [timeOf] says when an item arrived. A moment after [now] counts as today.
List<MessageDay<T>> groupMessagesByDay<T>(
  List<T> items, {
  required DateTime Function(T item) timeOf,
  required DateTime now,
}) {
  final today = now.toLocal();
  final groups = <MessageDay<T>>[];
  for (final item in items) {
    final at = timeOf(item).toLocal();
    final back = calendarDaysBetween(at, today);
    final day = back <= 0
        ? DateTime(today.year, today.month, today.day)
        : DateTime(at.year, at.month, at.day);
    if (groups.isNotEmpty && groups.last.day == day) {
      groups.last.items.add(item);
      continue;
    }
    groups.add(
      MessageDay<T>(
        day: day,
        kind: back <= 0
            ? MessageDayKind.today
            : back == 1
            ? MessageDayKind.yesterday
            : MessageDayKind.earlier,
        items: [item],
      ),
    );
  }
  return groups;
}

/// How an alarm that rang for a message ended.
enum RangEnd {
  /// Someone acknowledged it.
  answered,

  /// It ended with nobody answering: the sender closed it.
  resolved,

  /// It rang its full time and nobody answered.
  expired,

  /// It is ringing now.
  ringing,
}

/// What the mono line under a message that rang says.
@immutable
class RangLine {
  const RangLine({required this.end, this.duration});

  final RangEnd end;

  /// How long it rang, or null when the incident does not say when it
  /// stopped. The line then names the end alone.
  final Duration? duration;

  @override
  bool operator ==(Object other) =>
      other is RangLine && other.end == end && other.duration == duration;

  @override
  int get hashCode => Object.hash(end, duration);
}

/// The line for [incident], read only from what the incident holds.
///
/// - Open: ringing now, with no length.
/// - Acknowledged: answered, after the time from opening to the
///   acknowledge.
/// - Closed: answered when it was acknowledged first, resolved when it was
///   closed without one. Rang until the acknowledge, or the close.
/// - Expired: expired, after the time from opening to the close, when the
///   incident carries one.
///
/// A length is left out when the incident lacks the time it started or
/// stopped, rather than guessed.
RangLine rangLineFor(Incident incident) {
  final opened = incident.openedAt;
  Duration? since(DateTime? stopped) {
    if (opened == null || stopped == null) return null;
    final length = stopped.difference(opened);
    return length.isNegative ? null : length;
  }

  return switch (incident.incidentState) {
    IncidentState.open => const RangLine(end: RangEnd.ringing),
    IncidentState.acked => RangLine(
      end: RangEnd.answered,
      duration: since(incident.ackedAt),
    ),
    IncidentState.closed => RangLine(
      end: incident.ackedAt != null ? RangEnd.answered : RangEnd.resolved,
      duration: since(incident.ackedAt ?? incident.closedAt),
    ),
    IncidentState.expired => RangLine(
      end: RangEnd.expired,
      duration: since(incident.closedAt),
    ),
  };
}

/// A message that an incident holds.
@immutable
class RangMatch {
  const RangMatch({required this.incident, required this.opensIncident});

  final Incident incident;

  /// This is the message that opened the incident. Later ones are repeats of
  /// it, so only this one carries the line.
  final bool opensIncident;

  /// The line to print under the message, or null on a repeat.
  RangLine? get line => opensIncident ? rangLineFor(incident) : null;
}

/// Which messages rang, found from the incidents the phone already holds.
///
/// A message is linked to its incident by id. The server files every message
/// of an incident under that incident's id (api.md §1.6, `incident_id`), and
/// the incident lists the same messages by their own ids (§3.2). Either id is
/// enough: the incident id on the message is tried first, then the message id
/// among the incident's messages.
///
/// There is no match on the words. A message with neither id, such as an
/// example row that was never stored, shows no ring.
class RangIndex {
  RangIndex._(this._incidents, this._byMessageId, this._openingIds);

  /// Indexes the messages of [incidents]. Pass the incidents of one topic.
  factory RangIndex.of(Iterable<Incident> incidents) {
    final byIncident = <String, Incident>{};
    final byMessage = <String, Incident>{};
    final openingIds = <String, String>{};
    for (final incident in incidents) {
      byIncident[incident.id] = incident;
      final messages = incident.messages;
      if (messages.isEmpty) continue;
      var opening = messages.first;
      for (final message in messages) {
        if (message.time < opening.time) opening = message;
      }
      openingIds[incident.id] = opening.id;
      for (final message in messages) {
        byMessage.putIfAbsent(message.id, () => incident);
      }
    }
    return RangIndex._(byIncident, byMessage, openingIds);
  }

  final Map<String, Incident> _incidents;
  final Map<String, Incident> _byMessageId;

  /// The id of the message that opened each incident that lists messages.
  final Map<String, String> _openingIds;

  /// The match for the message [messageId], filed under [incidentId] when the
  /// server said so, or null when no incident holds it, so it did not ring.
  RangMatch? find({String? messageId, String? incidentId}) {
    final incident =
        (incidentId == null ? null : _incidents[incidentId]) ??
        (messageId == null ? null : _byMessageId[messageId]);
    if (incident == null) return null;
    return RangMatch(
      incident: incident,
      opensIncident: messageId != null && _openingIds[incident.id] == messageId,
    );
  }
}
