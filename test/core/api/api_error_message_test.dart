import 'package:critalarm/core/api/network_failure_message.dart';
import 'package:critalarm/core/failures/cap_reached.dart';
import 'package:critalarm/core/failures/failure.dart';
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

    test('a cap name we do not know never reaches the sentence', () {
      final message = apiErrorMessage('cap', cap: 'weekly_smoke_signals');

      expect(message, 'You have hit your plan limit.');
      expect(message, isNot(contains('weekly_smoke_signals')));
    });
  });

  group('CapReached', () {
    test('names the caps it knows', () {
      expect(const CapReached('critical_topics').label, 'Critical topics');
      expect(const CapReached('devices').message, 'Devices limit reached');
    });

    test('a cap it does not know gets a generic label, not the wire name', () {
      const cap = CapReached('weekly_smoke_signals');

      expect(cap.label, 'Plan');
      expect(cap.message, 'Plan limit reached');
      expect(cap.message, isNot(contains('weekly_smoke_signals')));
    });
  });

  group('failureMessage', () {
    test('a wire code on an api failure becomes a sentence', () {
      final message = failureMessage(
        const Failure.api(statusCode: 400, message: 'invalid topic name'),
      );

      expect(
        message,
        'That name is not allowed. '
        'Use 1 to 64 lowercase letters, digits and hyphens.',
      );
    });

    test('a 429 keeps the cap name in the sentence', () {
      final message = failureMessage(
        const Failure.api(statusCode: 429, message: 'cap', cap: 'devices'),
      );

      expect(message, 'You have hit your devices limit.');
    });

    test('an exception dump never reaches the screen', () {
      final message = failureMessage(
        const Failure.unexpected(
          message: 'PlatformException(error, Failed host lookup, null, null)',
        ),
      );

      expect(message, 'Something went wrong on the server. Try again.');
      expect(message, isNot(contains('PlatformException')));
    });

    test('a failure with no message still reads as a sentence', () {
      expect(
        failureMessage(const Failure.database()),
        'Something went wrong on the server. Try again.',
      );
    });
  });
}
