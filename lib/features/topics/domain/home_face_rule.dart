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
}

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
  if (handledEntries.isNotEmpty) {
    handledEntries.sort((a, b) => b.closedAt.compareTo(a.closedAt));
    final entry = handledEntries.first;
    final isExpired = entry.incident.state == IncidentStates.expired;
    final time = formatHm(entry.closedAt);
    return HomeFaceResult(
      hero: HomeHero(
        faceState: FaceState.success,
        word: isExpired
            ? LocaleKeys.home_stage_word_missed.tr()
            : LocaleKeys.home_stage_word_handled.tr(),
        subText: isExpired
            ? LocaleKeys.home_stage_sub_missed.tr(
                namedArgs: {'topic': entry.topic},
              )
            : LocaleKeys.home_stage_sub_handled.tr(
                namedArgs: {'topic': entry.topic, 'time': time},
              ),
        severity: SeverityMode.none,
      ),
      rows: rows,
    );
  }

  DateTime? newestClosedWithinHour;
  for (final inc in incidents) {
    if ((inc.state == IncidentStates.closed ||
            inc.state == IncidentStates.expired) &&
        inc.closedAt != null) {
      if (now.difference(inc.closedAt!).inSeconds < 3600) {
        if (newestClosedWithinHour == null ||
            inc.closedAt!.isAfter(newestClosedWithinHour)) {
          newestClosedWithinHour = inc.closedAt;
        }
      }
    }
  }
  String sub = LocaleKeys.home_no_alarm_body.tr();
  if (newestClosedWithinHour != null) {
    final time = formatHm(newestClosedWithinHour);
    sub =
        '${LocaleKeys.home_no_alarm_body.tr()}\n${LocaleKeys.home_no_alarm_last.tr(namedArgs: {'time': time})}';
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
