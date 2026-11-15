import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:critalarm/core/device/fold_scope.dart';
import 'package:critalarm/design/fold.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_ext/foldable_ext.dart';

// The iPhone Duo inner display: 951 x 669 open, with a 40 point division
// around x 475.5; 669 x 951 upright or on a table, division around y 475.5.
const _open = Size(951, 669);
const _upright = Size(669, 951);

ReservedRegion _division(Rect bounds, {bool isActive = true}) => ReservedRegion(
  kind: ReservedRegionKind.division,
  bounds: bounds,
  isActive: isActive,
);

/// What reaches `MediaQuery` on an iPhone Duo: the engine reports nothing
/// there, so the list is what the package publishes for [regions].
List<DisplayFeature> _onDuo(
  List<ReservedRegion> regions,
  HingeStatus status,
  Size window,
) {
  final published = DisplayFeatureBridge.build(
    mode: appFoldBridgeMode,
    regions: regions,
    status: status,
  );
  return foldFeaturesAcrossWindow(published, published, window);
}

void main() {
  group('an iPhone Duo', () {
    test('partly folded with an upright division reads as book', () {
      final features = _onDuo(
        [_division(const Rect.fromLTWH(455.5, 0, 40, 669))],
        HingeStatus.partiallyOpen,
        _open,
      );
      expect(features, hasLength(1));
      expect(features.single.type, DisplayFeatureType.fold);
      expect(features.single.state, DisplayFeatureState.postureHalfOpened);
      final fold = AppFold.fromFeatures(features, _open);
      expect(fold.isBook, isTrue);
      expect(fold.bounds, const Rect.fromLTWH(455.5, 0, 40, 669));
    });

    test('partly folded with a level division reads as tabletop', () {
      final features = _onDuo(
        [_division(const Rect.fromLTWH(0, 455.5, 669, 40))],
        HingeStatus.partiallyOpen,
        _upright,
      );
      final fold = AppFold.fromFeatures(features, _upright);
      expect(fold.isTabletop, isTrue);
      expect(fold.bounds, const Rect.fromLTWH(0, 455.5, 669, 40));
    });

    test('a division short of the window ends still spans it', () {
      // UIKit may leave the safe area off the ends of the region.
      final features = _onDuo(
        [_division(const Rect.fromLTRB(455.5, 20, 495.5, 640))],
        HingeStatus.partiallyOpen,
        _open,
      );
      expect(features.single.bounds, const Rect.fromLTRB(455.5, 0, 495.5, 669));
      expect(features.single.state, DisplayFeatureState.postureHalfOpened);
      expect(AppFold.fromFeatures(features, _open).isBook, isTrue);
    });

    test('a level division short of the window sides still spans it', () {
      final features = _onDuo(
        [_division(const Rect.fromLTRB(20, 455.5, 640, 495.5))],
        HingeStatus.partiallyOpen,
        _upright,
      );
      expect(features.single.bounds, const Rect.fromLTRB(0, 455.5, 669, 495.5));
      expect(AppFold.fromFeatures(features, _upright).isTabletop, isTrue);
    });

    test('flat, closed or with no reading has no fold', () {
      for (final status in [
        HingeStatus.fullyOpen,
        HingeStatus.closed,
        HingeStatus.unknown,
      ]) {
        final features = _onDuo(
          [_division(const Rect.fromLTWH(455.5, 0, 40, 669))],
          status,
          _open,
        );
        expect(features, isEmpty, reason: status.name);
        expect(
          AppFold.fromFeatures(features, _open).isNone,
          isTrue,
          reason: status.name,
        );
      }
    });

    test('a division that is not active is no fold', () {
      final features = _onDuo(
        [_division(const Rect.fromLTWH(455.5, 0, 40, 669), isActive: false)],
        HingeStatus.partiallyOpen,
        _open,
      );
      expect(features, isEmpty);
    });

    test('a camera cutout stays and the fold joins it', () {
      final features = _onDuo(
        [
          const ReservedRegion(
            kind: ReservedRegionKind.occlusion,
            bounds: Rect.fromLTWH(300, 0, 100, 30),
            isActive: true,
          ),
          _division(const Rect.fromLTRB(455.5, 20, 495.5, 640)),
        ],
        HingeStatus.partiallyOpen,
        _open,
      );
      expect(features, hasLength(2));
      expect(features.first.type, DisplayFeatureType.cutout);
      expect(features.first.bounds, const Rect.fromLTWH(300, 0, 100, 30));
      expect(features.last.bounds, const Rect.fromLTRB(455.5, 0, 495.5, 669));
    });
  });

  group('foldFeaturesAcrossWindow', () {
    const published = DisplayFeature(
      bounds: Rect.fromLTRB(455.5, 20, 495.5, 640),
      type: DisplayFeatureType.fold,
      state: DisplayFeatureState.postureHalfOpened,
    );

    test('a fold the engine already reports is never there twice', () {
      const engine = DisplayFeature(
        bounds: Rect.fromLTWH(400, 0, 0, 669),
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureHalfOpened,
      );
      expect(
        foldFeaturesAcrossWindow(
          const [engine, published],
          const [published],
          _open,
        ),
        const [engine],
      );
    });

    test('a hinge the engine already reports wins too', () {
      const hinge = DisplayFeature(
        bounds: Rect.fromLTWH(460, 0, 30, 669),
        type: DisplayFeatureType.hinge,
        state: DisplayFeatureState.postureFlat,
      );
      expect(
        foldFeaturesAcrossWindow(
          const [published, hinge],
          const [published],
          _open,
        ),
        const [hinge],
      );
    });

    test('with nothing published the engine list is handed back as it '
        'is', () {
      // Android with the division switch off.
      const cutout = DisplayFeature(
        bounds: Rect.fromLTWH(300, 0, 100, 30),
        type: DisplayFeatureType.cutout,
        state: DisplayFeatureState.unknown,
      );
      const halfOpened = DisplayFeature(
        bounds: Rect.fromLTWH(400, 0, 0, 800),
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureHalfOpened,
      );
      final engine = [cutout, halfOpened];
      expect(
        identical(
          foldFeaturesAcrossWindow(engine, const [], const Size(800, 800)),
          engine,
        ),
        isTrue,
      );
    });

    test('a Galaxy Fold laid flat keeps no fold with the switch off', () {
      const flat = DisplayFeature(
        bounds: Rect.fromLTWH(400, 0, 0, 800),
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureFlat,
      );
      const window = Size(800, 800);
      final features = foldFeaturesAcrossWindow(const [flat], const [], window);
      expect(features, const [flat]);
      expect(AppFold.fromFeatures(features, window).isNone, isTrue);
    });

    test('a published fold that already spans the window is handed back '
        'as it is', () {
      const spanning = DisplayFeature(
        bounds: Rect.fromLTWH(380, 0, 40, 800),
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureHalfOpened,
      );
      final features = [spanning];
      expect(
        identical(
          foldFeaturesAcrossWindow(features, features, const Size(800, 800)),
          features,
        ),
        isTrue,
      );
    });
  });
}
