import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:critalarm/core/device/native_fold.dart';
import 'package:critalarm/design/fold.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

// The iPhone Duo inner display: 951 x 669 open, fold at x 475.5; 669 x 951
// upright or on a table, fold at y 475.5.
void main() {
  group('NativeFold.fromEvent', () {
    test('reads the map the native side sends', () {
      final fold = NativeFold.fromEvent(const {
        'left': 475.5,
        'top': 0,
        'width': 0,
        'height': 669,
        'marginLeft': 12,
        'marginTop': 0,
        'marginRight': 12,
        'marginBottom': 0,
        'active': true,
      });
      expect(
        fold,
        const NativeFold(
          bounds: Rect.fromLTWH(475.5, 0, 0, 669),
          margins: EdgeInsets.symmetric(horizontal: 12),
          isActive: true,
        ),
      );
    });

    test('margins are optional', () {
      final fold = NativeFold.fromEvent(const {
        'left': 0,
        'top': 475.5,
        'width': 669,
        'height': 0,
        'active': false,
      });
      expect(fold?.margins, EdgeInsets.zero);
      expect(fold?.isActive, isFalse);
    });

    test('null and anything malformed are no fold', () {
      expect(NativeFold.fromEvent(null), isNull);
      expect(NativeFold.fromEvent('fold'), isNull);
      expect(NativeFold.fromEvent(const {'left': 1}), isNull);
      expect(
        NativeFold.fromEvent(const {
          'left': 0,
          'top': 0,
          'width': -1,
          'height': 10,
          'active': true,
        }),
        isNull,
      );
      expect(
        NativeFold.fromEvent(const {
          'left': 0,
          'top': 0,
          'width': 0,
          'height': 10,
          'active': 'yes',
        }),
        isNull,
      );
      expect(
        NativeFold.fromEvent(const {
          'left': double.nan,
          'top': 0,
          'width': 0,
          'height': 10,
          'active': true,
        }),
        isNull,
      );
    });
  });

  group('displayFeaturesWithFold', () {
    const open = Size(951, 669);
    const upright = Size(669, 951);

    test('no fold leaves the features as they are', () {
      expect(displayFeaturesWithFold(const [], null, open), isEmpty);
    });

    test('an inactive fold adds nothing', () {
      const fold = NativeFold(
        bounds: Rect.fromLTWH(475.5, 0, 0, 669),
        isActive: false,
      );
      expect(displayFeaturesWithFold(const [], fold, open), isEmpty);
    });

    test('an active vertical fold reads as book posture', () {
      const fold = NativeFold(
        bounds: Rect.fromLTWH(475.5, 0, 0, 669),
        isActive: true,
      );
      final features = displayFeaturesWithFold(const [], fold, open);
      expect(features, hasLength(1));
      expect(features.single.type, DisplayFeatureType.fold);
      expect(features.single.state, DisplayFeatureState.postureHalfOpened);
      final appFold = AppFold.fromFeatures(features, open);
      expect(appFold.isBook, isTrue);
      expect(appFold.bounds, const Rect.fromLTWH(475.5, 0, 0, 669));
    });

    test('an active horizontal fold reads as tabletop posture', () {
      const fold = NativeFold(
        bounds: Rect.fromLTWH(0, 475.5, 669, 0),
        isActive: true,
      );
      final appFold = AppFold.fromFeatures(
        displayFeaturesWithFold(const [], fold, upright),
        upright,
      );
      expect(appFold.isTabletop, isTrue);
      expect(appFold.bounds, const Rect.fromLTWH(0, 475.5, 669, 0));
    });

    test('a division short of the window ends still spans it', () {
      // UIKit may leave the safe area off the ends of the region.
      const fold = NativeFold(
        bounds: Rect.fromLTRB(474, 20, 477, 640),
        isActive: true,
      );
      final features = displayFeaturesWithFold(const [], fold, open);
      expect(features.single.bounds, const Rect.fromLTRB(474, 0, 477, 669));
      expect(AppFold.fromFeatures(features, open).isBook, isTrue);
    });

    test('a fold the engine already reports wins', () {
      const engine = DisplayFeature(
        bounds: Rect.fromLTWH(400, 0, 0, 669),
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureHalfOpened,
      );
      const fold = NativeFold(
        bounds: Rect.fromLTWH(475.5, 0, 0, 669),
        isActive: true,
      );
      expect(displayFeaturesWithFold(const [engine], fold, open), const [
        engine,
      ]);
    });

    test('a cutout stays and the fold joins it', () {
      const cutout = DisplayFeature(
        bounds: Rect.fromLTWH(300, 0, 100, 30),
        type: DisplayFeatureType.cutout,
        state: DisplayFeatureState.unknown,
      );
      const fold = NativeFold(
        bounds: Rect.fromLTWH(475.5, 0, 0, 669),
        isActive: true,
      );
      final features = displayFeaturesWithFold(const [cutout], fold, open);
      expect(features, hasLength(2));
      expect(features.first, cutout);
    });
  });
}
