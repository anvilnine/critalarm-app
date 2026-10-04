import 'package:critalarm/features/topics/domain/curl_line.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds a line that works as it is', () {
    expect(
      CurlLine.build(
        serverUrl: 'https://api.critalarm.app',
        topic: 'prod-db',
        token: 'tk_8Qm2',
        message: 'disk full',
      ),
      'curl -H "Authorization: Bearer tk_8Qm2" -d "disk full" '
      'https://api.critalarm.app/prod-db',
    );
  });

  test('drops trailing slashes and spaces from the server address', () {
    expect(
      CurlLine.build(
        serverUrl: ' https://alerts.example.com// ',
        topic: 'nas',
        token: 'tk_1',
        message: 'disk full',
      ),
      endsWith('https://alerts.example.com/nas'),
    );
  });

  test('leaves the priority header out unless one is asked for', () {
    final line = CurlLine.build(
      serverUrl: 'https://api.critalarm.app',
      topic: 'prod-db',
      token: 'tk_8Qm2',
      message: 'disk full',
    );
    expect(line.contains('Priority'), isFalse);
  });

  test('adds the priority header between the token and the message', () {
    expect(
      CurlLine.build(
        serverUrl: 'https://api.critalarm.app',
        topic: 'prod-db',
        token: 'tk_8Qm2',
        message: 'disk full',
        priority: CurlLine.urgent,
      ),
      'curl -H "Authorization: Bearer tk_8Qm2" -H "Priority: urgent" '
      '-d "disk full" https://api.critalarm.app/prod-db',
    );
  });

  test('an empty priority adds no header', () {
    expect(
      CurlLine.build(
        serverUrl: 'https://api.critalarm.app',
        topic: 'prod-db',
        token: 'tk_8Qm2',
        message: 'disk full',
        priority: ' ',
      ).contains('Priority'),
      isFalse,
    );
  });
}
