import 'dart:async';

import 'package:critalarm/core/links/app_link.dart';
import 'package:critalarm/core/links/connect_link_holder.dart';
import 'package:critalarm/core/push/push_deep_link.dart';
import 'package:critalarm/core/push/push_host.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _token = 'tk_s3cretValue';
const _https =
    'https://critalarm.app/connect#url=https%3A%2F%2Falarm.example.com&token=$_token';
const _custom =
    'critalarm://connect?url=https%3A%2F%2Falarm.example.com&token=$_token';

ConnectLink _link([String token = _token]) => ConnectLink(
  serverUrl: Uri.parse('https://alarm.example.com'),
  token: token,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConnectLinkHolder', () {
    late ConnectLinkHolder holder;

    setUp(() => holder = ConnectLinkHolder());
    tearDown(() => holder.dispose());

    test('holds a link that arrived before anyone listened', () {
      holder.offer(_link());
      expect(holder.pending, _link());
    });

    test('sends a link to whoever is listening', () async {
      final seen = holder.links.first;
      holder.offer(_link());
      expect(await seen, _link());
    });

    test('take hands the link over once', () {
      holder.offer(_link());
      expect(holder.take(), _link());
      expect(holder.take(), isNull);
      expect(holder.pending, isNull);
    });

    test('a second link replaces the first', () {
      holder
        ..offer(_link('tk_first'))
        ..offer(_link('tk_second'));
      expect(holder.take()?.token, 'tk_second');
    });

    test('clear forgets the link', () {
      holder
        ..offer(_link())
        ..clear();
      expect(holder.pending, isNull);
    });

    test('toString never shows the token', () {
      expect('$holder', 'ConnectLinkHolder(empty)');
      holder.offer(_link());
      expect('$holder', isNot(contains(_token)));
      expect('${holder.pending}', isNot(contains(_token)));
      expect('${[holder.pending]}', isNot(contains(_token)));
      expect('${{'link': holder.pending}}', isNot(contains(_token)));
    });
  });

  group('a connect link tapped outside the app', () {
    const channel = MethodChannel(PushHost.channelName);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late ConnectLinkHolder holder;
    late PushHost host;
    late List<String> printed;
    late DebugPrintCallback realDebugPrint;

    Future<void> tapFromPlatform(Map<String, String> tap) =>
        messenger.handlePlatformMessage(
          PushHost.channelName,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('onNotificationTap', tap),
          ),
          (_) {},
        );

    void platformHolds(Map<String, String>? tap) {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async =>
            call.method == 'takePending' && tap != null ? {'tap': tap} : null,
      );
    }

    /// Runs [body] and collects every line it prints, by either road.
    Future<void> capturing(Future<void> Function() body) => runZoned(
      body,
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => printed.add(line),
      ),
    );

    setUp(() {
      printed = [];
      realDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
      platformHolds(null);
      holder = ConnectLinkHolder();
      host = PushHost(null, holder);
    });

    tearDown(() async {
      debugPrint = realDebugPrint;
      await host.dispose();
      await holder.dispose();
      messenger.setMockMethodCallHandler(channel, null);
    });

    for (final (name, link) in [('https', _https), ('critalarm', _custom)]) {
      test(
        'a warm $name link reaches the holder and opens no screen',
        () async {
          final routes = <String>[];
          final subscription = host.deepLinks.listen(routes.add);
          await capturing(
            () => tapFromPlatform({PushHost.linkKey: link, 'tap_id': '1'}),
          );
          await Future<void>.delayed(Duration.zero);
          expect(holder.pending, _link());
          expect(routes, isEmpty);
          expect(printed.join('\n'), isNot(contains(_token)));
          await subscription.cancel();
        },
      );

      test('a cold $name link reaches the holder and opens Home', () async {
        platformHolds({PushHost.linkKey: link, 'tap_id': '1'});
        String? route;
        await capturing(() async => route = await host.takePendingRoute());
        expect(route, isNull);
        expect(holder.pending, _link());
        expect(printed.join('\n'), isNot(contains(_token)));
      });
    }

    test('the same link held and sent is offered once', () async {
      final seen = <ConnectLink>[];
      final subscription = holder.links.listen(seen.add);
      const tap = {PushHost.linkKey: _https, 'tap_id': '7'};
      platformHolds(tap);
      await tapFromPlatform(tap);
      expect(await host.takePendingRoute(), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(seen, hasLength(1));
      await subscription.cancel();
    });

    test('a second connect link replaces the first', () async {
      const second =
          'https://critalarm.app/connect#url=https%3A%2F%2Fother.example.com&token=tk_second';
      final seen = <ConnectLink>[];
      final subscription = holder.links.listen(seen.add);
      await tapFromPlatform({PushHost.linkKey: _https, 'tap_id': '1'});
      await tapFromPlatform({PushHost.linkKey: second, 'tap_id': '2'});
      await Future<void>.delayed(Duration.zero);
      expect(seen, hasLength(2));
      expect(holder.pending?.serverUrl.host, 'other.example.com');
      expect(holder.pending?.token, 'tk_second');
      expect(holder.take()?.token, 'tk_second');
      expect(holder.take(), isNull);
      await subscription.cancel();
    });

    test('an https connect link with the token in the query fills '
        'nothing', () async {
      final routes = <String>[];
      final subscription = host.deepLinks.listen(routes.add);
      await capturing(
        () => tapFromPlatform({
          PushHost.linkKey:
              'https://critalarm.app/connect?url=https%3A%2F%2Falarm.example.com&token=$_token',
          'tap_id': '1',
        }),
      );
      await Future<void>.delayed(Duration.zero);
      expect(routes, ['/']);
      expect(holder.pending, isNull);
      expect(printed.join('\n'), isNot(contains(_token)));
      await subscription.cancel();
    });

    test('a link written with a dot segment opens Home and fills '
        'nothing', () async {
      final routes = <String>[];
      final subscription = host.deepLinks.listen(routes.add);
      await tapFromPlatform({
        PushHost.linkKey:
            'https://critalarm.app/open/../connect#url=https%3A%2F%2Falarm.example.com&token=$_token',
        'tap_id': '1',
      });
      await Future<void>.delayed(Duration.zero);
      expect(routes, ['/']);
      expect(holder.pending, isNull);
      await subscription.cancel();
    });

    test('a link to the create-topic word opens Home', () async {
      platformHolds({
        PushHost.linkKey: 'https://critalarm.app/open/topics/new',
        'tap_id': '1',
      });
      expect(await host.takePendingRoute(), '/');
    });

    test('a refused connect link opens Home and fills nothing', () async {
      final routes = <String>[];
      final subscription = host.deepLinks.listen(routes.add);
      await capturing(
        () => tapFromPlatform({
          PushHost.linkKey:
              'https://critalarm.app/connect#url=http%3A%2F%2Falarm.example.com&token=$_token',
          'tap_id': '1',
        }),
      );
      await Future<void>.delayed(Duration.zero);
      expect(routes, ['/']);
      expect(holder.pending, isNull);
      expect(printed.join('\n'), isNot(contains(_token)));
      await subscription.cancel();
    });

    test('a route link opens its screen and fills nothing', () async {
      final routes = <String>[];
      final subscription = host.deepLinks.listen(routes.add);
      await tapFromPlatform({
        PushHost.linkKey: 'https://critalarm.app/open/topics/prod',
        'tap_id': '1',
      });
      await tapFromPlatform({
        PushHost.linkKey: 'https://critalarm.app/open/incidents/inc_1',
        'tap_id': '2',
      });
      await tapFromPlatform({
        PushHost.linkKey: 'https://critalarm.app/pricing',
        'tap_id': '3',
      });
      await Future<void>.delayed(Duration.zero);
      expect(routes, ['/topics/prod', '/incidents/inc_1', '/']);
      expect(holder.pending, isNull);
      await subscription.cancel();
    });

    test('a cold route link is the first screen', () async {
      platformHolds({
        PushHost.linkKey: 'https://critalarm.app/open/topics/prod',
        'tap_id': '1',
      });
      expect(await host.takePendingRoute(), '/topics/prod');
    });

    test('a link on another host opens nothing', () async {
      final routes = <String>[];
      final subscription = host.deepLinks.listen(routes.add);
      await tapFromPlatform({
        PushHost.linkKey:
            'https://example.com/connect#url=https%3A%2F%2Fa.example&token=$_token',
        'tap_id': '1',
      });
      await Future<void>.delayed(Duration.zero);
      expect(routes, isEmpty);
      expect(holder.pending, isNull);
      await subscription.cancel();
    });

    test('a widget or notification tap still routes as before', () async {
      final routes = <String>[];
      final subscription = host.deepLinks.listen(routes.add);
      await tapFromPlatform({'incident_id': 'inc_1', 'tap_id': '1'});
      await tapFromPlatform({'topic': 'prod', 'tap_id': '2'});
      await tapFromPlatform({'open': 'home', 'tap_id': '3'});
      await Future<void>.delayed(Duration.zero);
      expect(routes, ['/incidents/inc_1', '/topics/prod', '/']);
      await subscription.cancel();
    });

    test('a connect link that reaches the router has no route', () {
      final location = PushDeepLink.fromAppUri(Uri.parse(_custom));
      expect(location, '/');
      expect(location, isNot(contains(_token)));
    });
  });
}
