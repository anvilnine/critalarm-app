import 'package:critalarm/features/onboarding/domain/connect/connect_morph.dart';
import 'package:critalarm/features/onboarding/domain/connect/connect_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('how the spare room is shared', () {
    test('the Cloud state gives all of it to the picture', () {
      final split = connectMorphSplit(own: 0, leftover: 200, heroBase: 0);
      expect(split.hero, 200);
      expect(split.tail, 0);
    });

    test('the own server state leaves all of it under the form', () {
      final split = connectMorphSplit(own: 1, leftover: 200, heroBase: 148);
      expect(split.hero, 148);
      expect(split.tail, 200);
    });

    test('part of the way across, the two share it', () {
      final split = connectMorphSplit(own: 0.25, leftover: 200, heroBase: 37);
      expect(split.hero, 37 + 150);
      expect(split.tail, 50);
    });

    test('the parts always add up to the base and the room', () {
      for (var i = 0; i <= 20; i++) {
        final own = i / 20;
        final split = connectMorphSplit(
          own: own,
          leftover: 123,
          heroBase: connectMorphHeroBase(own: own, full: 148),
        );
        expect(
          split.hero + split.tail,
          closeTo(connectMorphHeroBase(own: own, full: 148) + 123, 1e-9),
        );
      }
    });

    test('a page with no room to spare keeps only the base', () {
      final split = connectMorphSplit(own: 0.5, leftover: -40, heroBase: 74);
      expect(split.hero, 74);
      expect(split.tail, 0);
    });

    test('a value outside 0 to 1 is held to the ends', () {
      expect(connectMorphSplit(own: -1, leftover: 10, heroBase: 0).tail, 0);
      expect(connectMorphSplit(own: 2, leftover: 10, heroBase: 0).hero, 0);
      expect(connectMorphHeroBase(own: 3, full: 148), 148);
      expect(connectMorphHeroBase(own: -1, full: 148), 0);
    });
  });

  group('the pinned bar', () {
    test('is the Cloud bar at 0 and the own server bar at 1', () {
      expect(
        connectMorphBarButtons(own: 0, cloud: 76, ownServer: 108),
        76,
      );
      expect(
        connectMorphBarButtons(own: 1, cloud: 76, ownServer: 108),
        108,
      );
    });

    test('grows evenly in between', () {
      expect(
        connectMorphBarButtons(own: 0.5, cloud: 76, ownServer: 108),
        92,
      );
    });
  });

  group('the faces of the card', () {
    test('show one face at each end', () {
      expect(connectMorphFades(0), (cloud: 1.0, own: 0.0));
      expect(connectMorphFades(1), (cloud: 0.0, own: 1.0));
    });

    test('never print over each other beyond a sliver', () {
      for (var i = 0; i <= 100; i++) {
        final fades = connectMorphFades(i / 100);
        expect(fades.cloud * fades.own, lessThan(0.05));
      }
    });

    test('the Cloud card is gone before half way', () {
      expect(connectMorphFades(0.5).cloud, 0);
      expect(connectMorphFades(0.3).own, 0);
    });

    test('each face moves one way only', () {
      var cloud = 1.0;
      var own = 0.0;
      for (var i = 1; i <= 100; i++) {
        final fades = connectMorphFades(i / 100);
        expect(fades.cloud, lessThanOrEqualTo(cloud));
        expect(fades.own, greaterThanOrEqualTo(own));
        cloud = fades.cloud;
        own = fades.own;
      }
    });
  });

  group('when a switch plays', () {
    test('only when the user asked and motion is on', () {
      expect(connectMorphPlays(userAsked: true, reduceMotion: false), isTrue);
      expect(connectMorphPlays(userAsked: true, reduceMotion: true), isFalse);
      expect(connectMorphPlays(userAsked: false, reduceMotion: false), isFalse);
    });
  });

  group('the dot while the lit route changes', () {
    const cloud = (
      lit: ConnectRoute.cloud,
      status: ConnectRouteStatus.waiting,
    );
    const own = (
      lit: ConnectRoute.ownServer,
      status: ConnectRouteStatus.waiting,
    );

    test('keeps its clock when only the lit route changes', () {
      expect(routeDotKeepsClock(cloud, own), isTrue);
      expect(routeDotKeepsClock(own, cloud), isTrue);
    });

    test('starts over when the status changes', () {
      expect(
        routeDotKeepsClock(
          cloud,
          (lit: ConnectRoute.cloud, status: ConnectRouteStatus.connecting),
        ),
        isFalse,
      );
    });
  });

  group('a picture that grows from nothing', () {
    test('is hidden below its fade and whole from its full height', () {
      expect(routesPictureOpacityAt(0), 0);
      expect(routesPictureOpacityAt(routesPictureFadeFrom), 0);
      expect(routesPictureOpacityAt(routesPictureFullFrom), 1);
      expect(routesPictureOpacityAt(300), 1);
    });

    test('fades in on the way up', () {
      expect(routesPictureOpacityAt(110), closeTo(0.5, 1e-9));
    });
  });
}
