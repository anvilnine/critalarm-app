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
      'curl -H "Authorization: Bearer tk_8Qm2" '
      "-d 'disk full' 'https://api.critalarm.app/prod-db'",
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
      endsWith("'https://alerts.example.com/nas'"),
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
      "-d 'disk full' 'https://api.critalarm.app/prod-db'",
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

  group('a shell runs the line as written', () {
    String lineWith({
      String serverUrl = 'https://api.critalarm.app',
      String message = 'disk full',
    }) => CurlLine.build(
      serverUrl: serverUrl,
      topic: 'nas',
      token: 'tk_1',
      message: message,
    );

    test('an address with ? and & stays one word', () {
      expect(
        lineWith(serverUrl: 'https://alerts.example.com/hook?a=1&b=2'),
        endsWith(" 'https://alerts.example.com/hook?a=1&b=2/nas'"),
      );
    });

    test('a double quote, a dollar and a backtick are not acted on', () {
      const message = r'say "hi" to $HOME and `id`';
      expect(lineWith(message: message), contains("-d '$message' "));
    });

    test('a single quote in the message is escaped', () {
      expect(
        lineWith(message: "it's down"),
        contains(r"-d 'it'\''s down' "),
      );
    });

    test('a single quote in the address is escaped', () {
      expect(
        lineWith(serverUrl: "https://alerts.example.com/a'b"),
        endsWith(r" 'https://alerts.example.com/a'\''b/nas'"),
      );
    });

    test('shellQuote wraps and escapes', () {
      expect(CurlLine.shellQuote('plain'), "'plain'");
      expect(CurlLine.shellQuote("a'b"), r"'a'\''b'");
      expect(CurlLine.shellQuote(''), "''");
    });
  });

  group('the line a terminal shows', () {
    test('names the server, the topic and the priority that rings', () {
      final line = CurlLine.forTerminal(
        serverUrl: 'https://alerts.example.com/',
        topic: 'prod-db',
        message: 'Test alarm',
      );

      expect(line, contains('curl https://alerts.example.com/prod-db'));
      expect(line, contains('-H "Priority: urgent"'));
      expect(line, contains("-d 'Test alarm'"));
    });

    test('shows a masked placeholder where a token would be', () {
      final line = CurlLine.forTerminal(
        serverUrl: 'https://api.critalarm.app',
        topic: 'prod-db',
        message: 'Test alarm',
      );

      expect(line, contains('Bearer tk_\u2026"'));
      // Nothing after the prefix: there is no token behind it.
      expect(RegExp('tk_[A-Za-z0-9]').hasMatch(line), isFalse);
    });
  });
}
