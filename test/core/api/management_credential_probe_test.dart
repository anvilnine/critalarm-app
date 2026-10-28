import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/api/http_api_client.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final class _NoSession implements ApiSessionStore {
  @override
  Future<void> clear() async {}

  @override
  Future<ApiSession?> read() async => null;

  @override
  Future<void> write(ApiSession session) async {}
}

void main() {
  test('asks the given server for one incident with the credential, and '
      'follows no redirect', () async {
    late http.BaseRequest sent;
    final client = HttpApiClient(
      MockClient((request) async {
        sent = request;
        return http.Response('[]', 200);
      }),
      _NoSession(),
    );

    await client.checkManagementCredential(
      Uri.parse('https://alarm.example.com/base/'),
      'ad_one',
    );

    expect(sent.method, 'GET');
    expect(
      sent.url.toString(),
      'https://alarm.example.com/base/v1/incidents?limit=1',
    );
    expect(sent.headers['authorization'], 'Bearer ad_one');
    expect(sent.followRedirects, isFalse);
  });

  test('a redirect is an answer that is not a yes', () async {
    final client = HttpApiClient(
      MockClient(
        (_) async => http.Response(
          '',
          302,
          headers: {'location': 'https://other.example.net/v1/incidents'},
        ),
      ),
      _NoSession(),
    );

    await expectLater(
      client.checkManagementCredential(
        Uri.parse('https://alarm.example.com'),
        'ad_one',
      ),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 302),
      ),
    );
  });

  test('a refused credential that begins like a device token does not '
      'start the dead-account recovery', () async {
    var recoveries = 0;
    final client = HttpApiClient(
      MockClient((_) async => http.Response('{"error":"unauthorized"}', 401)),
      _NoSession(),
      onDeadCredential: () async => recoveries++,
    );

    await expectLater(
      client.checkManagementCredential(
        Uri.parse('https://alarm.example.com'),
        'dv_not_this_phone',
      ),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
      ),
    );
    expect(recoveries, 0);
  });
}
