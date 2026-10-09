/// The words of the alert title a person types, and whether they typed them.
///
/// This is a plain string comparison between two pieces of text that are
/// both on the same screen, on the phone: the title the alarm screen already
/// shows, and what the person types under it. It does not read a message, it
/// does not look for meaning, and nothing here is logged or sent anywhere.
/// The app still never inspects content: it only checks that someone copied
/// what they were looking at.
///
/// A word is a run of characters between spaces. Punctuation and symbols at
/// its edges are dropped ("(nas)" is "nas", "disk:" is "disk"), and a word
/// that is only punctuation or an emoji is not a word at all, because it
/// is hard to type on a phone keyboard. Capitals do not matter.
library;

/// How many words of the title are asked for.
const int alertTitleWordCount = 3;

final RegExp _edgeSymbols = RegExp(
  r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$',
  unicode: true,
);
final RegExp _spaces = RegExp(r'\s+');

String _clean(String word) => word.replaceAll(_edgeSymbols, '').toLowerCase();

/// The words of [text], lowercase, edge symbols dropped, in order.
List<String> _words(String text) => [
  for (final raw in text.trim().split(_spaces))
    if (_clean(raw).isNotEmpty) _clean(raw),
];

/// The words [title] asks for: its first [alertTitleWordCount], or all of
/// them when it has fewer. Empty when the title has no word at all.
List<String> alertTitleWordsToType(String? title) {
  if (title == null) return const [];
  final words = _words(title);
  return words.length <= alertTitleWordCount
      ? words
      : words.sublist(0, alertTitleWordCount);
}

/// Whether [typed] is the first words of [title].
///
/// Case, outer spaces, runs of spaces and punctuation at word edges do not
/// matter. Typing less, more, or a different word does not match. A title
/// with no word never matches, so nothing passes by typing nothing.
bool alertTitleMatches({required String typed, required String? title}) {
  final want = alertTitleWordsToType(title);
  if (want.isEmpty) return false;
  final got = _words(typed);
  if (got.length != want.length) return false;
  for (var i = 0; i < want.length; i++) {
    if (got[i] != want[i]) return false;
  }
  return true;
}

/// A piece of the title for drawing: `isAsked` is true for the words to
/// type, so the screen can set them apart from the rest.
typedef AlertTitlePart = ({String text, bool isAsked});

/// [title] cut into pieces, spaces kept, so the pieces joined are the title
/// exactly. A long title is never shortened.
List<AlertTitlePart> alertTitleParts(String title) {
  final parts = <AlertTitlePart>[];
  var asked = 0;
  var last = 0;
  for (final match in RegExp(r'\S+').allMatches(title)) {
    if (match.start > last) {
      parts.add((text: title.substring(last, match.start), isAsked: false));
    }
    final isWord = _clean(match.group(0)!).isNotEmpty;
    final isAsked = isWord && asked < alertTitleWordCount;
    if (isAsked) asked++;
    parts.add((text: match.group(0)!, isAsked: isAsked));
    last = match.end;
  }
  if (last < title.length) {
    parts.add((text: title.substring(last), isAsked: false));
  }
  return parts;
}
