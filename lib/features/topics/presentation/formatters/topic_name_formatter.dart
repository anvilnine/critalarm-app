import 'package:flutter/services.dart';

/// Formats topic name input:
/// 1. Converts uppercase characters to lowercase automatically.
/// 2. Filters out characters that are not lowercase letters, digits, or
///    hyphens (`[a-z0-9-]`).
/// 3. Enforces a maximum character count (defaults to 100).
/// 4. Maintains valid cursor selection across typing, replacements, and pastes.
class TopicNameInputFormatter extends TextInputFormatter {
  const TopicNameInputFormatter({this.maxLength = 100});

  final int maxLength;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text == oldValue.text) {
      return newValue;
    }

    final lower = newValue.text.toLowerCase();
    final buffer = StringBuffer();
    var newSelectionIndex = newValue.selection.end;

    for (var i = 0; i < lower.length; i++) {
      if (buffer.length >= maxLength) {
        if (i < newSelectionIndex) {
          newSelectionIndex--;
        }
        continue;
      }
      final char = lower[i];
      final code = char.codeUnitAt(0);
      final isAllowed =
          (code >= 97 && code <= 122) || // a-z
          (code >= 48 && code <= 57) || // 0-9
          char == '-';
      if (isAllowed) {
        buffer.write(char);
      } else {
        if (i < newSelectionIndex) {
          newSelectionIndex--;
        }
      }
    }

    final formattedText = buffer.toString();
    final clampedOffset = newSelectionIndex.clamp(0, formattedText.length);

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: clampedOffset),
    );
  }
}
