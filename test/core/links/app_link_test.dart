import 'package:critalarm/core/links/app_link.dart';
import 'package:flutter_test/flutter_test.dart';

const _token = 'tk_s3cretValue';

AppLink? _parse(String link) => parseAppLink(Uri.parse(link));

ConnectLink _connect(String link) => _parse(link)! as ConnectLink;

void main() {
  group('routes on https://critalarm.app', () {
    test('a topic link opens that topic', () {
      expect(
        _parse('https://critalarm.app/open/topics/prod'),
        const AppLinkRoute('/topics/prod'),
      );
    });

    test('an incident link opens that incident', () {
      expect(
        _parse('https://critalarm.app/open/incidents/inc_9a8b7c'),
        const AppLinkRoute('/incidents/inc_9a8b7c'),
      );
    });

    test('the Reliability link opens Settings until its route exists', () {
      expect(AppLinkRoutes.reliability, '/settings/reliability');
      expect(AppLinkRoutes.reliabilityTarget, '/settings');
      expect(
        _parse('https://critalarm.app/open/settings/reliability'),
        const AppLinkRoute(AppLinkRoutes.reliabilityTarget),
      );
    });

    test('a trailing slash changes nothing', () {
      expect(
        _parse('https://critalarm.app/open/topics/prod/'),
        const AppLinkRoute('/topics/prod'),
      );
    });

    test('a percent-encoded name is decoded once and encoded once', () {
      expect(
        _parse('https://critalarm.app/open/topics/my%20topic%2Fx'),
        const AppLinkRoute('/topics/my%20topic%2Fx'),
      );
      expect(Uri.decodeComponent('my%20topic%2Fx'), 'my topic/x');
    });

    test('a query or a fragment on a route link is ignored', () {
      expect(
        _parse('https://critalarm.app/open/topics/prod?utm=x#frag'),
        const AppLinkRoute('/topics/prod'),
      );
    });

    test('anything else on the host opens Home', () {
      for (final link in [
        'https://critalarm.app',
        'https://critalarm.app/',
        'https://critalarm.app/pricing',
        'https://critalarm.app/open',
        'https://critalarm.app/open/',
        'https://critalarm.app/open/settings',
        'https://critalarm.app/open/settings/privacy',
        'https://critalarm.app/open/paywall',
        'https://critalarm.app/open/topics',
        'https://critalarm.app/open/nothing/here',
        // Not under /open/, so not the app's route.
        'https://critalarm.app/topics/prod',
        'https://critalarm.app/incidents/inc_1',
      ]) {
        expect(_parse(link), AppLinkRoute.home, reason: link);
      }
    });

    test('a path with extra segments opens Home', () {
      for (final link in [
        'https://critalarm.app/open/topics/prod/messages',
        'https://critalarm.app/open/incidents/inc_1/ack',
        'https://critalarm.app/open/settings/reliability/more',
        'https://critalarm.app/connect/extra#url=https%3A%2F%2Fa.example&token=$_token',
      ]) {
        expect(_parse(link), AppLinkRoute.home, reason: link);
      }
    });

    test('a broken percent escape opens Home', () {
      expect(
        _parse('https://critalarm.app/connect#url=%zz&token=$_token'),
        AppLinkRoute.home,
      );
    });
  });

  group('routes on critalarm://', () {
    test('the same routes, with and without open', () {
      expect(
        _parse('critalarm://topics/prod'),
        const AppLinkRoute('/topics/prod'),
      );
      expect(
        _parse('critalarm://open/topics/prod'),
        const AppLinkRoute('/topics/prod'),
      );
      expect(
        _parse('critalarm://incidents/inc_9a8b7c'),
        const AppLinkRoute('/incidents/inc_9a8b7c'),
      );
      expect(
        _parse('critalarm://open/incidents/inc_9a8b7c'),
        const AppLinkRoute('/incidents/inc_9a8b7c'),
      );
      expect(
        _parse('critalarm://settings/reliability'),
        const AppLinkRoute(AppLinkRoutes.reliabilityTarget),
      );
      expect(
        _parse('critalarm://open/settings/reliability'),
        const AppLinkRoute(AppLinkRoutes.reliabilityTarget),
      );
    });

    test('percent-encoded values survive', () {
      expect(
        _parse('critalarm://topics/my%20topic%2Fx'),
        const AppLinkRoute('/topics/my%20topic%2Fx'),
      );
    });

    test('anything else opens Home', () {
      for (final link in [
        'critalarm://',
        'critalarm://home',
        'critalarm://reminder/fire_drill',
        'critalarm://topics',
        'critalarm://topics/a/b',
        'critalarm://settings/privacy',
        'critalarm://open',
      ]) {
        expect(_parse(link), AppLinkRoute.home, reason: link);
      }
    });
  });

  group("links that are not the app's", () {
    test('another host gives nothing', () {
      for (final link in [
        'https://example.com/open/topics/prod',
        'https://www.critalarm.app/open/topics/prod',
        'https://critalarm.app.evil.example/connect#url=https%3A%2F%2Fa.example&token=$_token',
        'https://evil.example/connect?url=https%3A%2F%2Fa.example&token=$_token',
        'https://critalarm.app:8443/open/topics/prod',
      ]) {
        expect(_parse(link), isNull, reason: link);
      }
    });

    test('a bad scheme gives nothing', () {
      for (final link in [
        'http://critalarm.app/open/topics/prod',
        'http://critalarm.app/connect#url=https%3A%2F%2Fa.example&token=$_token',
        'ftp://critalarm.app/open/topics/prod',
        'file:///tmp/open/topics/prod',
        'critalarms://topics/prod',
        '/open/topics/prod',
      ]) {
        expect(_parse(link), isNull, reason: link);
      }
    });

    test('text that is no link gives nothing', () {
      expect(parseAppLinkText('::not a uri::'), isNull);
      expect(parseAppLinkText(''), isNull);
      expect(
        parseAppLinkText('https://critalarm.app/open/topics/prod'),
        const AppLinkRoute('/topics/prod'),
      );
    });
  });

  group('connect links', () {
    test('the https form reads the fragment', () {
      final link = _connect(
        'https://critalarm.app/connect#url=https%3A%2F%2Falarm.example.com&token=$_token',
      );
      expect(link.serverUrl, Uri.parse('https://alarm.example.com'));
      expect(link.token, _token);
    });

    test('the critalarm form reads the query', () {
      final link = _connect(
        'critalarm://connect?url=https%3A%2F%2Falarm.example.com&token=$_token',
      );
      expect(link.serverUrl, Uri.parse('https://alarm.example.com'));
      expect(link.token, _token);
    });

    test('each scheme takes the other form too', () {
      expect(
        _connect(
          'https://critalarm.app/connect?url=https%3A%2F%2Fa.example&token=$_token',
        ).token,
        _token,
      );
      expect(
        _connect(
          'critalarm://connect#url=https%3A%2F%2Fa.example&token=$_token',
        ).serverUrl,
        Uri.parse('https://a.example'),
      );
    });

    test('the fragment wins over the query', () {
      final link = _connect(
        'https://critalarm.app/connect'
        '?url=https%3A%2F%2Fquery.example&token=tk_query'
        '#url=https%3A%2F%2Ffragment.example&token=tk_fragment',
      );
      expect(link.serverUrl.host, 'fragment.example');
      expect(link.token, 'tk_fragment');
    });

    test('a value the fragment lacks comes from the query', () {
      final link = _connect(
        'https://critalarm.app/connect?token=$_token#url=https%3A%2F%2Fa.example',
      );
      expect(link.serverUrl.host, 'a.example');
      expect(link.token, _token);
    });

    test('percent-encoded values are decoded', () {
      final link = _connect(
        'https://critalarm.app/connect'
        '#url=https%3A%2F%2Falarm.example.com%3A8443%2Fbase'
        '&token=tk_a%2Bb%2Fc%3D',
      );
      expect(link.serverUrl, Uri.parse('https://alarm.example.com:8443/base'));
      expect(link.token, 'tk_a+b/c=');
    });

    test('a server address that was not encoded still reads', () {
      final link = _connect(
        'critalarm://connect?url=https://alarm.example.com&token=$_token',
      );
      expect(link.serverUrl, Uri.parse('https://alarm.example.com'));
    });

    test('a missing or empty token opens Home', () {
      for (final link in [
        'https://critalarm.app/connect#url=https%3A%2F%2Fa.example',
        'https://critalarm.app/connect#url=https%3A%2F%2Fa.example&token=',
        'https://critalarm.app/connect#url=https%3A%2F%2Fa.example&token=%20',
        'critalarm://connect?url=https%3A%2F%2Fa.example',
      ]) {
        expect(_parse(link), AppLinkRoute.home, reason: link);
      }
    });

    test('a missing server address opens Home', () {
      for (final link in [
        'https://critalarm.app/connect',
        'https://critalarm.app/connect#token=$_token',
        'critalarm://connect?token=$_token',
        'critalarm://connect',
      ]) {
        expect(_parse(link), AppLinkRoute.home, reason: link);
      }
    });

    test('a server address that is not https opens Home', () {
      for (final url in [
        'http://alarm.example.com',
        'http://8.8.8.8',
        'http://172.32.0.1',
        'http://192.169.1.1',
        'http://nas.local',
        'http://[2001:db8::1]',
        'ftp://10.0.0.5',
        'javascript:alert(1)',
        'alarm.example.com',
        'https://',
        'critalarm://connect',
      ]) {
        final link =
            'https://critalarm.app/connect#url=${Uri.encodeComponent(url)}&token=$_token';
        expect(_parse(link), AppLinkRoute.home, reason: url);
      }
    });

    test('http is allowed for this device and for a private network', () {
      for (final url in [
        'http://localhost:8080',
        'http://127.0.0.1:8080',
        'http://10.0.0.5',
        'http://172.16.0.1',
        'http://172.31.255.254',
        'http://192.168.1.20:3000',
        'http://169.254.10.10',
        'http://[::1]:8080',
        'http://[fd12:3456:789a::1]',
        'http://[fe80::1]',
        'http://[::ffff:192.168.1.5]',
      ]) {
        final link =
            'https://critalarm.app/connect#url=${Uri.encodeComponent(url)}&token=$_token';
        expect(_connect(link).serverUrl, Uri.parse(url), reason: url);
      }
    });

    test('toString hides the token', () {
      final link = _connect(
        'https://critalarm.app/connect#url=https%3A%2F%2Falarm.example.com&token=$_token',
      );
      expect('$link', 'ConnectLink(host: alarm.example.com, token: hidden)');
      expect('$link', isNot(contains(_token)));
    });
  });
}
