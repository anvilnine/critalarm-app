import 'package:flutter/widgets.dart';

// The words the Sheet puts over its list when it leads with the critical
// topic limit. Pure rules: the layout measures what they cannot know.

String _norm(String text) => text
    .toLowerCase()
    .replaceAll(RegExp('[^a-z0-9 ]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// [name] cut to at most [max] characters by taking out its middle, which
/// is replaced by one ellipsis. Both ends stay, so a name that begins or
/// ends alike with another still tells them apart. An emoji or an accent
/// is never split.
String middleEllipsis(String name, {int max = 16}) {
  final chars = name.characters;
  if (chars.length <= max) return name;
  final keep = max - 1;
  final head = (keep / 2).ceil();
  final tail = keep - head;
  return '${chars.take(head)}…${chars.takeLast(tail)}';
}

/// The two headlines the topics lead can have.
enum SheetTopicHeadline {
  /// "Make billing-api critical".
  named,

  /// "Make this topic critical".
  generic,
}

/// Which headline the topics lead gets. [fits] is whether the named
/// headline, with the name cut by [middleEllipsis], fits in two lines. The
/// layout measures it. No name, or no fit, is the generic one.
SheetTopicHeadline sheetTopicHeadlineFor({
  required String? name,
  required bool fits,
}) => name == null || name.isEmpty || !fits
    ? SheetTopicHeadline.generic
    : SheetTopicHeadline.named;

/// True when [headline] says what one of [tapped] (the sentences on the
/// card the person tapped) already says. Case and punctuation do not count.
bool sheetHeadlineRepeats(String headline, Iterable<String> tapped) {
  final h = _norm(headline);
  if (h.isEmpty) return false;
  for (final text in tapped) {
    final t = _norm(text);
    if (t.isEmpty) continue;
    if (t == h || t.contains(h) || h.contains(t)) return true;
  }
  return false;
}

/// Whether a check line for the lead is drawn under the headline. It goes
/// when a tag already says the lead, or when the headline says it.
bool sheetShowsLeadLine({
  required bool hasTag,
  required String headline,
  required String leadLine,
}) {
  if (hasTag) return false;
  final h = _norm(headline);
  final l = _norm(leadLine);
  if (l.isEmpty) return false;
  return !(h.contains(l) || l.contains(h));
}
