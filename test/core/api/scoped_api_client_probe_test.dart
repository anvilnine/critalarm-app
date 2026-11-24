import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/management_credential_probe.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/api/scoped_api_client.dart';
import 'package:critalarm/features/onboarding/data/repositories/in_memory_server_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Accepts one credential and answers 401 to any other.
final class _OneTokenServer extends MockApiClient {
  _OneTokenServer() : super(MockServer());

  final asked = <(Uri, String)>[];

  @override
  Future<void> checkManagementCredential(Uri baseUri, String credential) async {
    asked.add((baseUri, credential));
    if (credential != 'good') {
      throw const ApiException(statusCode: 401, message: 'unauthorized');
    }
  }
}

void main() {
  final base = Uri.parse('https://alarm.example.com');
  late _OneTokenServer inner;
  late InMemoryServerRepository repository;

  setUp(() {
    inner = _OneTokenServer();
    // The same wrapping the app registers for a real server.
    repository = InMemoryServerRepository(
      ScopedApiClient(inner, readScope: () async => null),
    );
  });

  test('the scoped client still answers the admin token probe', () {
    expect(
      ScopedApiClient(inner, readScope: () async => null),
      isA<ManagementCredentialProbe>(),
    );
  });

  test('a valid admin token reaches the server and passes', () async {
    await repository.checkAdminToken(base, 'good');

    expect(inner.asked, [(base, 'good')]);
  });

  test('a wrong admin token comes back as the server 401', () async {
    await expectLater(
      repository.checkAdminToken(base, 'wrong'),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
      ),
    );
    expect(inner.asked, [(base, 'wrong')]);
  });
}
