/// Reads a date out of a search query, so typing "sep 14" finds that day's
/// alarms.
///
/// Deliberately narrow. Bare numeric forms like "9/14" are not supported,
/// because there is no way to tell a month from a day without guessing the
/// user's locale, and guessing wrong silently shows the wrong alarms.
///
/// Understood: "today", "yesterday", "2026-09-14", "2026/9/14", "sep 14",
/// "sept 14th", "september 14, 2026", "14 sep", "14 september 2026".
abstract final class QueryDate {
  static const Map<String, int> _months = <String, int>{
    'january': 1,
    'jan': 1,
    'february': 2,
    'feb': 2,
    'march': 3,
    'mar': 3,
    'april': 4,
    'apr': 4,
    'may': 5,
    'june': 6,
    'jun': 6,
    'july': 7,
    'jul': 7,
    'august': 8,
    'aug': 8,
    'september': 9,
    'sept': 9,
    'sep': 9,
    'october': 10,
    'oct': 10,
    'november': 11,
    'nov': 11,
    'december': 12,
    'dec': 12,
  };

  static final RegExp _iso = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$');
  static final RegExp _monthFirst = RegExp(
    r'^([a-z]+)\.?\s+(\d{1,2})(?:st|nd|rd|th)?(?:,?\s+(\d{4}))?$',
  );
  static final RegExp _dayFirst = RegExp(
    r'^(\d{1,2})(?:st|nd|rd|th)?\s+([a-z]+)\.?(?:,?\s+(\d{4}))?$',
  );

  /// The day [query] names, at midnight, or null when it names no day.
  static DateTime? parse(String query, {required DateTime now}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;

    final today = DateTime(now.year, now.month, now.day);
    if (q == 'today') return today;
    if (q == 'yesterday') return today.subtract(const Duration(days: 1));

    final iso = _iso.firstMatch(q);
    if (iso != null) {
      return _build(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    }

    final monthFirst = _monthFirst.firstMatch(q);
    if (monthFirst != null) {
      final month = _months[monthFirst.group(1)!];
      if (month != null) {
        final day = int.parse(monthFirst.group(2)!);
        final year = monthFirst.group(3) == null
            ? _yearFor(month, day, now)
            : int.parse(monthFirst.group(3)!);
        return _build(year, month, day);
      }
    }

    final dayFirst = _dayFirst.firstMatch(q);
    if (dayFirst != null) {
      final month = _months[dayFirst.group(2)!];
      if (month != null) {
        final day = int.parse(dayFirst.group(1)!);
        final year = dayFirst.group(3) == null
            ? _yearFor(month, day, now)
            : int.parse(dayFirst.group(3)!);
        return _build(year, month, day);
      }
    }

    return null;
  }

  /// With no year typed, pick the most recent one. History only looks back, so
  /// a date that would land in the future belongs to last year.
  static int _yearFor(int month, int day, DateTime now) {
    final thisYear = DateTime(now.year, month, day);
    final today = DateTime(now.year, now.month, now.day);
    return thisYear.isAfter(today) ? now.year - 1 : now.year;
  }

  /// Rejects a day that does not exist. DateTime rolls Feb 31 forward into
  /// March instead of failing, so compare the parts back.
  static DateTime? _build(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }
}
