import 'package:critalarm/features/topics/domain/home_card/first_message_expected.dart';
import 'package:flutter_test/flutter_test.dart';

bool _expected({
  bool hasServer = true,
  bool wasSetUpHere = true,
  bool isChecklistRetired = false,
  bool isFirstMessageReceived = false,
}) => firstMessageExpected(
  hasServer: hasServer,
  wasSetUpHere: wasSetUpHere,
  isChecklistRetired: isChecklistRetired,
  isFirstMessageReceived: isFirstMessageReceived,
);

void main() {
  group('firstMessageExpected', () {
    test('a phone that finished setup and has no message yet expects one', () {
      expect(_expected(), isTrue);
    });

    test('no saved server means nothing to wait for', () {
      expect(_expected(hasServer: false), isFalse);
    });

    test('a phone set up before the checklist existed is not guessed at', () {
      expect(_expected(wasSetUpHere: false), isFalse);
    });

    test('a retired checklist never comes back', () {
      expect(_expected(isChecklistRetired: true), isFalse);
    });

    test('a first message that came ends the wait', () {
      expect(_expected(isFirstMessageReceived: true), isFalse);
    });
  });
}
