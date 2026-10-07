import 'package:critalarm/features/onboarding/domain/connect/connect_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ConnectRoutesView viewFor({
    bool isSelfHosting = false,
    bool isConnecting = false,
    bool isConnected = false,
    bool hasFailed = false,
  }) => connectRoutesFor(
    isSelfHosting: isSelfHosting,
    isConnecting: isConnecting,
    isConnected: isConnected,
    hasFailed: hasFailed,
  );

  group('which route is lit', () {
    test('before any choice the Cloud route is lit and waits', () {
      expect(
        viewFor(),
        (lit: ConnectRoute.cloud, status: ConnectRouteStatus.waiting),
      );
    });

    test('opening the form for your own server lights the other route', () {
      expect(
        viewFor(isSelfHosting: true),
        (lit: ConnectRoute.ownServer, status: ConnectRouteStatus.waiting),
      );
    });

    test('a connect on its way shows on the route that was picked', () {
      expect(
        viewFor(isConnecting: true),
        (lit: ConnectRoute.cloud, status: ConnectRouteStatus.connecting),
      );
      expect(
        viewFor(isSelfHosting: true, isConnecting: true),
        (lit: ConnectRoute.ownServer, status: ConnectRouteStatus.connecting),
      );
    });

    test('a connect that landed shows as connected', () {
      expect(
        viewFor(isConnected: true),
        (lit: ConnectRoute.cloud, status: ConnectRouteStatus.connected),
      );
      expect(
        viewFor(isSelfHosting: true, isConnected: true),
        (lit: ConnectRoute.ownServer, status: ConnectRouteStatus.connected),
      );
    });

    test('a failure shows the lit route broken', () {
      expect(
        viewFor(hasFailed: true),
        (lit: ConnectRoute.cloud, status: ConnectRouteStatus.broken),
      );
      expect(
        viewFor(isSelfHosting: true, hasFailed: true),
        (lit: ConnectRoute.ownServer, status: ConnectRouteStatus.broken),
      );
    });

    test('a new try wins over the failure before it', () {
      expect(
        viewFor(isConnecting: true, hasFailed: true).status,
        ConnectRouteStatus.connecting,
      );
    });

    test('connected wins over everything', () {
      expect(
        viewFor(isConnecting: true, isConnected: true, hasFailed: true).status,
        ConnectRouteStatus.connected,
      );
    });
  });

  group('the dot', () {
    test('travels while the route waits or connects, and only then', () {
      expect(connectRouteHasDot(ConnectRouteStatus.waiting), isTrue);
      expect(connectRouteHasDot(ConnectRouteStatus.connecting), isTrue);
      expect(connectRouteHasDot(ConnectRouteStatus.connected), isFalse);
      expect(connectRouteHasDot(ConnectRouteStatus.broken), isFalse);
    });

    test('runs from the tool to the phone', () {
      expect(routeDotProgressAt(0), 0);
      expect(routeDotProgressAt(routeDotTravelTakes / 2), closeTo(0.5, 1e-9));
      expect(routeDotProgressAt(routeDotTravelTakes), closeTo(1, 1e-9));
    });

    test('is away between two runs, then starts over at the tool', () {
      expect(routeDotProgressAt(routeDotTravelTakes + 0.1), isNull);
      expect(
        routeDotProgressAt(routeDotTravelTakes + routeDotRests - 0.01),
        isNull,
      );
      expect(
        routeDotProgressAt(routeDotTravelTakes + routeDotRests + 0.01),
        closeTo(0, 0.01),
      );
      expect(
        routeDotProgressAt(
          routeDotTravelTakes + routeDotRests + routeDotTravelTakes / 2,
        ),
        closeTo(0.5, 1e-9),
      );
    });

    test('keeps the same pace on every later run', () {
      const lap = routeDotRests + routeDotTravelTakes;
      final first = routeDotProgressAt(routeDotTravelTakes + routeDotRests + 1);
      final third = routeDotProgressAt(
        routeDotTravelTakes + routeDotRests + 1 + 2 * lap,
      );
      expect(third, closeTo(first!, 1e-9));
    });

    test('the first run after a choice is short, the later ones are not', () {
      const fast = routeDotChosenRunTakes;
      expect(routeDotProgressAt(fast / 2, firstRunTakes: fast), 0.5);
      expect(routeDotProgressAt(fast, firstRunTakes: fast), 1);
      expect(
        routeDotProgressAt(
          fast + routeDotRests + routeDotTravelTakes / 2,
          firstRunTakes: fast,
        ),
        closeTo(0.5, 1e-9),
      );
    });

    test('reaches the phone once on its first run', () {
      const fast = routeDotChosenRunTakes;
      expect(
        routeDotFirstArrivedBetween(0.38, 0.41, firstRunTakes: fast),
        isTrue,
      );
      expect(
        routeDotFirstArrivedBetween(0.1, 0.2, firstRunTakes: fast),
        isFalse,
      );
      // The later runs do not count.
      expect(
        routeDotFirstArrivedBetween(0.41, 5, firstRunTakes: fast),
        isFalse,
      );
    });
  });
}
