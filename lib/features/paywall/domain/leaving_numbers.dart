import 'package:critalarm/features/paywall/domain/leaving_floors.dart';
import 'package:flutter/foundation.dart';

/// The rows a leaving slip can print, in the order it prints them.
enum LeavingRow { rang, answered, nights, criticalTopics }

/// What a count needs of one alarm.
@immutable
class LeavingAlarm {
  const LeavingAlarm({
    required this.id,
    required this.openedAt,
    required this.isAcked,
  });

  final String id;
  final DateTime openedAt;
  final bool isAcked;
}

/// The person's numbers, counted on the phone. They go in the paywall's
/// location (`rang`, `ans`, `nights`, `crit`, `days`) and nowhere else.
@immutable
class LeavingFacts {
  const LeavingFacts({
    required this.rang,
    required this.answered,
    required this.nights,
    required this.criticalTopics,
    required this.historyDaysHeld,
  });

  final int rang;
  final int answered;
  final int nights;
  final int criticalTopics;

  /// How many days back the oldest row on the phone is.
  final int historyDaysHeld;

  Map<String, String> toQuery() => {
    'rang': '$rang',
    'ans': '$answered',
    'nights': '$nights',
    'crit': '$criticalTopics',
    'days': '$historyDaysHeld',
  };

  static final RegExp _digits = RegExp(r'^[0-9]{1,6}$');

  /// The facts a location carries, or null when any field is missing or is
  /// not a whole number of at most six digits.
  static LeavingFacts? fromQuery(Map<String, String> query) {
    int? read(String key) {
      final value = query[key];
      return value != null && _digits.hasMatch(value) ? int.parse(value) : null;
    }

    final rang = read('rang');
    final answered = read('ans');
    final nights = read('nights');
    final critical = read('crit');
    final days = read('days');
    if (rang == null ||
        answered == null ||
        nights == null ||
        critical == null ||
        days == null) {
      return null;
    }
    return LeavingFacts(
      rang: rang,
      answered: answered,
      nights: nights,
      criticalTopics: critical,
      historyDaysHeld: days,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LeavingFacts &&
      other.rang == rang &&
      other.answered == answered &&
      other.nights == nights &&
      other.criticalTopics == criticalTopics &&
      other.historyDaysHeld == historyDaysHeld;

  @override
  int get hashCode =>
      Object.hash(rang, answered, nights, criticalTopics, historyDaysHeld);
}

/// Counts the person's numbers from the alarms the phone holds.
///
/// Every row the phone holds counts, hidden ones past the plan's window
/// included: the phone only hides them (`HistoryWindow`). [alarms] are the
/// rows opened in the window; rows older than [LeavingFloors.windowDays]
/// before [now] are left out here too, so a caller that passes more is safe.
/// [excludedIds] are alarms setup caused (the test alarms): they say nothing
/// about how the app is used. [oldestOpenedAt] is the oldest row on the
/// phone, in any window.
LeavingFacts leavingFactsFrom({
  required Iterable<LeavingAlarm> alarms,
  required DateTime now,
  required int criticalTopics,
  required DateTime? oldestOpenedAt,
  Set<String> excludedIds = const {},
}) {
  final from = now.subtract(const Duration(days: LeavingFloors.windowDays));
  var rang = 0;
  var answered = 0;
  final nights = <String>{};
  for (final alarm in alarms) {
    if (excludedIds.contains(alarm.id)) continue;
    if (alarm.openedAt.isBefore(from)) continue;
    rang++;
    if (alarm.isAcked) answered++;
    final local = alarm.openedAt.toLocal();
    if (local.hour < LeavingFloors.nightEndsAtHour) {
      nights.add('${local.year}-${local.month}-${local.day}');
    }
  }
  final held = oldestOpenedAt == null
      ? 0
      : now.difference(oldestOpenedAt).inDays;
  return LeavingFacts(
    rang: rang,
    answered: answered,
    nights: nights.length,
    criticalTopics: criticalTopics,
    historyDaysHeld: held < 0 ? 0 : held,
  );
}

@immutable
class LeavingSlipRow {
  const LeavingSlipRow(this.row, this.value);

  final LeavingRow row;
  final int value;
}

/// What the slip prints: the rows that cleared their floor, in the order
/// of the slip, and the one that gets the yellow band.
@immutable
class LeavingSlip {
  const LeavingSlip({required this.rows, required this.strongest});

  final List<LeavingSlipRow> rows;
  final LeavingRow? strongest;

  /// Receipt when at least [LeavingFloors.rowsForReceipt] rows cleared.
  bool get showsReceipt => rows.length >= LeavingFloors.rowsForReceipt;
}

/// The slip for [facts]. A row under its floor is left off.
LeavingSlip leavingSlipFor(LeavingFacts facts) {
  final clears = <LeavingRow, bool>{
    LeavingRow.rang: facts.rang >= LeavingFloors.alarmsRang,
    // answered / rang >= 80 / 100, in whole numbers.
    LeavingRow.answered:
        facts.answered >= LeavingFloors.answered &&
        facts.answered * 100 >= facts.rang * LeavingFloors.answeredPercent,
    LeavingRow.nights: facts.nights >= LeavingFloors.nights,
    LeavingRow.criticalTopics:
        facts.criticalTopics >= LeavingFloors.criticalTopics,
  };
  int valueOf(LeavingRow row) => switch (row) {
    LeavingRow.rang => facts.rang,
    LeavingRow.answered => facts.answered,
    LeavingRow.nights => facts.nights,
    LeavingRow.criticalTopics => facts.criticalTopics,
  };
  const strengthOrder = [
    LeavingRow.nights,
    LeavingRow.rang,
    LeavingRow.criticalTopics,
    LeavingRow.answered,
  ];
  return LeavingSlip(
    rows: [
      for (final row in LeavingRow.values)
        if (clears[row]!) LeavingSlipRow(row, valueOf(row)),
    ],
    strongest: strengthOrder
        .where((row) => clears[row]!)
        .cast<LeavingRow?>()
        .firstOrNull,
  );
}

/// Which of the three critical topics sentences a person reads, by how many
/// critical topics they have on.
enum LeavingCriticalLine { many, one, none }

LeavingCriticalLine leavingCriticalLineFor(int critical) => critical >= 2
    ? LeavingCriticalLine.many
    : critical == 1
    ? LeavingCriticalLine.one
    : LeavingCriticalLine.none;
