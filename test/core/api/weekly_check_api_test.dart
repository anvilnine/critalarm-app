import 'dart:convert';

import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/api/http_api_client.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/models/weekly_check.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final class _Sessions implements ApiSessionStore {
  ApiSession? session = ApiSession(
    baseUri: Uri.parse('https://server.example'),
    relayUri: Uri.parse('https://relay.example'),
    mode: ServerMode.selfhosted,
    managementCredential: 'ad_secret',
  );

  @override
  Future<void> clear() async => session = null;

  @override
  Future<ApiSession?> read() async => session;

  @override
  Future<void> write(ApiSession session) async => this.session = session;
}

const _registration = DeviceRegistration(
  deviceId: 'dev_1',
  platform: 'android',
  pushToken: 'push_token',
  appVersion: '1.0.0',
);

Matcher _status(int code) =>
    isA<ApiException>().having((e) => e.statusCode, 'statusCode', code);

void main() {
  late MockServer server;
  late _Sessions sessions;
  String? deviceToken;
  String? deviceId;
  var now = DateTime.utc(2026, 10, 7, 9);
  final requests = <http.Request>[];

  HttpApiClient client() => HttpApiClient(
    MockClient((request) {
      requests.add(request);
      return server.handleHttpRequest(request);
    }),
    sessions,
    readDeviceToken: () async => deviceToken,
    readDeviceId: () async => deviceId,
  );

  int seconds() => now.millisecondsSinceEpoch ~/ 1000;

  setUp(() {
    now = DateTime.utc(2026, 10, 7, 9);
    server = MockServer()..weeklyCheckClock = (() => now);
    sessions = _Sessions();
    requests.clear();
    deviceToken = null;
    deviceId = 'dev_1';
  });

  /// Registers the fixture device on an account of [tier]. The weekly
  /// check goes by the tier and by nothing else (api.md §4.5).
  Future<void> register({String tier = 'hosted'}) async {
    server.accountTier = tier;
    final response = await client().registerDevice(_registration);
    deviceToken = response.deviceToken;
    requests.clear();
  }

  group('PUT .../check', () {
    test('goes to the relay, to this device, with its own token', () async {
      await register();
      final check = await client().setWeeklyCheck(enabled: true);
      final request = requests.single;
      expect(request.method, 'PUT');
      expect(
        request.url.toString(),
        'https://relay.example/relay/v1/devices/dev_1/check',
      );
      expect(request.headers['authorization'], 'Bearer $deviceToken');
      expect(jsonDecode(request.body), {'enabled': true});
      expect(check.enabled, isTrue);
      expect(check.state, WeeklyCheckState.waiting);
      expect(check.nextDueAt, isNotNull);
      expect(check.noticeAfter, isNotNull);
    });

    test(
      'enabling off Hosted answers 403 and names the tier it needs',
      () async {
        await register(tier: 'free');
        for (final tier in ['free', 'relay']) {
          server.accountTier = tier;
          await expectLater(
            client().setWeeklyCheck(enabled: true),
            throwsA(
              isA<ApiException>()
                  .having((e) => e.statusCode, 'statusCode', 403)
                  .having((e) => e.message, 'message', 'tier')
                  .having((e) => e.tier, 'tier', 'hosted')
                  .having((e) => e.pack, 'pack', isNull),
            ),
            reason: tier,
          );
          expect((await client().getWeeklyCheck()).enabled, isFalse);
        }
      },
    );

    test('no pack is enough: free with Pro is refused the same way', () async {
      await register(tier: 'free');
      server.grantedPacks.add('pro');
      await expectLater(
        client().setWeeklyCheck(enabled: true),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having((e) => e.tier, 'tier', 'hosted'),
        ),
      );
    });

    test('no pack is needed: Hosted with no pack enrols', () async {
      await register();
      expect(server.heldPacks(), isEmpty);
      expect((await client().setWeeklyCheck(enabled: true)).enabled, isTrue);
    });

    test('enabling off Hosted changes nothing for a device already '
        'enrolled', () async {
      await register();
      await client().setWeeklyCheck(enabled: true);
      server.accountTier = 'free';
      await expectLater(
        client().setWeeklyCheck(enabled: true),
        throwsA(isA<ApiException>().having((e) => e.tier, 'tier', 'hosted')),
      );
      expect((await client().getWeeklyCheck()).enabled, isTrue);
    });

    test('the pack error of 1.18.0 still parses, with no tier', () async {
      final old = HttpApiClient(
        MockClient(
          (request) async => http.Response(
            jsonEncode({'error': 'pack', 'pack': 'pro'}),
            403,
          ),
        ),
        _Sessions(),
        readDeviceToken: () async => 'dv_1',
        readDeviceId: () async => 'dev_1',
      );
      await expectLater(
        old.setWeeklyCheck(enabled: true),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having((e) => e.pack, 'pack', 'pro')
              .having((e) => e.tier, 'tier', isNull),
        ),
      );
    });

    test('disabling always answers, Hosted or not', () async {
      await register(tier: 'free');
      final check = await client().setWeeklyCheck(enabled: false);
      expect(check.enabled, isFalse);
      expect(check.state, WeeklyCheckState.off);
      expect(check.reason, WeeklyCheckOffReason.disabled);
      expect(check.nextDueAt, isNull);
      expect(check.noticeAfter, isNull);
    });
  });

  group('GET .../check', () {
    test('a device that never enrolled is off', () async {
      await register();
      final check = await client().getWeeklyCheck();
      expect(requests.single.method, 'GET');
      expect(
        requests.single.url.path,
        '/relay/v1/devices/dev_1/check',
      );
      expect(check.state, WeeklyCheckState.off);
      expect(check.reason, WeeklyCheckOffReason.disabled);
      expect(check.lastSentAt, isNull);
      expect(check.lastReceivedAt, isNull);
    });

    test('the mock shows every state', () async {
      await register();
      for (final state in WeeklyCheckState.values) {
        server.seedWeeklyCheck(state);
        final check = await client().getWeeklyCheck();
        expect(check.state, state, reason: state.name);
        expect(check.enabled, state != WeeklyCheckState.off);
      }
    });

    test('misses and notice_after follow the rounds', () async {
      await register();
      server.seedWeeklyCheck(WeeklyCheckState.received);
      var check = await client().getWeeklyCheck();
      expect(check.misses, 0);
      expect(check.lastReceivedAt, isNotNull);
      expect(check.noticeAfter! > seconds(), isTrue);

      server.seedWeeklyCheck(WeeklyCheckState.missedOnce);
      check = await client().getWeeklyCheck();
      expect(check.misses, 1);
      expect(check.noticeAfter! > seconds(), isTrue);

      server.seedWeeklyCheck(WeeklyCheckState.tokenRefused);
      expect((await client().getWeeklyCheck()).misses, 1);

      server.seedWeeklyCheck(WeeklyCheckState.missedRepeatedly);
      check = await client().getWeeklyCheck();
      expect(check.misses, 2);
      // Where the run reached two, which is in the past.
      expect(check.noticeAfter! < seconds(), isTrue);
    });

    test('a skipped round changes nothing', () async {
      await register();
      server.seedWeeklyCheck(WeeklyCheckState.missedOnce);
      server.weeklyCheckRounds.insert(
        0,
        WeeklyCheckRound(
          id: 'rnd_skip',
          openedAt: seconds() - 60,
          closedAt: seconds() - 30,
          result: WeeklyCheckResult.skipped,
          reason: 'held',
        ),
      );
      final check = await client().getWeeklyCheck();
      expect(check.state, WeeklyCheckState.missedOnce);
      expect(check.misses, 1);
    });

    test('a lapse: still enrolled, off with the reason `tier`, and the '
        'times it had', () async {
      await register();
      server.seedWeeklyCheck(WeeklyCheckState.received);
      final before = await client().getWeeklyCheck();
      server.accountTier = 'free';
      final check = await client().getWeeklyCheck();
      expect(check.enabled, isTrue);
      expect(check.state, WeeklyCheckState.off);
      expect(check.reason, WeeklyCheckOffReason.tier);
      expect(check.lastSentAt, before.lastSentAt);
      expect(check.lastReceivedAt, before.lastReceivedAt);
      expect(check.nextDueAt, isNull);
      expect(check.noticeAfter, isNull);
    });

    test('a return: the device needs no new PUT', () async {
      await register();
      server
        ..seedWeeklyCheck(WeeklyCheckState.received)
        ..accountTier = 'free';
      expect((await client().getWeeklyCheck()).state, WeeklyCheckState.off);
      server.accountTier = 'hosted';
      requests.clear();
      final check = await client().getWeeklyCheck();
      expect(check.enabled, isTrue);
      expect(check.state, WeeklyCheckState.received);
      expect(check.reason, isNull);
      expect(check.noticeAfter, isNotNull);
      expect(requests.map((r) => r.method), ['GET']);
    });

    test('holding Pro does not keep the check through a lapse', () async {
      await register();
      server
        ..seedWeeklyCheck(WeeklyCheckState.received)
        ..grantedPacks.add('pro')
        ..accountTier = 'free';
      final check = await client().getWeeklyCheck();
      expect(check.state, WeeklyCheckState.off);
      expect(check.reason, WeeklyCheckOffReason.tier);
    });

    test('a reason this build does not know reads as no reason: `pack` '
        'from 1.18.0 and anything later', () {
      for (final reason in ['pack', 'something_new', 7, '']) {
        final check = WeeklyCheck.fromJson({
          'enabled': true,
          'state': 'off',
          'reason': reason,
        });
        expect(check.state, WeeklyCheckState.off, reason: '$reason');
        expect(check.reason, isNull, reason: '$reason');
        // Written back out, it is still no reason.
        expect(
          WeeklyCheck.fromJson(check.toJson()).reason,
          isNull,
          reason: '$reason',
        );
      }
      expect(
        WeeklyCheck.fromJson(const {
          'enabled': true,
          'state': 'off',
          'reason': 'tier',
        }).reason,
        WeeklyCheckOffReason.tier,
      );
      expect(WeeklyCheckOffReason.fromWire('disabled'), isNotNull);
    });

    test('a state this build does not know reads as null', () {
      final check = WeeklyCheck.fromJson(const {
        'enabled': true,
        'state': 'paused',
        'misses': 0,
      });
      expect(check.enabled, isTrue);
      expect(check.state, isNull);
    });

    test("another device's token answers 404", () async {
      await register();
      deviceId = 'dev_other';
      await expectLater(client().getWeeklyCheck(), throwsA(_status(404)));
    });

    test('with no device token there is nobody to ask', () async {
      expect(
        client().getWeeklyCheck(),
        throwsA(isA<NoApiSessionException>()),
      );
      expect(requests, isEmpty);
    });

    test('with no device id there is nobody to ask', () async {
      await register();
      deviceId = null;
      expect(
        client().getWeeklyCheck(),
        throwsA(isA<NoApiSessionException>()),
      );
    });
  });

  group('POST .../checks/{check_id}/receipt', () {
    test('a receipt while the round is open counts and ends it', () async {
      await register();
      await client().setWeeklyCheck(enabled: true);
      final checkId = server.openWeeklyCheckRound();
      requests.clear();

      final receipt = await client().sendWeeklyCheckReceipt(
        checkId,
        attempt: 1,
        receivedAt: seconds(),
      );
      final request = requests.single;
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'https://relay.example/relay/v1/devices/dev_1/checks/$checkId/receipt',
      );
      expect(request.headers['authorization'], 'Bearer $deviceToken');
      expect(jsonDecode(request.body), {
        'attempt': 1,
        'received_at': seconds(),
      });
      expect(receipt.counted, isTrue);
      expect(receipt.nextDueAt, isNotNull);
      expect(receipt.noticeAfter, isNotNull);

      final check = await client().getWeeklyCheck();
      expect(check.state, WeeklyCheckState.received);
      expect(check.lastReceivedAt, seconds());
    });

    test('both body fields are optional', () async {
      await register();
      await client().setWeeklyCheck(enabled: true);
      final checkId = server.openWeeklyCheckRound();
      requests.clear();
      final receipt = await client().sendWeeklyCheckReceipt(checkId);
      expect(jsonDecode(requests.single.body), <String, dynamic>{});
      expect(receipt.counted, isTrue);
    });

    test(
      'the same receipt twice gets the same answer and changes nothing',
      () async {
        await register();
        await client().setWeeklyCheck(enabled: true);
        final checkId = server.openWeeklyCheckRound();
        final first = await client().sendWeeklyCheckReceipt(
          checkId,
          attempt: 1,
        );
        final rounds = server.weeklyCheckRounds.length;
        final second = await client().sendWeeklyCheckReceipt(
          checkId,
          attempt: 2,
        );
        expect(second.counted, first.counted);
        expect(second.noticeAfter, first.noticeAfter);
        expect(server.weeklyCheckRounds.length, rounds);
        expect(server.weeklyCheckRounds.first.attemptReceived, 1);
      },
    );

    test('a receipt after the round closed does not count', () async {
      await register();
      await client().setWeeklyCheck(enabled: true);
      final checkId = server.openWeeklyCheckRound();
      now = now.add(const Duration(hours: 25));
      final receipt = await client().sendWeeklyCheckReceipt(checkId);
      expect(receipt.counted, isFalse);
      final round = server.weeklyCheckRounds.first;
      expect(round.result, WeeklyCheckResult.missed);
      expect(round.lateReceiptAt, seconds());
    });

    test('an id the relay never sent answers 404', () async {
      await register();
      await expectLater(
        client().sendWeeklyCheckReceipt('chk_unknown'),
        throwsA(_status(404)),
      );
    });
  });

  group('GET .../checks', () {
    test('lists the rounds newest first', () async {
      await register();
      server.seedWeeklyCheck(WeeklyCheckState.received);
      final rounds = await client().listWeeklyCheckRounds();
      expect(requests.single.url.path, '/relay/v1/devices/dev_1/checks');
      expect(requests.single.url.query, isEmpty);
      expect(rounds, hasLength(5));
      for (var i = 1; i < rounds.length; i++) {
        expect(rounds[i - 1].openedAt > rounds[i].openedAt, isTrue);
      }
      expect(
        {for (final round in rounds) round.result},
        {
          WeeklyCheckResult.received,
          WeeklyCheckResult.missed,
          WeeklyCheckResult.skipped,
        },
      );
    });

    test('limit is sent and applied', () async {
      await register();
      server.seedWeeklyCheck(WeeklyCheckState.received);
      final rounds = await client().listWeeklyCheckRounds(limit: 2);
      expect(requests.single.url.query, 'limit=2');
      expect(rounds, hasLength(2));
    });

    test('an open round is in the list with no result', () async {
      await register();
      await client().setWeeklyCheck(enabled: true);
      server.openWeeklyCheckRound();
      final rounds = await client().listWeeklyCheckRounds();
      expect(rounds.single.isOpen, isTrue);
      expect(rounds.single.result, isNull);
      expect(rounds.single.closedAt, isNull);
    });

    test('answers whatever the tier is today', () async {
      await register();
      server
        ..seedWeeklyCheck(WeeklyCheckState.missedOnce)
        ..accountTier = 'free';
      expect(await client().listWeeklyCheckRounds(), hasLength(2));
    });

    test('no route returns the id a push carries', () async {
      await register();
      await client().setWeeklyCheck(enabled: true);
      final checkId = server.openWeeklyCheckRound();
      requests.clear();
      final bodies = <String>[];
      final http.Client raw = MockClient((request) async {
        final response = await server.handleHttpRequest(request);
        bodies.add(response.body);
        return response;
      });
      final spy = HttpApiClient(
        raw,
        sessions,
        readDeviceToken: () async => deviceToken,
        readDeviceId: () async => deviceId,
      );
      await spy.getWeeklyCheck();
      await spy.listWeeklyCheckRounds();
      await spy.sendWeeklyCheckReceipt(checkId);
      for (final body in bodies) {
        expect(body.contains(checkId), isFalse);
      }
    });
  });

  group('the mock client', () {
    test('speaks the same four routes', () async {
      final mock = MockApiClient(server);
      server.accountTier = 'hosted';
      expect((await mock.getWeeklyCheck()).state, WeeklyCheckState.off);
      expect((await mock.setWeeklyCheck(enabled: true)).enabled, isTrue);
      final checkId = server.openWeeklyCheckRound();
      expect((await mock.sendWeeklyCheckReceipt(checkId)).counted, isTrue);
      expect(await mock.listWeeklyCheckRounds(), hasLength(1));
    });

    test('closing an open round with no receipt is a miss', () async {
      final mock = MockApiClient(server);
      server.accountTier = 'hosted';
      await mock.setWeeklyCheck(enabled: true);
      server
        ..openWeeklyCheckRound()
        ..closeWeeklyCheckRound(WeeklyCheckResult.missed);
      final check = await mock.getWeeklyCheck();
      expect(check.state, WeeklyCheckState.missedOnce);
      expect(check.misses, 1);
    });
  });
}
