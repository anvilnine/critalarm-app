import 'package:critalarm/features/topics/domain/curl_line.dart';
import 'package:critalarm/features/topics/domain/new_token_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('quick names', () {
    test('are the five tools in order', () {
      expect(kNewTokenQuickNames, [
        'curl',
        'Uptime Kuma',
        'Grafana',
        'GitHub Actions',
        'cron',
      ]);
    });

    test('each one is sent as it is written', () {
      for (final name in kNewTokenQuickNames) {
        expect(resolveNewTokenName(name), name);
      }
    });
  });

  group('resolveNewTokenName', () {
    test('trims the ends', () {
      expect(resolveNewTokenName('  Grafana \n'), 'Grafana');
    });

    test('keeps inner spaces', () {
      expect(resolveNewTokenName('Uptime  Kuma  eu'), 'Uptime  Kuma  eu');
    });

    test('cuts at 40 characters', () {
      final typed = 'a' * 55;
      expect(resolveNewTokenName(typed), 'a' * 40);
    });

    test('keeps exactly 40', () {
      expect(resolveNewTokenName('b' * 40), 'b' * 40);
    });

    test('does not leave a space at the cut', () {
      final typed = '${'c' * 39} tail';
      expect(resolveNewTokenName(typed), 'c' * 39);
    });

    test('empty and whitespace send no name', () {
      expect(resolveNewTokenName(''), isNull);
      expect(resolveNewTokenName('   \t '), isNull);
    });
  });

  group('maskedToken', () {
    test('keeps the first 7 and the last 4 around three dots', () {
      expect(maskedToken('tk_da393e7d43be4687a1c9'), 'tk_da39...a1c9');
    });

    test('shows a token with no middle whole', () {
      expect(maskedToken('tk_8Qm2'), 'tk_8Qm2');
    });

    test('shows a token under 11 characters whole', () {
      expect(maskedToken('tk_abc'), 'tk_abc');
      expect(maskedToken('0123456789'), '0123456789');
      expect(maskedToken('01234567890'), '01234567890');
    });

    test('hides at least one character of a 12 character token', () {
      expect(maskedToken('012345678901'), '0123456...8901');
    });

    test('an empty token stays empty', () {
      expect(maskedToken(''), '');
    });
  });

  group('the curl picture with a partly hidden token', () {
    const token = 'tk_da393e7d43be4687a1c9';

    test('hides the middle and never holds the full value', () {
      final view = CurlLine.forTerminalShowing(
        serverUrl: 'https://api.critalarm.app/',
        topic: 'uptime-kuma',
        token: token,
        message: 'disk full',
      );
      expect(view, contains('Bearer tk_da39...a1c9"'));
      expect(view, isNot(contains(token)));
      expect(view, isNot(contains('393e7d43be4687')));
    });

    test('is the terminal picture with the token in the header', () {
      final view = CurlLine.forTerminalShowing(
        serverUrl: 'https://api.critalarm.app',
        topic: 'uptime-kuma',
        token: token,
        message: 'disk full',
      );
      expect(
        view,
        'curl https://api.critalarm.app/uptime-kuma \\\n'
        '  -H "Authorization: Bearer tk_da39...a1c9" \\\n'
        '  -H "Priority: urgent" \\\n'
        "  -d 'disk full'",
      );
    });

    test('forTerminal still holds no token', () {
      final view = CurlLine.forTerminal(
        serverUrl: 'https://api.critalarm.app',
        topic: 'uptime-kuma',
        message: 'disk full',
      );
      expect(view, contains(CurlLine.maskedToken));
    });

    test('build still carries the full value', () {
      final line = CurlLine.build(
        serverUrl: 'https://api.critalarm.app',
        topic: 'uptime-kuma',
        token: token,
        message: 'disk full',
        priority: CurlLine.urgent,
      );
      expect(line, contains('Bearer $token"'));
      expect(line, contains('Priority: urgent'));
      expect(line, endsWith("'https://api.critalarm.app/uptime-kuma'"));
    });
  });

  group('MakeTokenGuard', () {
    test('lets the first tap through and holds back the rest', () {
      final guard = MakeTokenGuard();
      expect(guard.isBusy, isFalse);
      expect(guard.tryBegin(), isTrue);
      expect(guard.isBusy, isTrue);
      expect(guard.tryBegin(), isFalse);
      expect(guard.tryBegin(), isFalse);
    });

    test('lets one more through after a refused request', () {
      final guard = MakeTokenGuard()
        ..tryBegin()
        ..release();
      expect(guard.isBusy, isFalse);
      expect(guard.tryBegin(), isTrue);
      expect(guard.tryBegin(), isFalse);
    });

    test('stays closed after a token was made', () {
      final guard = MakeTokenGuard();
      var made = 0;
      for (var i = 0; i < 5; i++) {
        if (guard.tryBegin()) made++;
      }
      expect(made, 1);
    });
  });

  test('the two steps are name then shown', () {
    expect(NewTokenStep.values, [NewTokenStep.name, NewTokenStep.shown]);
  });
}
