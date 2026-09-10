/// Whole-calendar-day arithmetic that is immune to time-of-day and DST.
///
/// The trick both helpers share: anchor a date's *local* year/month/day on the
/// UTC number line. UTC has no daylight-saving jumps, so the gap between two
/// such instants is always an exact multiple of 24h and `.inDays` never
/// truncates. Plain `DateTime(y, m, d)` local midnights sit 23h/25h apart
/// across a DST transition, so `difference(...).inDays` silently drops a day —
/// the recurring streak/bucket/countdown bug this module exists to prevent.
library;

/// Midnight of [date]'s calendar day, anchored in UTC (see library doc).
///
/// Reads only the year/month/day, so the time of day is discarded. Use this
/// wherever whole-day differences are computed — never `DateTime(y, m, d)`.
DateTime dateOnlyUtc(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

/// Whole calendar days from [from]'s day to [to]'s day (`to - from`); negative
/// when [to] precedes [from]. Ignores the time of day and stays exact across
/// DST transitions.
int calendarDaysBetween(DateTime from, DateTime to) =>
    dateOnlyUtc(to).difference(dateOnlyUtc(from)).inDays;
