import 'package:critalarm/design/components/picker_rows.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const options = [
    AppPickerOption<String?>(value: null, label: 'Remote decides'),
    AppPickerOption<String?>(value: 'a', label: 'First'),
    AppPickerOption<String?>(value: 'b', label: 'Second'),
  ];

  group('pickerValueText', () {
    test('shows the label of the selected option', () {
      expect(
        pickerValueText(options: options, selected: 'b', hasSelection: true),
        'Second',
      );
    });

    test('a null value is a choice like any other', () {
      expect(
        pickerValueText(options: options, selected: null, hasSelection: true),
        'Remote decides',
      );
    });

    test('a value text given by the caller wins', () {
      expect(
        pickerValueText(
          options: options,
          selected: 'a',
          hasSelection: true,
          valueText: 'Mine',
        ),
        'Mine',
      );
    });

    test('a list of things to open shows no value', () {
      expect(
        pickerValueText(options: options, selected: null, hasSelection: false),
        isNull,
      );
    });

    test('a value no option holds shows nothing', () {
      expect(
        pickerValueText(options: options, selected: 'z', hasSelection: true),
        isNull,
      );
    });
  });

  group('pickerSheetScrolls', () {
    test('a short list opens at its natural height', () {
      expect(pickerSheetScrolls(1), isFalse);
      expect(pickerSheetScrolls(pickerSheetFixedLimit), isFalse);
    });

    test('a longer list opens the sheet that scrolls', () {
      expect(pickerSheetScrolls(pickerSheetFixedLimit + 1), isTrue);
    });
  });
}
