import 'dart:convert';

import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/api/cancel_reason_api.dart';
import 'package:critalarm/core/api/http_api_client.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/cancel_reason.dart';
import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final class _Sessions implements ApiSessionStore {
  ApiSession? session = ApiSession(
    baseUri: Uri.parse('https://api.example'),
    relayUri: Uri.parse('https://relay.example'),
    mode: ServerMode.hosted,
    managementCredential: 'dv_secret',
  );

  @override
  Future<void> clear() async => session = null;

  @override
  Future<ApiSession?> read() async => session;

  @override
  Future<void> write(ApiSession session) async => this.session = session;
}

/// The `error` of a JSON error body.
String _error(http.Response response) =>
    (jsonDecode(response.body) as Map<String, dynamic>)['error'] as String;

/// A string of the given UTF-16 code units. The formatter turns `\u` escapes
/// of white space into the characters, so the tests build them.
String _units(List<int> units) => String.fromCharCodes(units);

Matcher _status(int code, String message) => isA<ApiException>()
    .having((e) => e.statusCode, 'statusCode', code)
    .having((e) => e.message, 'message', message);

void main() {
  late MockServer server;
  late DateTime clock;
  final requests = <http.Request>[];

  HttpApiClient client() => HttpApiClient(
    MockClient((request) {
      requests.add(request);
      return server.handleHttpRequest(request);
    }),
    _Sessions(),
  );

  Future<void> send(
    CancelReasonApi api, {
    CancelReason reason = CancelReason.other,
    String? text,
    String version = '1',
    String platform = 'ios',
  }) => api.sendCancelReason(
    reason: reason,
    text: text,
    appVersion: version,
    platform: platform,
  );

  /// A raw call to the route, for bodies the typed client cannot make.
  Future<http.Response> raw(String body) => server.handleHttpRequest(
    http.Request(
        'POST',
        Uri.parse('https://api.example/v1/account/cancel-reason'),
      )
      ..headers['content-type'] = 'application/json'
      ..body = body,
  );

  setUp(() {
    clock = DateTime.utc(2026, 10, 20, 9);
    server = MockServer()
      ..accountTier = 'hosted'
      ..cancelAnswerClock = (() => clock);
    server.serverInfo = server.serverInfo.copyWith(mode: ServerModes.hosted);
    requests.clear();
  });

  test('posts the contract body to /v1/account/cancel-reason', () async {
    await client().sendCancelReason(
      reason: CancelReason.price,
      text: 'too much for what I use',
      appVersion: '1.0.0+12',
      platform: 'ios',
    );
    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/v1/account/cancel-reason');
    expect(request.headers['authorization'], 'Bearer dv_secret');
    expect(jsonDecode(request.body), {
      'reason': 'price',
      'text': 'too much for what I use',
      'app_version': '1.0.0+12',
      'platform': 'ios',
    });
    expect(server.cancelAnswers.single.reason, CancelReason.price);
  });

  test(
    'sends no key: no text key when there is none, no id, no plan end',
    () async {
      await send(client(), platform: 'android');
      expect(jsonDecode(requests.single.body), {
        'reason': 'other',
        'app_version': '1',
        'platform': 'android',
      });
    },
  );

  test(
    'the chip answer arrives, then the text arrives, and the text is stored',
    () async {
      final api = client();
      await send(api, reason: CancelReason.broken);
      expect(server.cancelAnswers.single.text, isNull);
      await send(api, reason: CancelReason.broken, text: 'crashed twice');
      expect(server.cancelAnswers, hasLength(1));
      expect(server.cancelAnswers.single.text, 'crashed twice');
    },
  );

  test('a repeat never changes the reason, version or platform, and text is '
      'set once', () async {
    final api = client();
    await send(api, reason: CancelReason.broken);
    await send(
      api,
      reason: CancelReason.price,
      text: 'crashed twice',
      version: '2',
      platform: 'android',
    );
    final answer = server.cancelAnswers.single;
    expect(answer.reason, CancelReason.broken);
    expect(answer.appVersion, '1');
    expect(answer.platform, 'ios');
    expect(answer.text, 'crashed twice');
    // Later text never replaces the first, and no text never clears it.
    await send(api, reason: CancelReason.broken, text: 'an older draft');
    await send(api, reason: CancelReason.broken);
    expect(server.cancelAnswers.single.text, 'crashed twice');
  });

  test('a repeat with only white space fills nothing', () async {
    final api = client();
    await send(api);
    await send(api, text: _units([0x20, 0x0A, 0x00A0, 0x3000, 0x20]));
    expect(server.cancelAnswers.single.text, isNull);
    await send(api, text: 'now words');
    expect(server.cancelAnswers.single.text, 'now words');
  });

  test('any call inside 30 days is a repeat, and one 30 days later is a new '
      'answer', () async {
    final api = client();
    await send(api);
    clock = clock.add(const Duration(days: 29));
    await send(api, text: 'day 29');
    expect(server.cancelAnswers, hasLength(1));
    // The window runs from the first store, and a repeat does not extend it.
    clock = clock.add(const Duration(days: 1));
    await send(api, reason: CancelReason.price);
    expect(server.cancelAnswers, hasLength(2));
    expect(server.cancelAnswers.last.reason, CancelReason.price);
  });

  group('the text limit', () {
    test('the mock refuses text over 500 characters like the server', () async {
      await expectLater(
        send(client(), text: 'x' * 501),
        throwsA(_status(400, 'text too long')),
      );
      expect(server.cancelAnswers, isEmpty);
      await send(client(), text: 'x' * 500);
      expect(server.cancelAnswers.single.text, 'x' * 500);
    });

    test(
      'counts code points after trimming the way the server trims',
      () async {
        // Padding the server trims does not count.
        final padding = _units([0x00A0, 0x3000]);
        await send(
          client(),
          text: '$padding${'😀' * 500}${_units([0xFEFF, 0x0A])}',
        );
        expect(server.cancelAnswers.single.text, '😀' * 500);
        server
          ..reset()
          ..serverInfo = server.serverInfo.copyWith(mode: ServerModes.hosted)
          ..accountTier = 'hosted';
        // 501 emoji are over, even though they are 1002 UTF-16 units.
        await expectLater(
          send(client(), text: '😀' * 501),
          throwsA(_status(400, 'text too long')),
        );
        // Next line (U+0085) is not trimmed by the server, so it counts.
        await expectLater(
          send(client(), text: '${'x' * 500}${_units([0x0085])}'),
          throwsA(_status(400, 'text too long')),
        );
        expect(server.cancelAnswers, isEmpty);
      },
    );
  });

  group('the refusals', () {
    test(
      '501 away from a server in hosted mode, and before the tier',
      () async {
        server
          ..serverInfo = server.serverInfo.copyWith(
            mode: ServerModes.selfhosted,
          )
          ..accountTier = 'free';
        await expectLater(
          send(client()),
          throwsA(_status(501, 'not supported in selfhosted mode')),
        );
        server.serverInfo = server.serverInfo.copyWith(mode: ServerModes.relay);
        await expectLater(
          send(client()),
          throwsA(_status(501, 'not supported in relay mode')),
        );
        expect(server.cancelAnswers, isEmpty);
      },
    );

    test('403 tier for an account never assigned Hosted', () async {
      server.accountTier = 'free';
      await expectLater(
        send(client()),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having((e) => e.message, 'message', 'tier')
              .having((e) => e.tier, 'tier', 'hosted'),
        ),
      );
      expect(server.cancelAnswers, isEmpty);
      // Once it was assigned Hosted, a lapsed account may still answer.
      server.everHeldHosted = true;
      await send(client());
      expect(server.cancelAnswers, hasLength(1));
    });

    test('the tier is checked before the body', () async {
      server.accountTier = 'free';
      expect((await raw('not json')).statusCode, 403);
      expect((await raw('x' * 9000)).statusCode, 403);
    });

    test('413 over 8192 raw bytes, and a body of exactly 8192 passes the size '
        'check', () async {
      final big = await raw('{"pad":"${'x' * 8200}"}');
      expect(big.statusCode, 413);
      expect(_error(big), 'request too large');
      // Bytes, not characters: 2731 three byte characters are 8193 bytes.
      final multibyte = await raw('{"pad":"${'€' * 2731}"}');
      expect(multibyte.statusCode, 413);
      // Right at the limit it moves on to the shape check.
      const shell = '{"pad":""}';
      final atLimit = await raw('{"pad":"${'x' * (8192 - shell.length)}"}');
      expect(atLimit.statusCode, 400);
      expect(_error(atLimit), 'invalid request');
      expect(server.cancelAnswers, isEmpty);
    });

    test('400 invalid request for a body of the wrong shape', () async {
      for (final body in [
        'not json',
        '[]',
        '"price"',
        '{"reason":1,"app_version":"1","platform":"ios"}',
        '{"reason":"price","text":5,"app_version":"1","platform":"ios"}',
        '{"reason":"price","platform":"ios"}',
        '{"reason":"price","app_version":"","platform":"ios"}',
        '{"reason":"price","app_version":"${'1' * 33}","platform":"ios"}',
        '{"reason":"price","app_version":"1 2","platform":"ios"}',
        '{"reason":"price","app_version":"1"}',
        '{"reason":"price","app_version":"1","platform":"web"}',
      ]) {
        final response = await raw(body);
        expect(response.statusCode, 400, reason: body);
        expect(_error(response), 'invalid request');
      }
      expect(server.cancelAnswers, isEmpty);
    });

    test(
      '400 invalid reason for a string that is not one of the six',
      () async {
        for (final reason in ['Price', '', 'cost']) {
          final response = await raw(
            jsonEncode({
              'reason': reason,
              'app_version': '1',
              'platform': 'ios',
            }),
          );
          expect(response.statusCode, 400, reason: reason);
          expect(_error(response), 'invalid reason');
        }
      },
    );

    test(
      'a bad shape wins over a bad reason, and a bad reason over long text',
      () async {
        final shape = await raw(
          jsonEncode({'reason': 'nope', 'app_version': '1', 'platform': 'web'}),
        );
        expect(_error(shape), 'invalid request');
        final reason = await raw(
          jsonEncode({
            'reason': 'nope',
            'text': 'x' * 501,
            'app_version': '1',
            'platform': 'ios',
          }),
        );
        expect(_error(reason), 'invalid reason');
      },
    );

    test('text may be absent, null or empty, and a long one is 400', () async {
      for (final text in [null, '', '   ']) {
        final response = await raw(
          jsonEncode({
            'reason': 'price',
            'text': text,
            'app_version': '1',
            'platform': 'ios',
          }),
        );
        expect(response.statusCode, 204);
      }
      expect(server.cancelAnswers.single.text, isNull);
      final long = await raw(
        jsonEncode({
          'reason': 'price',
          'text': 'x' * 501,
          'app_version': '1',
          'platform': 'ios',
        }),
      );
      expect(long.statusCode, 400);
      expect(_error(long), 'text too long');
    });

    test(
      '429 after 30 calls in a rolling hour, refused calls included',
      () async {
        final api = client();
        for (var i = 0; i < 30; i++) {
          await send(api);
        }
        await expectLater(send(api), throwsA(_status(429, 'rate limited')));
        // A call the limit refused is not counted, so the hour still ends.
        clock = clock.add(const Duration(hours: 1, seconds: 1));
        await send(api);
      },
    );
  });

  test('failNextCancelAnswers makes that many calls fail with 503', () async {
    server.failNextCancelAnswers = 2;
    final api = MockApiClient(server);
    for (var i = 0; i < 2; i++) {
      await expectLater(send(api), throwsA(_status(503, 'unavailable')));
    }
    await send(api);
    expect(server.cancelAnswerAttempts, 3);
    expect(server.cancelAnswers, hasLength(1));
  });

  test('a build with no such API throws a state error', () {
    expect(() => send(const NoCancelReasonApi()), throwsStateError);
  });
}
