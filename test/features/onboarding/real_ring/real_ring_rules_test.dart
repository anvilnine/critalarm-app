import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/features/onboarding/domain/connect/background_connect.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/real_ring_rules.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const idle = BackgroundConnectState();
  const connected = BackgroundConnectState(
    status: BackgroundConnectStatus.connected,
    serverUrl: 'https://api.critalarm.app',
  );
  const critical = Topic(name: 'prod-db', critical: true);
  const quiet = Topic(name: 'prod-db');

  group('realRingGateFor', () {
    test('a saved server and a critical topic are ready', () {
      for (final connect in [idle, connected]) {
        expect(
          realRingGateFor(
            hasConnection: true,
            connect: connect,
            topic: critical,
          ),
          RealRingGate.ready,
        );
      }
    });

    test('no saved connection is no server, whatever the topic', () {
      expect(
        realRingGateFor(hasConnection: false, connect: idle, topic: critical),
        RealRingGate.noServer,
      );
    });

    test('a connect still on its way is no server yet', () {
      for (final status in [
        BackgroundConnectStatus.connecting,
        BackgroundConnectStatus.waitingForNetwork,
        BackgroundConnectStatus.waitingForPushToken,
      ]) {
        expect(
          realRingGateFor(
            hasConnection: false,
            connect: BackgroundConnectState(status: status),
            topic: critical,
          ),
          RealRingGate.noServer,
          reason: status.name,
        );
      }
    });

    test('a connect that gave up is no server', () {
      expect(
        realRingGateFor(
          hasConnection: true,
          connect: const BackgroundConnectState(
            status: BackgroundConnectStatus.failed,
            failure: BackgroundConnectFailure.refused,
          ),
          topic: critical,
        ),
        RealRingGate.noServer,
      );
    });

    test('Critical off on the topic comes before ready', () {
      expect(
        realRingGateFor(hasConnection: true, connect: connected, topic: quiet),
        RealRingGate.criticalOff,
      );
    });

    test('no server is said before Critical off', () {
      expect(
        realRingGateFor(hasConnection: false, connect: idle, topic: quiet),
        RealRingGate.noServer,
      );
    });

    test('a server with no topic on it has nothing to ring', () {
      expect(
        realRingGateFor(hasConnection: true, connect: connected, topic: null),
        RealRingGate.noTopic,
      );
    });
  });

  group('setupTestTopic', () {
    const other = Topic(name: 'nas', critical: true);

    test('the topic setup just made wins', () {
      expect(
        setupTestTopic(
          heldName: 'prod-db',
          savedName: 'old',
          topics: const [other, quiet],
        ),
        quiet,
      );
    });

    test('after a kill the saved name finds it', () {
      expect(
        setupTestTopic(
          heldName: null,
          savedName: 'prod-db',
          topics: const [other, quiet],
        ),
        quiet,
      );
    });

    test('with neither, the first topic in the list', () {
      expect(
        setupTestTopic(
          heldName: null,
          savedName: null,
          topics: const [other, quiet],
        ),
        other,
      );
    });

    test('a name that is no longer in the list falls back to the first', () {
      expect(
        setupTestTopic(
          heldName: 'gone',
          savedName: 'gone',
          topics: const [other],
        ),
        other,
      );
    });

    test('an empty list has no topic', () {
      expect(
        setupTestTopic(heldName: 'prod-db', savedName: null, topics: const []),
        isNull,
      );
    });
  });

  group('the answer to the test call', () {
    test('a 409 is Critical off, never a failure line', () {
      expect(
        isCriticalOffAnswer(const Failure.api(statusCode: 409)),
        isTrue,
      );
      expect(isCriticalOffAnswer(const Failure.conflict()), isTrue);
      expect(
        isCriticalOffAnswer(const Failure.api(statusCode: 500)),
        isFalse,
      );
    });

    test('each failure maps to a reason', () {
      final cases = <Failure, RealRingFailure>{
        const Failure.api(statusCode: 401): RealRingFailure.signedOut,
        const Failure.api(statusCode: 403): RealRingFailure.signedOut,
        const Failure.unauthorized(): RealRingFailure.signedOut,
        const Failure.api(statusCode: 404): RealRingFailure.topicGone,
        const Failure.notFound(): RealRingFailure.topicGone,
        const Failure.api(statusCode: 429): RealRingFailure.rateLimited,
        const Failure.api(statusCode: 500): RealRingFailure.serverDown,
        const Failure.api(statusCode: 503): RealRingFailure.serverDown,
        const Failure.api(statusCode: 400): RealRingFailure.unknown,
        const Failure.unexpected(
          message:
              'ClientException with SocketException: Failed host lookup: '
              "'api.critalarm.app'",
        ): RealRingFailure.offline,
        const Failure.unexpected(
          message: 'SocketException: Network is unreachable',
        ): RealRingFailure.offline,
        const Failure.unexpected(
          message:
              'TimeoutException after 0:00:15.000000: Future not completed',
        ): RealRingFailure.slow,
        const Failure.unexpected(
          message: 'No API session configured',
        ): RealRingFailure.signedOut,
        const Failure.unexpected(message: 'boom'): RealRingFailure.unknown,
        const Failure.unexpected(): RealRingFailure.unknown,
      };
      for (final MapEntry(key: failure, value: reason) in cases.entries) {
        expect(realRingFailureFor(failure), reason, reason: '$failure');
      }
    });
  });

  group('realRingPlatformFor', () {
    test('an iPhone with AlarmKit', () {
      expect(
        realRingPlatformFor(
          platform: TargetPlatform.iOS,
          isWeb: false,
          claim: RingClaim.alarm,
        ),
        RealRingPlatform.iosAlarm,
      );
    });

    test('an iPhone without AlarmKit never gets the silent mode lines', () {
      expect(
        realRingPlatformFor(
          platform: TargetPlatform.iOS,
          isWeb: false,
          claim: RingClaim.timeSensitive,
        ),
        RealRingPlatform.iosTimeSensitive,
      );
    });

    test('an Android phone', () {
      expect(
        realRingPlatformFor(
          platform: TargetPlatform.android,
          isWeb: false,
          claim: RingClaim.alarm,
        ),
        RealRingPlatform.android,
      );
    });
  });

  test('the phone gets 20 seconds to ring', () {
    expect(realRingPushWait, const Duration(seconds: 20));
  });
}
