import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/api/http_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final class _MemoryApiSessionStore implements ApiSessionStore {
  _MemoryApiSessionStore(this.session);

  ApiSession? session;

  @override
  Future<void> clear() async => session = null;

  @override
  Future<ApiSession?> read() async => session;

  @override
  Future<void> write(ApiSession session) async => this.session = session;
}

ApiSessionStore _store() => _MemoryApiSessionStore(
  ApiSession(
    baseUri: Uri.parse('https://server.example'),
    relayUri: Uri.parse('https://relay.example'),
    mode: ServerMode.selfhosted,
    managementCredential: 'ad_secret',
  ),
);

List<Incident> _incidents(int count) => [
  for (var i = 0; i < count; i++)
    Incident(
      id: 'inc_$i',
      topic: 'prod-db',
      state: IncidentStates.acked,
      openedAt: DateTime.utc(2026, 9, 17).subtract(Duration(minutes: i)),
    ),
];

void main() {
  group('every list request carries a limit', () {
    test('the query always has one', () async {
      late http.Request captured;
      final client = HttpApiClient(
        MockClient((request) async {
          captured = request;
          return http.Response('[]', 200);
        }),
        _store(),
      );

      await client.getIncidents(limit: maxIncidentLimit);

      expect(captured.url.queryParameters['limit'], '200');
    });

    test('narrowing by state does not push the limit off the query', () async {
      late http.Request captured;
      final client = HttpApiClient(
        MockClient((request) async {
          captured = request;
          return http.Response('[]', 200);
        }),
        _store(),
      );

      await client.getIncidents(limit: 20, state: 'open');

      expect(captured.url.queryParameters, {'limit': '20', 'state': 'open'});
    });

    test('a request built without setting a limit still asks for one', () {
      // `limit` is not nullable, so the old bug (pass null, the query drops
      // the parameter, the server answers 20) has no way to be written.
      expect(const GetIncidentsParams().limit, maxIncidentLimit);
      expect(const GetIncidentsParams(state: 'open').limit, maxIncidentLimit);
    });
  });

  group('nothing asks for more than the contract allows', () {
    test('the ceiling is 200', () {
      expect(maxIncidentLimit, 200);
    });

    test('a limit outside 1..200 is rejected where it is built', () {
      for (final bad in <int>[0, -5, maxIncidentLimit + 1]) {
        expect(
          () => GetIncidentsParams(limit: bad),
          throwsA(isA<AssertionError>()),
          reason: 'limit $bad is outside api.md §3.2',
        );
      }
    });
  });

  group('the fake server reads limit the way api.md §3.2 says', () {
    test('absent means 20, not everything', () {
      final server = MockServer()..seedState(incidents: _incidents(250));

      expect(server.getIncidents(), hasLength(defaultIncidentLimit));
    });

    test('above 200 comes back as 200', () {
      final server = MockServer()..seedState(incidents: _incidents(250));

      expect(server.getIncidents(limit: maxIncidentLimit), hasLength(200));
      expect(server.getIncidents(limit: 500), hasLength(200));
    });

    test('below 1 is a 400', () {
      final server = MockServer()..seedState(incidents: _incidents(3));

      expect(
        () => server.getIncidents(limit: 0),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });
  });
}
