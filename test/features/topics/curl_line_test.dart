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
}
