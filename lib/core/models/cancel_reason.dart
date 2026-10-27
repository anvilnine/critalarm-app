/// Why a person cancelled the Cloud plan. The wire names are the contract's
/// (api.md §3.9) and the order is the order of the chips on the sheet.
enum CancelReason {
  price('price'),
  unused('unused'),
  selfhost('selfhost'),
  missing('missing'),
  broken('broken'),
  other('other');

  const CancelReason(this.wire);

  final String wire;

  static CancelReason? fromWire(String? value) {
    for (final reason in values) {
      if (reason.wire == value) return reason;
    }
    return null;
  }
}

/// The most characters the optional text may hold (api.md §3.9).
const int kCancelTextMaxChars = 500;

/// True for a UTF-16 code unit that JavaScript's `String.prototype.trim()`
/// removes: ECMAScript white space (tab, vertical tab, form feed, the
/// Unicode space separators and the byte order mark) and line terminators.
/// Dart's own `trim()` also removes U+0085, which JavaScript keeps, so it
/// cannot be used here.
bool _isTrimmedByServer(int unit) {
  switch (unit) {
    case 0x0009:
    case 0x000A:
    case 0x000B:
    case 0x000C:
    case 0x000D:
    case 0x0020:
    case 0x00A0:
    case 0x1680:
    case 0x2028:
    case 0x2029:
    case 0x202F:
    case 0x205F:
    case 0x3000:
    case 0xFEFF:
      return true;
  }
  return unit >= 0x2000 && unit <= 0x200A;
}

/// Trims the ends of [raw] exactly as the server does before it counts the
/// text (api.md §3.9, "trimmed").
String trimCancelText(String raw) {
  var start = 0;
  var end = raw.length;
  while (start < end && _isTrimmedByServer(raw.codeUnitAt(start))) {
    start += 1;
  }
  while (end > start && _isTrimmedByServer(raw.codeUnitAt(end - 1))) {
    end -= 1;
  }
  return raw.substring(start, end);
}

/// The text as it is sent: trimmed the way the server trims, nothing when
/// empty, and cut to [kCancelTextMaxChars] characters. An emoji counts as one
/// and is never split, because the server counts code points.
String? cleanCancelText(String raw) {
  final trimmed = trimCancelText(raw);
  if (trimmed.isEmpty) return null;
  final runes = trimmed.runes;
  if (runes.length <= kCancelTextMaxChars) return trimmed;
  return String.fromCharCodes(runes.take(kCancelTextMaxChars));
}
