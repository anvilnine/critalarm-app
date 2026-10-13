import 'package:flutter/foundation.dart';

/// The most rows the picture shows younger than the Free window, and past it.
const int historyOwnMaxInside = 3;
const int historyOwnMaxBeyond = 4;

/// One alarm of the person's own, as the history picture draws it.
@immutable
class HistoryOwnRow {
  const HistoryOwnRow(this.topic, this.ageDays);

  final String topic;
  final int ageDays;
}

/// The person's real rows, for the history picture on a paywall: the few
/// newest inside the Free window, and a few spread across what lies past it.
///
/// The phone keeps rows past the window and only hides them
/// (`HistoryWindow`), so these are rows a purchase shows again. They travel
/// in the paywall's location (`hin`, `hbe`) and go nowhere else: a topic
/// name is the person's own data, drawn on screen and never sent, counted
/// or logged.
@immutable
class HistoryOwn {
  const HistoryOwn({required this.inside, required this.beyond});

  /// Newest first, younger than the Free window.
  final List<HistoryOwnRow> inside;

  /// Newest first, at least as old as the window. Never empty.
  final List<HistoryOwnRow> beyond;

  /// The location's `hin` and `hbe` entries, `topic:age,topic:age`.
  Map<String, String> toQuery() => {
    if (inside.isNotEmpty) 'hin': _write(inside),
    'hbe': _write(beyond),
  };

  static final RegExp _topic = RegExp(r'^[a-z0-9_-]{1,64}$');
  static final RegExp _age = RegExp(r'^[0-9]{1,4}$');

  static String _write(List<HistoryOwnRow> rows) =>
      rows.map((r) => '${r.topic}:${r.ageDays}').join(',');

  static List<HistoryOwnRow> _read(String? text, int max) {
    if (text == null || text.isEmpty) return const [];
    final rows = <HistoryOwnRow>[];
    for (final part in text.split(',')) {
      final at = part.lastIndexOf(':');
      if (at <= 0) continue;
      final topic = part.substring(0, at).trim().toLowerCase();
      final age = part.substring(at + 1);
      if (!_topic.hasMatch(topic) || !_age.hasMatch(age)) continue;
      rows.add(HistoryOwnRow(topic, int.parse(age)));
      if (rows.length == max) break;
    }
    return rows;
  }

  /// The rows a location carries, or null when none lies past the window.
  static HistoryOwn? fromQuery(Map<String, String> query) {
    final beyond = _read(query['hbe'], historyOwnMaxBeyond);
    if (beyond.isEmpty) return null;
    return HistoryOwn(
      inside: _read(query['hin'], historyOwnMaxInside),
      beyond: beyond,
    );
  }
}

/// [count] entries of [rows], the first and the last among them, evenly
/// spread. All of [rows] when it has no more than [count].
List<T> _spread<T>(List<T> rows, int count) {
  if (rows.length <= count) return rows;
  if (count == 1) return [rows.first];
  return [
    for (var i = 0; i < count; i++)
      rows[(i * (rows.length - 1) / (count - 1)).round()],
  ];
}

/// The picture's rows from the alarms the phone holds, or null when none is
/// as old as the window ([freeDays]). With none that old there is nothing
/// to show again, and the paywall draws the made-up picture it always has.
HistoryOwn? historyOwnFrom({
  required Iterable<({String topic, DateTime openedAt})> rows,
  required DateTime now,
  required int freeDays,
}) {
  final aged = [
    for (final row in rows)
      (
        topic: row.topic,
        openedAt: row.openedAt,
        age: now.isBefore(row.openedAt)
            ? 0
            : now.difference(row.openedAt).inDays,
      ),
  ]..sort((a, b) => b.openedAt.compareTo(a.openedAt));
  final inside = [
    for (final row in aged)
      if (row.age < freeDays) HistoryOwnRow(row.topic, row.age),
  ];
  final beyond = [
    for (final row in aged)
      if (row.age >= freeDays) HistoryOwnRow(row.topic, row.age),
  ];
  if (beyond.isEmpty) return null;
  return HistoryOwn(
    inside: inside.take(historyOwnMaxInside).toList(),
    beyond: _spread(beyond, historyOwnMaxBeyond),
  );
}
