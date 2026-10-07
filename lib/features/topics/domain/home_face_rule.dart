import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';

class HomeHero {
  const HomeHero({
    required this.faceState,
    required this.word,
    required this.subText,
    required this.severity,
    this.ringingIncidentId,
  });

  final FaceState faceState;
  final String word;
  final String subText;
  final SeverityMode severity;
  final String? ringingIncidentId;
}

class HomeTopicRow {
  const HomeTopicRow({
    required this.name,
    required this.faceState,
    required this.meta,
  });

  final String name;
  final FaceState faceState;
  final String meta;
}

class HomeFaceResult {
  const HomeFaceResult({required this.hero, required this.rows});

  final HomeHero hero;
  final List<HomeTopicRow> rows;

  bool get hasAckedRow => rows.any((r) => r.faceState == FaceState.acked);

  /// True while the face changes on its own as time passes: a desk timer
  /// counting down, or a HANDLED face that only lasts a while.
  bool get needsTick => hasAckedRow || hero.faceState == FaceState.success;
}

/// How long the big face says HANDLED after a close before it goes back to
/// the resting face. The row keeps the handled time for the hour.
const handledFaceWindow = Duration(seconds: 30);

HomeFaceResult resolveHomeFace({
  required List<Topic> topics,
  required List<Incident> incidents,
  required Set<String> warningTopics,
  required DateTime now,
}) {
  String formatHm(DateTime dt) => DateFormat.Hm().format(dt.toLocal());

  String relativeAgo(DateTime from) {
    final diff = now.difference(from);
    final mins = diff.inMinutes;
    if (mins < 1) return 'just now';
    if (mins == 1) return '1 min ago';
    return '$mins min ago';
  }

  final topicByName = {for (final t in topics) t.name: t};

  Incident? alarmedIncident;
  for (final inc in incidents) {
    if (inc.state != IncidentStates.open) continue;
    if (!inc.messages.any((m) => m.priority == 5)) continue;
    if (alarmedIncident == null) {
      alarmedIncident = inc;
    } else {
      final aTime = alarmedIncident.openedAt;
      final bTime = inc.openedAt;
      if (aTime != null && bTime != null && bTime.isAfter(aTime)) {
        alarmedIncident = inc;
      }
    }
  }

  final hasCriticalOpen = alarmedIncident != null;
  final hasWarningOpen = warningTopics.isNotEmpty;

  final ackedEntries =
      <
        ({String topic, Incident incident, DateTime ackedAt, DateTime deadline})
      >[];
  for (final inc in incidents) {
    if (inc.state != IncidentStates.acked) continue;
    final ackedAt = inc.ackedAt;
    if (ackedAt == null) continue;
    final deskS = topicByName[inc.topic]?.deskTimerS ?? 600;
    final deadline = ackedAt.add(Duration(seconds: deskS));
    if (now.isBefore(deadline)) {
      ackedEntries.add((
        topic: inc.topic,
        incident: inc,
        ackedAt: ackedAt,
        deadline: deadline,
      ));
    }
  }

  final handledEntries =
      <({String topic, Incident incident, DateTime closedAt})>[];
  for (final inc in incidents) {
    final closedAt = inc.closedAt;
    if (closedAt == null) continue;
    final isHandled =
        inc.state == IncidentStates.closed ||
        inc.state == IncidentStates.expired;
    if (!isHandled) continue;
    if (now.difference(closedAt).inSeconds < 3600) {
      handledEntries.add((topic: inc.topic, incident: inc, closedAt: closedAt));
    }
  }

  List<HomeTopicRow> buildRows() {
    return topics.map((t) {
      final openP5 = incidents.any(
        (i) =>
            i.topic == t.name &&
            i.state == IncidentStates.open &&
            i.messages.any((m) => m.priority == 5),
      );
      if (openP5) {
        return HomeTopicRow(
          name: t.name,
          faceState: FaceState.alarmed,
          meta: LocaleKeys.home_meta_alert_active.tr(),
        );
      }
      if (warningTopics.contains(t.name)) {
        return HomeTopicRow(
          name: t.name,
          faceState: FaceState.worried,
          meta: LocaleKeys.home_meta_warning.tr(),
        );
      }
      final acked = ackedEntries.where((a) => a.topic == t.name).toList();
      if (acked.isNotEmpty) {
        acked.sort((a, b) => b.ackedAt.compareTo(a.ackedAt));
        final entry = acked.first;
        final ago = relativeAgo(entry.ackedAt);
        return HomeTopicRow(
          name: t.name,
          faceState: FaceState.acked,
          meta: LocaleKeys.home_meta_acknowledged.tr(namedArgs: {'time': ago}),
        );
      }
      final handled = handledEntries.where((h) => h.topic == t.name).toList();
      if (handled.isNotEmpty) {
        handled.sort((a, b) => b.closedAt.compareTo(a.closedAt));
        final entry = handled.first;
        // An alarm that ran out was not handled by anyone. The row says the
        // plain fact with a resting face, and the missed alarm notice owns
        // the rest.
        if (entry.incident.state == IncidentStates.expired) {
          return HomeTopicRow(
            name: t.name,
            faceState: FaceState.calm,
            meta: LocaleKeys.notices_missed_alarm_reason_unanswered.tr(),
          );
        }
        final time = formatHm(entry.closedAt);
        return HomeTopicRow(
          name: t.name,
          faceState: FaceState.success,
          meta: LocaleKeys.home_meta_handled.tr(namedArgs: {'time': time}),
        );
      }
      return HomeTopicRow(
        name: t.name,
        faceState: FaceState.calm,
        meta: LocaleKeys.home_meta_quiet.tr(),
      );
    }).toList();
  }

  final rows = buildRows();

  if (hasCriticalOpen) {
    return HomeFaceResult(
      hero: HomeHero(
        faceState: FaceState.alarmed,
        word: LocaleKeys.home_stage_word_critical.tr(),
        subText: LocaleKeys.home_stage_sub_critical.tr(
          namedArgs: {'topic': alarmedIncident.topic},
        ),
        severity: SeverityMode.crit,
        ringingIncidentId: alarmedIncident.id,
      ),
      rows: rows,
    );
  }
  if (hasWarningOpen) {
    final warningCount = warningTopics.length;
    return HomeFaceResult(
      hero: HomeHero(
        faceState: FaceState.worried,
        word: LocaleKeys.home_stage_word_warning.plural(warningCount),
        subText: LocaleKeys.home_stage_sub_warning.plural(
          warningCount,
          namedArgs: {
            'count': topics.length.toString(),
            'warnings': warningCount.toString(),
          },
        ),
        severity: SeverityMode.high,
      ),
      rows: rows,
    );
  }
  if (ackedEntries.isNotEmpty) {
    ackedEntries.sort((a, b) => b.ackedAt.compareTo(a.ackedAt));
    final entry = ackedEntries.first;
    final remaining = entry.deadline.difference(now);
    final mins = (remaining.inSeconds / 60).ceil().clamp(1, 1000000);
    return HomeFaceResult(
      hero: HomeHero(
        faceState: FaceState.acked,
        word: LocaleKeys.home_stage_word_acknowledged.tr(),
        subText: LocaleKeys.home_stage_sub_acknowledged.tr(
          namedArgs: {'topic': entry.topic, 'minutes': '$mins'},
        ),
        severity: SeverityMode.ack,
      ),
      rows: rows,
    );
  }
  // A close is a moment, so the face only says HANDLED for a short while.
  // An alarm that ran out is not a close: Home says it in the missed alarm
  // notice, which has the gates this rule lacks, and never in the hero.
  final heroEntries = handledEntries
      .where(
        (h) =>
            h.incident.state == IncidentStates.closed &&
            now.difference(h.closedAt) < handledFaceWindow,
      )
      .toList();
  if (heroEntries.isNotEmpty) {
    heroEntries.sort((a, b) => b.closedAt.compareTo(a.closedAt));
    final entry = heroEntries.first;
    final time = formatHm(entry.closedAt);
    return HomeFaceResult(
      hero: HomeHero(
        faceState: FaceState.success,
        word: LocaleKeys.home_stage_word_handled.tr(),
        subText: LocaleKeys.home_stage_sub_handled.tr(
          namedArgs: {'topic': entry.topic, 'time': time},
        ),
        severity: SeverityMode.none,
      ),
      rows: rows,
    );
  }

  // Only a close counts as "handled". An alarm that ran out was not.
  DateTime? newestClosed;
  for (final inc in incidents) {
    if (inc.state == IncidentStates.closed && inc.closedAt != null) {
      if (newestClosed == null || inc.closedAt!.isAfter(newestClosed)) {
        newestClosed = inc.closedAt;
      }
    }
  }
  var sub = LocaleKeys.home_no_alarm_body.tr();
  if (newestClosed != null) {
    final localClosed = newestClosed.toLocal();
    final localNow = now.toLocal();
    final isToday =
        localClosed.year == localNow.year &&
        localClosed.month == localNow.month &&
        localClosed.day == localNow.day;
    // No existing key shows a date, so add month and day only when the last
    // close was not today, and keep the same time format used everywhere
    // else in this file.
    final time = isToday
        ? formatHm(newestClosed)
        : '${DateFormat.MMMd().format(localClosed)}, ${formatHm(newestClosed)}';
    sub =
        '${LocaleKeys.home_no_alarm_body.tr()}\n'
        '${LocaleKeys.home_no_alarm_last.tr(namedArgs: {'time': time})}';
  }

  return HomeFaceResult(
    hero: HomeHero(
      faceState: FaceState.calm,
      word: LocaleKeys.home_stage_word_clear.tr(),
      subText: sub,
      severity: SeverityMode.none,
    ),
    rows: rows,
  );
}

/// The hero while Home's missed alarm notice is in the slot.
///
/// The notice says an alarm was missed, so a glad face over "All clear"
/// would contradict it. The resting hero (calm, or the short HANDLED
/// moment) drops to a calm face and the one line that is still true.
/// Anything live, a ringing, acknowledged or warning hero, is returned
/// unchanged: a quiet hero never hides an alarm.
HomeHero heroWhileMissedNoticeShows(HomeHero hero) {
  final isResting =
      hero.faceState == FaceState.calm || hero.faceState == FaceState.success;
  if (!isResting || hero.ringingIncidentId != null) return hero;
  return HomeHero(
    faceState: FaceState.calm,
    word: '',
    subText: LocaleKeys.home_no_alarm_body.tr(),
    severity: SeverityMode.none,
  );
}
