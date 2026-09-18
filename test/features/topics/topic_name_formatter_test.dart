import 'package:critalarm/features/topics/presentation/formatters/topic_name_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TopicNameInputFormatter', () {
    const formatter = TopicNameInputFormatter();

    test('automatically converts uppercase to lowercase', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: 'PROD-DB-01',
        selection: TextSelection.collapsed(offset: 10),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, 'prod-db-01');
      expect(result.selection.end, 10);
    });

    test(
      'filters out disallowed characters (spaces, underscores, symbols)',
      () {
        const oldValue = TextEditingValue.empty;
        const newValue = TextEditingValue(
          text: 'my_topic! @123',
          selection: TextSelection.collapsed(offset: 14),
        );

        final result = formatter.formatEditUpdate(oldValue, newValue);
        expect(result.text, 'mytopic123');
        expect(result.selection.end, 10);
      },
    );

    test('allows lowercase letters, digits, and hyphens', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: 'alpha-beta-123',
        selection: TextSelection.collapsed(offset: 14),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, 'alpha-beta-123');
      expect(result.selection.end, 14);
    });

    test('enforces max length of 100 characters', () {
      const longText =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
          'aaaaaaaaaaaaaaaaaaaa';
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: longText,
        selection: TextSelection.collapsed(offset: 120),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text.length, 100);
      expect(result.text, 'a' * 100);
      expect(result.selection.end, 100);
    });

    test('custom max length works as expected', () {
      const customFormatter = TopicNameInputFormatter(maxLength: 10);
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: 'DATABASE-SYSTEM-01',
        selection: TextSelection.collapsed(offset: 18),
      );

      final result = customFormatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, 'database-s');
      expect(result.text.length, 10);
      expect(result.selection.end, 10);
    });
  });
}
