import 'package:critalarm/features/local_reminders/domain/local_reminder_copy.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_ids.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_kind.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_lab_samples.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fireAt = DateTime(2026, 9, 22, 12, 0, 10);

  test('every kind has a sample that fills its copy', () {
    for (final kind in LocalReminderKind.values) {
      final request = const LocalReminderCopy(
        isIos: true,
      ).build(LocalReminderLabSamples.candidate(kind, fireAt));
      expect(request.title, isNot(contains('{')), reason: kind.name);
      expect(request.body, isNot(contains('{')), reason: kind.name);
    }
  });

  test('lab fires use lab ids a plan pass never cancels', () {
    for (final kind in LocalReminderKind.values) {
      final id = LocalReminderLabSamples.candidate(kind, fireAt).id;
      expect(id, LocalReminderIds.lab(kind));
      expect(LocalReminderIds.isPlanned(id), isFalse);
    }
  });

  test('the pool preview has all ten drill lines', () {
    final pool = LocalReminderLabSamples.drillPool(fireAt);
    expect(pool.map((c) => c.poolIndex), [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
  });
}
