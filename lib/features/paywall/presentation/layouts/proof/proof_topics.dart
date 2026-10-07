import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// One row of the topic list the Proof layout draws.
@immutable
class ProofTopic {
  const ProofTopic(this.name, {this.rings = false});

  /// The topic name, as a machine would read it.
  final String name;

  /// Whether Critical delivery is on for it.
  final bool rings;

  @override
  bool operator ==(Object other) =>
      other is ProofTopic && other.name == name && other.rings == rings;

  @override
  int get hashCode => Object.hash(name, rings);

  @override
  String toString() => 'ProofTopic($name, rings: $rings)';
}

/// The list drawn when no real one is handed in.
const List<ProofTopic> proofDemoTopics = [
  ProofTopic('prod-db', rings: true), // l10n-ok: demo data
  ProofTopic('uptime-kuma', rings: true), // l10n-ok: demo data
  ProofTopic('nas-backup'), // l10n-ok: demo data
  ProofTopic('home-ha'), // l10n-ok: demo data
];

/// The fewest rows the list is ever drawn with: the ones that ring and one
/// that is refused only tell the story with a third row to compare.
const int proofMinRows = 3;

/// Turns any topic list into the [rows] rows the layout draws.
///
/// The drawing replays the free cap, so it always has the same shape: the
/// first [cap] rows ring and every row after them is one the cap refuses.
/// - Topics that ring come first, in the order given, then the others.
/// - A short list is padded with demo names it does not already hold.
/// - A long list is trimmed.
/// - There are never fewer than [proofMinRows] rows, and never a list with
///   no refused row.
List<ProofTopic> proofTopicsFor(
  List<ProofTopic> input, {
  int rows = 4,
  int cap = 2,
}) {
  final count = math.max(proofMinRows, rows);
  final ringing = math.min(math.max(cap, 1), count - 1);

  final names = <String>[];
  void add(String name) {
    final clean = name.trim();
    if (clean.isEmpty || names.contains(clean)) return;
    names.add(clean);
  }

  for (final topic in input) {
    if (topic.rings) add(topic.name);
  }
  // More ringing topics than the cap allows can only be left over from a
  // plan that ended. They are drawn after the cap, as refused rows.
  final overCap = names.length > ringing
      ? names.sublist(ringing)
      : const <String>[];
  if (overCap.isNotEmpty) names.removeRange(ringing, names.length);
  final quiet = <String>[
    ...overCap,
    for (final topic in input)
      if (!topic.rings) topic.name,
  ];
  // Fill the ringing rows first, so a quiet topic is never drawn ringing
  // while a demo name could take that row.
  for (final demo in proofDemoTopics) {
    if (names.length >= ringing) break;
    if (!quiet.contains(demo.name)) add(demo.name);
  }
  quiet.forEach(add);
  for (final demo in proofDemoTopics) {
    if (names.length >= count) break;
    add(demo.name);
  }
  // Only reached when the demo names ran out, which a caller asking for
  // more rows than there are demo names can do.
  for (var i = 1; names.length < count; i++) {
    add('topic-$i'); // l10n-ok: demo data
  }

  return [
    for (final (i, name) in names.take(count).indexed)
      ProofTopic(name, rings: i < ringing),
  ];
}
