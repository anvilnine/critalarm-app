import 'package:critalarm/features/topics/domain/topic_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 9, 14, 30);

  test('a topic with nothing in it has an empty summary', () {
    final summary = topicSummaryFor(
      messageTimes: const [],
      lastAlarmAt: null,
      now: now,
    );
    expect(summary.isEmpty, isTrue);
    expect(summary.today, 0);
  });

  test('counts only the messages that arrived today', () {
    final summary = topicSummaryFor(
      messageTimes: [
        DateTime(2026, 10, 9, 0, 46),
        DateTime(2026, 10, 9, 0, 42),
        DateTime(2026, 10, 8, 23, 59),
        DateTime(2026, 10, 1, 9),
      ],
      lastAlarmAt: null,
      now: now,
    );
    expect(summary.today, 2);
    expect(summary.hasAnyMessage, isTrue);
    expect(summary.isEmpty, isFalse);
  });

  test('messages from other days leave today at zero', () {
    final summary = topicSummaryFor(
      messageTimes: [DateTime(2026, 10, 8, 12)],
      lastAlarmAt: null,
      now: now,
    );
    expect(summary.today, 0);
    expect(summary.hasAnyMessage, isTrue);
  });

  test('an alarm from today shows as a clock time', () {
    final alarm = DateTime(2026, 10, 9, 0, 46);
    final summary = topicSummaryFor(
      messageTimes: [alarm],
      lastAlarmAt: alarm,
      now: now,
    );
    expect(summary.lastAlarmAt, alarm);
    expect(summary.lastAlarmIsToday, isTrue);
  });

  test('an older alarm shows as a date', () {
    final alarm = DateTime(2026, 9, 16, 8);
    final summary = topicSummaryFor(
      messageTimes: const [],
      lastAlarmAt: alarm,
      now: now,
    );
    expect(summary.lastAlarmIsToday, isFalse);
    expect(summary.isEmpty, isFalse);
  });

  test('the day is the local one, whatever zone the time arrives in', () {
    final late = DateTime(2026, 10, 9, 23, 30).toUtc();
    final summary = topicSummaryFor(
      messageTimes: [late],
      lastAlarmAt: late,
      now: DateTime(2026, 10, 9, 23, 45),
    );
    expect(summary.today, 1);
    expect(summary.lastAlarmIsToday, isTrue);
  });
}
