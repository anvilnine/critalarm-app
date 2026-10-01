import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/features/local_reminders/domain/ring_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('409 means the topic is not critical', () {
    expect(
      RingFailures.classify(const Failure.api(statusCode: 409)),
      RingFailure.notCritical,
    );
  });

  test('401 means the server does not accept this phone', () {
    expect(
      RingFailures.classify(const Failure.api(statusCode: 401)),
      RingFailure.unauthorized,
    );
    expect(
      RingFailures.classify(const Failure.unauthorized()),
      RingFailure.unauthorized,
    );
  });

  test('a socket error means offline', () {
    expect(
      RingFailures.classify(
        const Failure.unexpected(
          message: 'ClientException with SocketException: Failed host lookup',
        ),
      ),
      RingFailure.offline,
    );
  });

  test('anything else is other, and only other is not a failed test', () {
    final other = RingFailures.classify(const Failure.api(statusCode: 500));
    expect(other, RingFailure.other);
    expect(other.countsAsFailedTest, isFalse);
    expect(RingFailure.offline.countsAsFailedTest, isTrue);
  });
}
