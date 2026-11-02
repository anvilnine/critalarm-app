import 'dart:async';
import 'dart:io';

import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/network_failure_message.dart';
import 'package:critalarm/core/api/network_fault.dart';
import 'package:critalarm/core/failures/cap_reached.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('numeric server codes', () {
    const cases = {
      40101: 'The server refused that. Check your connection in Settings.',
      40001:
          'That name is not allowed. '
          'Use 1 to 64 lowercase letters, digits and hyphens.',
      40901: 'A topic with that name already exists.',
      41301: 'The message is too large.',
      42901: 'Too many requests. Wait a moment and try again.',
    };
    for (final entry in cases.entries) {
      test('${entry.key} wins over conflicting server text', () {
        expect(
          failureMessage(
            Failure.api(
              statusCode: 400,
              code: entry.key,
              message: 'not found',
            ),
          ),
          entry.value,
        );
      });
      test('${entry.key} works without error text', () {
        expect(apiErrorMessage(null, code: entry.key), entry.value);
      });
    }
    test('an unknown numeric code never borrows a different text mapping', () {
      expect(
        failureMessage(
          const Failure.api(
            statusCode: 400,
            code: 99999,
            message: 'unauthorized',
          ),
        ),
        'Something went wrong on this phone. Try again.',
      );
    });
  });

  group('contract errors without numeric codes', () {
    const cases = {
      'unauthorized':
          'The server refused that. Check your connection in Settings.',
      'invalid topic name':
          'That name is not allowed. '
          'Use 1 to 64 lowercase letters, digits and hyphens.',
      'topic already exists': 'A topic with that name already exists.',
      'message too large': 'The message is too large.',
      'rate limited': 'Too many requests. Wait a moment and try again.',
      'invalid priority': 'That priority is not allowed.',
      'invalid request': 'The server could not read that request.',
      'incident state conflict':
          'That alarm is no longer in the expected state.',
      'scheduled delivery not supported':
          'The server does not support scheduled delivery.',
      'streaming not supported': 'The server does not support streaming.',
      'not found': 'The server could not find that.',
      'cap': 'You have hit a limit on your plan.',
      'pack': 'Your account does not have the pack needed for that.',
      'tier': 'Your account is not on the plan needed for that.',
      'invalid base_url': 'The server address is not allowed.',
      'challenge failed': 'The relay could not verify the server.',
      'registration closed': 'The relay is not accepting registrations.',
      'topic mismatch': 'That topic does not match the registered server.',
    };
    for (final entry in cases.entries) {
      test(entry.key, () {
        expect(apiErrorMessage(entry.key), entry.value);
      });
    }
  });

  group('connection exception mapping', () {
    test('a server exception uses numeric priority, not its text', () {
      expect(
        networkFailureMessage(
          const ApiException(
            statusCode: 400,
            code: 40101,
            message: 'invalid topic name',
          ),
        ),
        LocaleKeys.api_errors_unauthorized.tr(),
      );
    });

    test('a code-less server exception maps its known text and cap', () {
      expect(
        networkFailureMessage(
          const ApiException(statusCode: 429, message: 'cap', cap: 'devices'),
        ),
        'You have hit your devices limit.',
      );
    });

    test('unknown server text and exception dumps never reach the user', () {
      for (final error in [
        const ApiException(
          statusCode: 500,
          message: 'An unknown English server sentence.',
        ),
        Exception('An unknown English server sentence.'),
      ]) {
        expect(
          networkFailureMessage(error),
          error is ApiException
              ? LocaleKeys.api_errors_unknown.tr()
              : LocaleKeys.api_errors_unknown_phone.tr(),
        );
      }
    });

    test('transport timeouts and unreachable messages keep their wording', () {
      expect(
        networkFailureMessage(TimeoutException('private host')),
        LocaleKeys.onboarding_connect_connect_timeout.tr(),
      );
      expect(
        networkFailureMessage(const SocketException('private host')),
        LocaleKeys.onboarding_connect_network_unreachable.tr(),
      );
    });
  });

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

    test('the last token refusal reads as a next step, not a failure', () {
      final message = apiErrorMessage('topic must retain a token');

      expect(
        message,
        'A topic keeps at least one token. '
        'Make a new token first, then revoke this one.',
      );
      expect(message, isNot(contains('Something went wrong')));
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
        'Something went wrong on this phone. Try again.',
      );
      expect(apiErrorMessage('teapot_on_fire'), isNot(contains('teapot')));
    });

    test('a missing code falls back to the same sentence', () {
      expect(
        apiErrorMessage(null),
        'Something went wrong on this phone. Try again.',
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

      expect(message, 'Something went wrong on this phone. Try again.');
      expect(message, isNot(contains('PlatformException')));
    });

    test('a failure with no message still reads as a sentence', () {
      expect(
        failureMessage(const Failure.database()),
        'Something went wrong on this phone. Try again.',
      );
    });
  });

  group('a server error kept by a network fault', () {
    test('every word it keeps has a line of its own', () {
      for (final word in NetworkFault.knownWireErrors) {
        expect(
          apiErrorMessage(word, cap: word == 'cap' ? 'topics' : null),
          isNot(LocaleKeys.api_errors_unknown.tr()),
          reason: word,
        );
      }
    });

    test('reads with the same line as the server error itself', () {
      const error = ApiException(
        statusCode: 429,
        message: 'rate limited',
        code: 42901,
      );
      expect(
        networkFailureMessage(NetworkFault.of(error)),
        networkFailureMessage(error),
      );
      expect(
        networkFailureMessage(
          NetworkFault.of(
            const ApiException(statusCode: 500, message: 'Some prose'),
          ),
        ),
        LocaleKeys.api_errors_unknown.tr(),
      );
    });
  });

  group('server fault or phone fault', () {
    final server = LocaleKeys.api_errors_unknown.tr();
    final phone = LocaleKeys.api_errors_unknown_phone.tr();

    test('the two lines differ and only the server one blames the server', () {
      expect(server, isNot(phone));
      expect(server, contains('server'));
      expect(phone, isNot(contains('server')));
    });

    test('a 5xx answer is the server', () {
      for (final status in [500, 502, 503, 504, 599]) {
        expect(
          failureMessage(Failure.api(statusCode: status)),
          server,
          reason: '$status',
        );
        expect(
          networkFailureMessage(
            ApiException(statusCode: status, message: 'Some prose'),
          ),
          server,
          reason: '$status',
        );
      }
    });

    test('a 4xx the app has no words for is the phone, not the server', () {
      for (final status in [400, 403, 404, 418, 422]) {
        expect(
          failureMessage(Failure.api(statusCode: status)),
          phone,
          reason: '$status',
        );
        expect(
          failureMessage(
            Failure.api(statusCode: status, message: 'Some prose'),
          ),
          phone,
          reason: '$status',
        );
        expect(
          networkFailureMessage(
            ApiException(statusCode: status, message: 'Some prose'),
          ),
          phone,
          reason: '$status',
        );
      }
    });

    test('a known code keeps its own line whatever the status', () {
      expect(
        failureMessage(const Failure.api(statusCode: 500, code: 42901)),
        LocaleKeys.api_errors_rate_limited.tr(),
      );
    });

    test('a failure raised on the phone is the phone', () {
      for (final failure in [
        const Failure.unexpected(),
        const Failure.unexpected(message: 'FormatException: bad json'),
        const Failure.database(),
        const Failure.unsupported(),
        const Failure.conflict(),
        const Failure.badRequest(),
        const Failure.unauthorized(),
      ]) {
        expect(failureMessage(failure), phone, reason: '$failure');
      }
    });

    test('an exception thrown on the phone is the phone', () {
      for (final error in [
        const FormatException('bad body'),
        StateError('no session'),
        Exception('boom'),
        const NetworkFault(NetworkFaultKind.other),
      ]) {
        expect(networkFailureMessage(error), phone, reason: '$error');
      }
    });

    test('no connection and a timeout keep their own lines', () {
      expect(
        networkFailureMessage(const NetworkFault(NetworkFaultKind.timeout)),
        LocaleKeys.onboarding_connect_connect_timeout.tr(),
      );
      expect(
        networkFailureMessage(
          const NetworkFault(NetworkFaultKind.unreachable),
        ),
        LocaleKeys.onboarding_connect_network_unreachable.tr(),
      );
    });

    test('a server error kept by a network fault keeps its status', () {
      expect(
        networkFailureMessage(
          NetworkFault.of(const ApiException(statusCode: 503, message: 'x')),
        ),
        server,
      );
      expect(
        networkFailureMessage(
          NetworkFault.of(const ApiException(statusCode: 404, message: 'x')),
        ),
        phone,
      );
    });

    test('apiErrorMessage with no status falls to the phone line', () {
      expect(apiErrorMessage('something else'), phone);
      expect(apiErrorMessage(null, statusCode: 500), server);
    });
  });
}
