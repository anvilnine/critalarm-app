import 'package:critalarm/features/onboarding/presentation/cubits/connect_link_state.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/connect_link_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

ConnectLinkState _state({
  String host = 'alarm.example.com',
  String address = 'https://alarm.example.com',
  bool isPlainHttp = false,
  ConnectLinkPhase phase = ConnectLinkPhase.ready,
  bool canRetry = true,
}) => ConnectLinkState(
  host: host,
  address: address,
  isPlainHttp: isPlainHttp,
  phase: phase,
  canRetry: canRetry,
);

void main() {
  group('which Replaces line', () {
    test('none when the phone is on no server', () {
      expect(
        connectReplaces(replacingHost: null, replacesCloud: false),
        ConnectReplaces.none,
      );
      expect(
        connectReplaces(replacingHost: null, replacesCloud: true),
        ConnectReplaces.none,
      );
    });

    test('Crit Alarm Cloud when the server being replaced is the cloud', () {
      expect(
        connectReplaces(
          replacingHost: 'api.critalarm.app',
          replacesCloud: true,
        ),
        ConnectReplaces.cloud,
      );
    });

    test('the host for any other server', () {
      expect(
        connectReplaces(replacingHost: 'nas.local:8080', replacesCloud: false),
        ConnectReplaces.host,
      );
    });
  });

  group('the word on the button that leaves', () {
    test('Not now while the person can still decide', () {
      expect(connectLeaveIsClose(_state()), isFalse);
      expect(
        connectLeaveIsClose(_state(phase: ConnectLinkPhase.failed)),
        isFalse,
      );
    });

    test('Close once the server refused and asking again changes nothing', () {
      expect(
        connectLeaveIsClose(
          _state(phase: ConnectLinkPhase.failed, canRetry: false),
        ),
        isTrue,
      );
    });
  });

  group('when the address line shows', () {
    test('not when it is the https host and nothing more', () {
      expect(connectShowsAddress(_state()), isFalse);
      expect(
        connectShowsAddress(_state(address: 'https://alarm.example.com/')),
        isFalse,
      );
    });

    test('not when the port is already in the host', () {
      expect(
        connectShowsAddress(
          _state(
            host: 'alarm.example.com:8443',
            address: 'https://alarm.example.com:8443',
          ),
        ),
        isFalse,
      );
      expect(
        connectShowsAddress(
          _state(host: '[::1]:8443', address: 'https://[::1]:8443'),
        ),
        isFalse,
      );
    });

    test('a path shows it', () {
      expect(
        connectShowsAddress(
          _state(address: 'https://alarm.example.com/alarms/v1'),
        ),
        isTrue,
      );
      expect(
        connectShowsAddress(_state(address: 'https://alarm.example.com//')),
        isTrue,
      );
    });

    test('a query, a fragment or user info shows it', () {
      for (final address in [
        'https://alarm.example.com?x=1',
        'https://alarm.example.com/?x=1',
        'https://alarm.example.com#top',
        'https://user@alarm.example.com',
        'https://alarm.example.com@other.example.net',
      ]) {
        expect(
          connectShowsAddress(_state(address: address)),
          isTrue,
          reason: address,
        );
      }
    });

    test('plain http always shows it', () {
      expect(
        connectShowsAddress(
          _state(
            host: '192.168.1.20:8080',
            address: 'http://192.168.1.20:8080',
            isPlainHttp: true,
          ),
        ),
        isTrue,
      );
    });

    test('an address that does not match the host shows it', () {
      expect(
        connectShowsAddress(_state(address: 'https://other.example.com')),
        isTrue,
      );
      expect(
        connectShowsAddress(_state(address: 'ftp://alarm.example.com')),
        isTrue,
      );
    });

    test('every failed state shows it, refusals included', () {
      for (final canRetry in [true, false]) {
        expect(
          connectShowsAddress(
            _state(phase: ConnectLinkPhase.failed, canRetry: canRetry),
          ),
          isTrue,
        );
      }
    });

    test('a long host keeps it', () {
      final host = 'a' * (connectHostLongLength + 1);
      expect(
        connectShowsAddress(_state(host: host, address: 'https://$host')),
        isTrue,
      );
      final edge = 'a' * connectHostLongLength;
      expect(
        connectShowsAddress(_state(host: edge, address: 'https://$edge')),
        isFalse,
      );
    });
  });

  group('how the large host fits', () {
    // The sheet's line on a 375 point phone, and the host's full size.
    const line = 327.0;
    const full = 28.0;

    /// A 63-letter label, the longest DNS allows, of letters [em] wide at
    /// text size [scale].
    HostFit fit63({required double em, double scale = 1}) => hostFit(
      fontSize: full,
      longestLabelWidth: 63 * em * full * scale,
      maxWidth: line,
    );

    test('a host that fits stays at full size', () {
      final fit = hostFit(
        fontSize: full,
        longestLabelWidth: 200,
        maxWidth: line,
      );
      expect(
        fit,
        const HostFit(fontSize: full, atFloor: false, breaksInsideLabel: false),
      );
      expect(fit.isCramped, isFalse);
    });

    test('a label a little too wide is scaled down and stays whole', () {
      final fit = hostFit(
        fontSize: full,
        longestLabelWidth: line * 2,
        maxWidth: line,
      );
      expect(fit.fontSize, full / 2);
      expect(fit.breaksInsideLabel, isFalse);
      expect(fit.isCramped, isFalse);
    });

    test('a 63-letter label of wide letters on a narrow phone at large text '
        'is never set below the floor, and wraps inside the label', () {
      for (final scale in [1.0, 1.3, 2.0, 3.0]) {
        final fit = fit63(em: 0.9, scale: scale);
        expect(fit.fontSize, connectHostMinFontSize, reason: '$scale');
        expect(fit.atFloor, isTrue, reason: '$scale');
        expect(fit.breaksInsideLabel, isTrue, reason: '$scale');
        expect(fit.isCramped, isTrue, reason: '$scale');
      }
    });

    test('that label would not have fitted at the old 9 point floor', () {
      // 63 letters of 0.9 em at 9 points and 1.0x are 510 points wide.
      expect(63 * 0.9 * 9, greaterThan(line));
    });

    test('a 63-letter label of narrow letters fits whole above the floor at '
        '1.0x and wraps at 2.0x', () {
      final small = fit63(em: 0.4);
      expect(small.fontSize, greaterThan(connectHostMinFontSize));
      expect(small.breaksInsideLabel, isFalse);
      expect(small.isCramped, isFalse);
      final large = fit63(em: 0.4, scale: 2);
      expect(large.fontSize, connectHostMinFontSize);
      expect(large.breaksInsideLabel, isTrue);
    });

    test('a label that fits exactly at the floor is at the floor and '
        'whole', () {
      final fit = hostFit(
        fontSize: full,
        longestLabelWidth: line * full / connectHostMinFontSize,
        maxWidth: line,
      );
      expect(fit.fontSize, connectHostMinFontSize);
      expect(fit.atFloor, isTrue);
      expect(fit.breaksInsideLabel, isFalse);
      expect(fit.isCramped, isTrue);
    });

    test('the size never goes under the floor or over the full size', () {
      for (final width in [0.0, 1.0, 326.0, 327.0, 328.0, 763.0, 5000.0]) {
        final fit = hostFit(
          fontSize: full,
          longestLabelWidth: width,
          maxWidth: line,
        );
        expect(
          fit.fontSize,
          inInclusiveRange(connectHostMinFontSize, full),
          reason: '$width',
        );
      }
    });

    test('no room at all still gives the floor, not zero', () {
      final fit = hostFit(fontSize: full, longestLabelWidth: 100, maxWidth: 0);
      expect(fit.fontSize, connectHostMinFontSize);
      expect(fit.breaksInsideLabel, isTrue);
    });

    test('the floor is the smallest body size of the design system', () {
      expect(connectHostMinFontSize, 12);
    });
  });

  group('a cramped host and the address line', () {
    test('a cramped host shows the address even when it says nothing '
        'more', () {
      expect(connectShowsAddress(_state()), isFalse);
      expect(connectShowsAddress(_state(), hostIsCramped: true), isTrue);
    });

    test('the 63-letter label shows it both ways: long, and cramped', () {
      final host = '${'w' * 63}.example.com';
      final state = _state(host: host, address: 'https://$host');
      expect(connectShowsAddress(state), isTrue);
      expect(connectShowsAddress(state, hostIsCramped: true), isTrue);
      expect(hostLabels(host).first, '${'w' * 63}.');
    });

    test('a short host at a very large text size shows it once cramped', () {
      const host = 'wwwwwwwwwwwwwwwwwwww.example.com';
      final state = _state(host: host, address: 'https://$host');
      final fit = hostFit(
        fontSize: 28,
        longestLabelWidth: 21 * 0.9 * 28 * 3,
        maxWidth: 327,
      );
      expect(connectShowsAddress(state), isFalse);
      expect(
        connectShowsAddress(state, hostIsCramped: fit.isCramped),
        isTrue,
      );
    });
  });

  group('the host cut into labels', () {
    test('breaks only after a dot, and joins back to the host', () {
      for (final host in [
        'alarm.example.com',
        'pager.operations.internal.example-company.com:8443',
        '192.168.1.20:8080',
        '[2001:db8::1]:8443',
        'localhost',
        'a..b',
        'trailing.',
      ]) {
        expect(hostLabels(host).join(), host, reason: host);
      }
    });

    test('a hyphen, a colon and a port stay inside their label', () {
      expect(hostLabels('pager.example-company.com:8443'), [
        'pager.',
        'example-company.',
        'com:8443',
      ]);
      expect(hostLabels('[::1]:8443'), ['[::1]:8443']);
    });

    test('no host, no labels', () {
      expect(hostLabels(''), isEmpty);
    });
  });
}
