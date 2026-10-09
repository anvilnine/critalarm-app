import 'package:critalarm/core/format/when_label.dart';

/// The route a topic's Tokens page lives at, under [base].
///
/// [base] is `/` for the Home branch and `/history` for the History branch
/// (the same two bases the topic screen is reached from). The topic name is
/// encoded as one path segment, so a name with a space or a slash in it
/// still opens the right topic.
///
/// [startCurlFlow] adds `?curl=1`, which opens the New token sheet with the
/// name filled in as soon as the page builds.
String topicTokensPath(
  String base,
  String topic, {
  bool startCurlFlow = false,
}) {
  final root = base.replaceAll(RegExp(r'/+$'), '');
  final query = startCurlFlow ? '?curl=1' : '';
  return '$root/topics/${Uri.encodeComponent(topic)}/tokens$query';
}

/// The meta line under a token's name: "Made just now", "Made 11:17",
/// "Made yesterday" or "Made 8 Oct".
///
/// A token that was just made in this session has no date from the server
/// yet, so [createdAt] is null and the line says so. Every other case is
/// [formatWhen]: the time today, the word [yesterday] for the day before,
/// and the day and month for anything older.
///
/// The words come in as arguments because a pure function holds no
/// strings: [madeJustNow] is the whole line for a null date, [madeOn] wraps
/// the date or time, and [yesterday] is the lower-case word used inside it.
String tokenMadeLine({
  required DateTime? createdAt,
  required DateTime now,
  required String madeJustNow,
  required String Function(String when) madeOn,
  required String yesterday,
}) {
  if (createdAt == null) return madeJustNow;
  return madeOn(formatWhen(at: createdAt, now: now, yesterday: yesterday));
}
