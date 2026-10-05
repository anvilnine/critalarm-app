import 'package:critalarm/features/onboarding/presentation/widgets/curl_terminal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('what the terminal has typed so far', () {
    test('plain text is typed a letter at a time', () {
      expect(CurlTerminalCard.typedPart('curl', 0), '');
      expect(CurlTerminalCard.typedPart('curl', 2), 'cu');
      expect(CurlTerminalCard.typedPart('curl', 99), 'curl');
      expect(CurlTerminalCard.lengthOf('curl'), 4);
    });

    test('an emoji in a topic name is typed whole, never cut in half', () {
      const command = 'curl x/\u{1F525}-db';
      // Seven letters, then the emoji, which is two code units.
      expect(CurlTerminalCard.typedPart(command, 7), 'curl x/');
      expect(CurlTerminalCard.typedPart(command, 8), 'curl x/\u{1F525}');
      expect(CurlTerminalCard.lengthOf(command), 11);
      expect(command.length, 12);
    });

    test('a letter with a combining accent is one character', () {
      const command = 'café';
      expect(CurlTerminalCard.lengthOf(command), 4);
      expect(CurlTerminalCard.typedPart(command, 4), command);
      expect(CurlTerminalCard.typedPart(command, 3), 'caf');
    });

    test('a negative count types nothing', () {
      expect(CurlTerminalCard.typedPart('curl', -1), '');
    });
  });
}
