import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('alarmMetaLine', () {
    test('is the time alone when the message has no tags', () {
      expect(alarmMetaLine(time: '13:30', tags: const []), '13:30');
    });

    test('puts one tag after the time', () {
      expect(
        alarmMetaLine(time: '13:30', tags: const ['critical']),
        '13:30 / critical',
      );
    });

    test('joins two tags with a comma', () {
      expect(
        alarmMetaLine(time: '13:30', tags: const ['critical', 'db']),
        '13:30 / critical, db',
      );
    });
  });
}
