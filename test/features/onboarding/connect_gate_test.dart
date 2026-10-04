import 'package:critalarm/features/onboarding/domain/connect/background_connect.dart';
import 'package:critalarm/features/onboarding/presentation/flow/connect_gate.dart';
import 'package:flutter_test/flutter_test.dart';

const _url = 'https://api.critalarm.app';

BackgroundConnectState _state(
  BackgroundConnectStatus status, {
  BackgroundConnectFailure? failure,
}) => BackgroundConnectState(status: status, serverUrl: _url, failure: failure);

void main() {
  const pending = [
    BackgroundConnectStatus.connecting,
    BackgroundConnectStatus.waitingForNetwork,
    BackgroundConnectStatus.waitingForPushToken,
  ];

  group('connectGateFor', () {
    test('nothing was asked for: every step shows as it is', () {
      for (final path in [
        '/onboarding/welcome',
        '/onboarding',
        '/onboarding/first-topic',
        '/onboarding/real-ring',
      ]) {
        expect(
          connectGateFor(
            state: const BackgroundConnectState(),
            path: path,
            isReplay: false,
          ),
          ConnectGate.none,
        );
      }
    });

    test('pending on a step that needs the server: the step waits', () {
      for (final status in pending) {
        for (final path in [
          '/onboarding/first-topic',
          '/onboarding/real-ring',
          '/onboarding/test',
        ]) {
          expect(
            connectGateFor(
              state: _state(status),
              path: path,
              isReplay: false,
            ),
            ConnectGate.waiting,
            reason: '$status on $path',
          );
        }
      }
    });

    test('pending on a step that does not need the server: one quiet line', () {
      for (final status in pending) {
        for (final path in ['/onboarding', '/onboarding/widgets']) {
          expect(
            connectGateFor(
              state: _state(status),
              path: path,
              isReplay: false,
            ),
            ConnectGate.quiet,
            reason: '$status on $path',
          );
        }
      }
    });

    test('a failure shows on whichever step the user is on', () {
      final failed = _state(
        BackgroundConnectStatus.failed,
        failure: BackgroundConnectFailure.refused,
      );
      for (final path in [
        '/onboarding',
        '/onboarding/first-topic',
        '/onboarding/real-ring',
      ]) {
        expect(
          connectGateFor(state: failed, path: path, isReplay: false),
          ConnectGate.failed,
        );
      }
    });

    test('the connect step itself is never covered', () {
      for (final status in BackgroundConnectStatus.values) {
        expect(
          connectGateFor(
            state: _state(status),
            path: '/onboarding/connect',
            isReplay: false,
          ),
          ConnectGate.none,
          reason: '$status',
        );
      }
    });

    test('once connected the step appears', () {
      expect(
        connectGateFor(
          state: _state(BackgroundConnectStatus.connected),
          path: '/onboarding/first-topic',
          isReplay: false,
        ),
        ConnectGate.none,
      );
    });

    test('a replay from Settings is never covered', () {
      for (final status in BackgroundConnectStatus.values) {
        expect(
          connectGateFor(
            state: _state(status),
            path: '/onboarding/first-topic',
            isReplay: true,
          ),
          ConnectGate.none,
        );
      }
    });

    test('a path outside the setup steps is left alone', () {
      expect(
        connectGateFor(
          state: _state(BackgroundConnectStatus.waitingForNetwork),
          path: '/settings',
          isReplay: false,
        ),
        ConnectGate.none,
      );
    });
  });
}
