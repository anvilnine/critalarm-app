import 'package:critalarm/core/api/network_failure_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('apiErrorMessage', () {
    test('turns the cap code into a sentence naming the limit', () {
      final message = apiErrorMessage('cap', cap: 'critical_topics');

      expect(message, 'You have hit your critical topics limit.');
      expect(message, isNot(contains('cap')));
    });

    test('names the devices cap', () {
      expect(
        apiErrorMessage('cap', cap: 'devices'),
        'You have hit your devices limit.',
      );
    });

    test('cap with no cap name still reads as a sentence', () {
      expect(
        apiErrorMessage('cap'),
        'You have hit a limit on your plan.',
      );
    });

    test('maps the codes a client meets while creating a topic', () {
      expect(
        apiErrorMessage('topic already exists'),
        'A topic with that name already exists.',
      );
      expect(
        apiErrorMessage('invalid topic name'),
        'That name is not allowed. '
            'Use 1 to 64 lowercase letters, digits and hyphens.',
      );
      expect(
        apiErrorMessage('unauthorized'),
        'The server refused that. Check your connection in Settings.',
      );
      expect(
        apiErrorMessage('rate limited'),
        'Too many requests. Wait a moment and try again.',
      );
    });

    test('matches whatever case and padding the server sent', () {
      expect(
        apiErrorMessage('  Not Found '),
        'The server could not find that.',
      );
    });

    test('an unknown code falls back to a generic sentence', () {
      expect(
        apiErrorMessage('teapot_on_fire'),
        'Something went wrong on the server. Try again.',
      );
      expect(apiErrorMessage('teapot_on_fire'), isNot(contains('teapot')));
    });

    test('a missing code falls back to the same sentence', () {
      expect(
        apiErrorMessage(null),
        'Something went wrong on the server. Try again.',
      );
    });
  });
}
