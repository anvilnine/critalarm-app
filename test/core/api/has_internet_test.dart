import 'dart:async';
import 'dart:io';

import 'package:critalarm/core/api/network_failure_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('isOnlineFromProbe decision logic', () {
    test('returns true when HTTP status code is 200', () {
      expect(isOnlineFromProbe(statusCode: 200), isTrue);
    });

    test('returns true for any HTTP response status code', () {
      expect(isOnlineFromProbe(statusCode: 204), isTrue);
      expect(isOnlineFromProbe(statusCode: 301), isTrue);
      expect(isOnlineFromProbe(statusCode: 401), isTrue);
      expect(isOnlineFromProbe(statusCode: 404), isTrue);
      expect(isOnlineFromProbe(statusCode: 500), isTrue);
      expect(isOnlineFromProbe(statusCode: 503), isTrue);
    });

    test('treats timeout as online (unknown result)', () {
      expect(
        isOnlineFromProbe(
          error: TimeoutException('Connection timed out'),
        ),
        isTrue,
      );
    });

    test('treats TLS handshake failure as online (unknown/captive portal)', () {
      expect(
        isOnlineFromProbe(
          error: const HandshakeException('Handshake failed'),
        ),
        isTrue,
      );
      expect(
        isOnlineFromProbe(
          error: const TlsException('TLS error'),
        ),
        isTrue,
      );
      expect(
        isOnlineFromProbe(
          error: const CertificateException('Cert expired'),
        ),
        isTrue,
      );
    });

    test('treats generic or unknown error as online', () {
      expect(
        isOnlineFromProbe(error: const FormatException('Unexpected response')),
        isTrue,
      );
      expect(
        isOnlineFromProbe(error: Exception('Some random error')),
        isTrue,
      );
    });

    test(
      'treats connection refused / reset as online (remote host reached)',
      () {
        expect(
          isOnlineFromProbe(
            error: const SocketException('Connection refused', port: 443),
          ),
          isTrue,
        );
        expect(
          isOnlineFromProbe(
            error: const SocketException('Connection reset by peer', port: 443),
          ),
          isTrue,
        );
      },
    );

    test('returns false on definitive network unreachable errors', () {
      expect(
        isOnlineFromProbe(
          error: const SocketException('Network is unreachable'),
        ),
        isFalse,
      );
      expect(
        isOnlineFromProbe(
          error: const SocketException('Network is down'),
        ),
        isFalse,
      );
      expect(
        isOnlineFromProbe(
          error: const SocketException('No route to host'),
        ),
        isFalse,
      );
      expect(
        isOnlineFromProbe(
          error: const SocketException('Failed host lookup: api.critalarm.app'),
        ),
        isFalse,
      );
    });

    test('returns false when OSError has unreachable/down error codes', () {
      expect(
        isOnlineFromProbe(
          error: const SocketException(
            'Failed',
            osError: OSError('Network is unreachable', 101),
          ),
        ),
        isFalse,
      );
      expect(
        isOnlineFromProbe(
          error: const SocketException(
            'Failed',
            osError: OSError('Network is unreachable', 51),
          ),
        ),
        isFalse,
      );
      expect(
        isOnlineFromProbe(
          error: const SocketException(
            'Failed',
            osError: OSError('No route to host', 113),
          ),
        ),
        isFalse,
      );
      expect(
        isOnlineFromProbe(
          error: const SocketException(
            'Failed',
            osError: OSError('Network is down', 100),
          ),
        ),
        isFalse,
      );
    });

    test('returns false on ClientException wrapping offline socket errors', () {
      expect(
        isOnlineFromProbe(
          error: http.ClientException(
            'ClientException with SocketException: Failed host lookup: '
            "'api.critalarm.app' "
            '(OS Error: nodename nor servname provided, errno = 8)',
          ),
        ),
        isFalse,
      );
      expect(
        isOnlineFromProbe(
          error: http.ClientException(
            'ClientException with SocketException: Network is unreachable',
          ),
        ),
        isFalse,
      );
    });
  });

  group('hasInternet injectable probe', () {
    test('probes https://api.critalarm.app/v1/info by default', () async {
      Uri? requestedUri;
      final client = MockClient((request) async {
        requestedUri = request.url;
        return http.Response('{"name":"critalarm","version":"0.3.0"}', 200);
      });

      final result = await hasInternet(client: client);

      expect(result, isTrue);
      expect(
        requestedUri,
        Uri.parse('https://api.critalarm.app/v1/info'),
      );
    });

    test('probes custom URI when provided', () async {
      Uri? requestedUri;
      final customUri = Uri.parse('https://my-server.example/v1/info');
      final client = MockClient((request) async {
        requestedUri = request.url;
        return http.Response('{"name":"critalarm"}', 200);
      });

      final result = await hasInternet(uri: customUri, client: client);

      expect(result, isTrue);
      expect(requestedUri, customUri);
    });

    test('returns true on HTTP 200', () async {
      final client = MockClient((_) async => http.Response('ok', 200));
      expect(await hasInternet(client: client), isTrue);
    });

    test('treats 500 response as online (server reached)', () async {
      final client = MockClient((_) async => http.Response('error', 500));
      expect(await hasInternet(client: client), isTrue);
    });

    test('treats timeout as online (unknown result)', () async {
      final client = MockClient((_) async {
        throw TimeoutException('Request timeout');
      });
      expect(await hasInternet(client: client), isTrue);
    });

    test('returns false on definitive failed host lookup', () async {
      final client = MockClient((_) async {
        throw http.ClientException(
          'ClientException with SocketException: Failed host lookup: '
          "'api.critalarm.app' "
          '(OS Error: nodename nor servname provided, errno = 8)',
        );
      });
      expect(await hasInternet(client: client), isFalse);
    });

    test(
      'returns false on definitive network unreachable socket error',
      () async {
        final client = MockClient((_) async {
          throw const SocketException('Network is unreachable');
        });
        expect(await hasInternet(client: client), isFalse);
      },
    );
  });
}
