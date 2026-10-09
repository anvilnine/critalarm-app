import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_input.dart';
import 'package:flutter/foundation.dart';

/// What state an inbox row is in. Only [normal] rows are well.
enum InboxRowKind {
  /// An alarm is sounding on the topic.
  ringing,

  /// An alarm was acknowledged and its desk timer is counting.
  acknowledged,

  /// The topic sent a warning.
  warning,

  /// An alarm on the topic ran out with nobody answering.
  missed,

  /// An alarm on the topic was closed within the last hour.
  handled,

  /// Nothing to say.
  normal,
}

/// How long a row keeps saying "handled" or "missed" after a close.
const Duration inboxStateWindow = Duration(hours: 1);

/// The state of the row for [topic].
///
/// Uses the same facts the Home hero uses, in the same order: a sounding
/// alarm, then a warning, then an acknowledged alarm whose desk timer is
/// still counting, then the newest close within [inboxStateWindow]. A close
/// that is an alarm running out is a missed row, and any other close is a
/// handled row.
///
/// - [incidents]: every incident the app holds. Other topics are ignored.
/// - [warningTopics]: the topics with a live warning.
/// - [deskTimerS]: the topic's desk timer, for a server that does not send
///   `desk_timer_fires_at`.
InboxRowKind rowKindFor({
  required String topic,
  required Iterable<Incident> incidents,
  required Set<String> warningTopics,
  required DateTime now,
  int deskTimerS = defaultDeskTimerS,
}) {
  final own = incidents.where((i) => i.topic == topic).toList();

  final isRinging = own.any(
    (i) => i.isOpen && i.messages.any((m) => m.priority == 5),
  );
  if (isRinging) return InboxRowKind.ringing;

  if (warningTopics.contains(topic)) return InboxRowKind.warning;

  final isAcknowledged = own.any((i) {
    final fact = AcknowledgedFact.fromIncident(i, deskTimerS: deskTimerS);
    return fact != null && now.isBefore(fact.deadline);
  });
  if (isAcknowledged) return InboxRowKind.acknowledged;

  Incident? newestClose;
  for (final incident in own) {
    final closedAt = incident.closedAt;
    if (closedAt == null) continue;
    if (!incident.isClosed && !incident.isExpired) continue;
    if (now.difference(closedAt) >= inboxStateWindow) continue;
    if (newestClose == null || closedAt.isAfter(newestClose.closedAt!)) {
      newestClose = incident;
    }
  }
  if (newestClose != null) {
    return newestClose.isExpired ? InboxRowKind.missed : InboxRowKind.handled;
  }
  return InboxRowKind.normal;
}

/// One row of the inbox, as the order rule sees it.
@immutable
class InboxEntry {
  const InboxEntry({
    required this.name,
    required this.kind,
    this.pinned = false,
    this.muted = false,
    this.unreadCount = 0,
    this.lastMessageAt,
  });

  final String name;
  final InboxRowKind kind;
  final bool pinned;
  final bool muted;
  final int unreadCount;

  /// Null for a topic with no messages.
  final DateTime? lastMessageAt;

  @override
  bool operator ==(Object other) =>
      other is InboxEntry &&
      other.name == name &&
      other.kind == kind &&
      other.pinned == pinned &&
      other.muted == muted &&
      other.unreadCount == unreadCount &&
      other.lastMessageAt == lastMessageAt;

  @override
  int get hashCode =>
      Object.hash(name, kind, pinned, muted, unreadCount, lastMessageAt);
}

/// Which rows need the user, and in what order. Null for a row that does not.
int? _needsYouRank(InboxRowKind kind) => switch (kind) {
  InboxRowKind.ringing => 0,
  InboxRowKind.acknowledged => 1,
  InboxRowKind.warning => 2,
  InboxRowKind.missed => 3,
  InboxRowKind.handled || InboxRowKind.normal => null,
};

/// The order of the flat inbox, as topic names.
///
/// 1. Rows that need the user: ringing, acknowledged, warning, missed.
/// 2. Pinned rows, directly under them.
/// 3. Rows with unread messages.
/// 4. The rest.
/// 5. Muted rows.
///
/// A row that needs the user never sinks to the muted group. A pinned row
/// stays in the pinned group when muted. Inside a group the newest message
/// comes first, a topic with no messages follows those with messages, and a
/// tie keeps the order the entries came in.
List<String> orderInbox(List<InboxEntry> entries) {
  int group(InboxEntry e) {
    if (_needsYouRank(e.kind) != null) return 0;
    if (e.pinned) return 1;
    if (e.muted) return 4;
    if (e.unreadCount > 0) return 2;
    return 3;
  }

  final indexed = entries.asMap().entries.toList()
    ..sort((a, b) {
      final x = a.value;
      final y = b.value;
      final byGroup = group(x).compareTo(group(y));
      if (byGroup != 0) return byGroup;
      if (group(x) == 0) {
        final byRank = _needsYouRank(x.kind)!.compareTo(_needsYouRank(y.kind)!);
        if (byRank != 0) return byRank;
      }
      final xt = x.lastMessageAt;
      final yt = y.lastMessageAt;
      if (xt != null && yt != null) {
        final byTime = yt.compareTo(xt);
        if (byTime != 0) return byTime;
      } else if (xt != null) {
        return -1;
      } else if (yt != null) {
        return 1;
      }
      // List.sort is not stable, so the position breaks ties.
      return a.key.compareTo(b.key);
    });
  return [for (final entry in indexed) entry.value.name];
}

/// How the time cell of a row is written. The view formats it.
enum InboxTimeStyle {
  /// A time of day, for a message from today.
  clock,

  /// The word for yesterday.
  yesterday,

  /// The name of the weekday, within the last week.
  weekday,

  /// A date, for anything older.
  date,

  /// The cell names the row's state ("Ringing", "Handled 06:14").
  state,

  /// No time to show: the topic has no messages.
  none,
}

/// The style of the time cell for a row last written to at [at].
///
/// A ringing, acknowledged, missed or handled row names its state. A warning
/// row and a normal row show the message time. Days are calendar days in
/// local time, not spans of 24 hours.
InboxTimeStyle timeStyleFor(
  DateTime? at,
  DateTime now,
  InboxRowKind kind,
) {
  switch (kind) {
    case InboxRowKind.ringing:
    case InboxRowKind.acknowledged:
    case InboxRowKind.missed:
    case InboxRowKind.handled:
      return InboxTimeStyle.state;
    case InboxRowKind.warning:
    case InboxRowKind.normal:
      break;
  }
  if (at == null) return InboxTimeStyle.none;
  final localAt = at.toLocal();
  final localNow = now.toLocal();
  final days = DateTime.utc(
    localNow.year,
    localNow.month,
    localNow.day,
  ).difference(DateTime.utc(localAt.year, localAt.month, localAt.day)).inDays;
  if (days <= 0) return InboxTimeStyle.clock;
  if (days == 1) return InboxTimeStyle.yesterday;
  if (days < 7) return InboxTimeStyle.weekday;
  return InboxTimeStyle.date;
}
