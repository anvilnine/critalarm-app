import 'package:critalarm/features/reminders/domain/reminder_copy.dart';
import 'package:critalarm/features/reminders/domain/reminder_ids.dart';
import 'package:critalarm/features/reminders/domain/reminder_kind.dart';
import 'package:critalarm/features/reminders/domain/reminder_lab_samples.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fireAt = DateTime(2026, 9, 22, 12, 0, 10);

  test('every kind has a sample that fills its copy', () {
    for (final kind in ReminderKind.values) {
      final request = const ReminderCopy(
        isIos: true,
      ).build(ReminderLabSamples.candidate(kind, fireAt));
      expect(request.title, isNot(contains('{')), reason: kind.name);
      expect(request.body, isNot(contains('{')), reason: kind.name);
    }
  });

  test('lab fires use lab ids a plan pass never cancels', () {
    for (final kind in ReminderKind.values) {
      final id = ReminderLabSamples.candidate(kind, fireAt).id;
      expect(id, ReminderIds.lab(kind));
      expect(ReminderIds.isPlanned(id), isFalse);
    }
  });

  test('the pool preview has all ten drill lines', () {
    final pool = ReminderLabSamples.drillPool(fireAt);
    expect(pool.map((c) => c.poolIndex), [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
  });
}
