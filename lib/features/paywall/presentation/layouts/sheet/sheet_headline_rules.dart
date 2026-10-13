import 'package:flutter/widgets.dart';

// The words the Sheet puts over its list when it leads with the critical
// topic limit. Pure rules: the layout measures what they cannot know.

String _norm(String text) => text
    .toLowerCase()
    .replaceAll(RegExp('[^a-z0-9 ]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// The longest topic name, in characters, the headline will say. A longer
/// one reads as noise in a headline, so the headline has no name.
const int sheetHeadlineNameMax = 16;

/// [name] as the headline says it, or null when the headline has no name:
/// there is none, or it is longer than [sheetHeadlineNameMax] characters.
/// An emoji or an accent counts as one.
String? sheetHeadlineName(String? name) =>
    name == null ||
        name.isEmpty ||
        name.characters.length > sheetHeadlineNameMax
    ? null
    : name;

/// The two headlines the topics lead can have.
enum SheetTopicHeadline {
  /// "Make billing-api critical".
  named,

  /// "Make this topic critical".
  generic,
}

/// Which headline the topics lead gets. [fits] is whether the named
/// headline fits in two lines. The layout measures it. No name, a name
/// over [sheetHeadlineNameMax] characters, or no fit, is the generic one.
SheetTopicHeadline sheetTopicHeadlineFor({
  required String? name,
  required bool fits,
}) => sheetHeadlineName(name) == null || !fits
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
