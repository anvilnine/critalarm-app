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
