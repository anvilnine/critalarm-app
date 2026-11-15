import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:critalarm/core/device/fold_scope.dart';
import 'package:critalarm/design/fold.dart';
import 'package:flutter/widgets.dart';
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

// Said outright: the package default is on in a debug build only.
// ignore: avoid_redundant_argument_values
const _divisionOn = FoldDivisionConfig(enabled: true);

/// What the package publishes on an Android foldable that is rendered as an
/// iPhone Duo: the features it builds from the emulated window [state].
List<DisplayFeature> _publishedAsDuo(
  EmulatedDeviceState state,
  HingeStatus status,
) {
  final emulated = emulateDeviceData(
    data: FoldableData(
      capabilities: FoldableData.unsupported.capabilities,
      status: status,
      angleDegrees: null,
      regions: const [],
      displayFeatures: const [],
    ),
    state: state,
    config: _divisionOn,
  );
  return DisplayFeatureBridge.build(
    mode: appFoldBridgeMode,
    regions: emulated.regions,
    status: emulated.status,
  );
}

/// What reaches `MediaQuery` there: the package swaps the engine's list for
/// the one it publishes, so both lists are the same.
List<DisplayFeature> _asDuo(EmulatedDeviceState state, HingeStatus status) {
  final published = _publishedAsDuo(state, status);
  return foldFeaturesAcrossWindow(published, published, state.windowSize);
}

void main() {
  group('an Android foldable rendered as an iPhone Duo', () {
    const duo = EmulatedDevice.iphoneDuo;

    test('partly folded with the fold upright reads as book', () {
      final state = duo.innerLandscape;
      final features = _asDuo(state, HingeStatus.partiallyOpen);
      final fold = AppFold.fromFeatures(features, state.windowSize);
      expect(fold.isBook, isTrue);
      expect(fold.bounds, const Rect.fromLTWH(455.5, 0, 40, 669));
    });

    test('partly folded with the fold level reads as tabletop', () {
      final state = duo.innerPortrait;
      final features = _asDuo(state, HingeStatus.partiallyOpen);
      final fold = AppFold.fromFeatures(features, state.windowSize);
      expect(fold.isTabletop, isTrue);
      expect(fold.bounds, const Rect.fromLTWH(0, 455.5, 669, 40));
    });

    test('the emulated fold already spans the window, so the list is '
        'handed back as it is', () {
      final state = duo.innerLandscape;
      final published = _publishedAsDuo(state, HingeStatus.partiallyOpen);
      expect(published, hasLength(1));
      expect(
        identical(
          foldFeaturesAcrossWindow(published, published, state.windowSize),
          published,
        ),
        isTrue,
      );
    });

    test('laid flat has no fold', () {
      final state = duo.innerLandscape;
      final features = _asDuo(state, HingeStatus.fullyOpen);
      expect(AppFold.fromFeatures(features, state.windowSize).isNone, isTrue);
    });

    test('the outer display has no fold, and its system strip is no '
        'fold either', () {
      final state = duo.outerPortrait;
      final features = _asDuo(state, HingeStatus.partiallyOpen);
      expect(
        features.where((f) => f.type == DisplayFeatureType.fold),
        isEmpty,
      );
      expect(AppFold.fromFeatures(features, state.windowSize).isNone, isTrue);
    });
  });

  group('layoutIsIphone', () {
    test('an iPhone follows the iPhone rules', () {
      expect(
        layoutIsIphone(isIphone: true, isRenderedAsIphone: false),
        isTrue,
      );
    });

    test('a device rendered as an iPhone Duo follows them too', () {
      expect(
        layoutIsIphone(isIphone: false, isRenderedAsIphone: true),
        isTrue,
      );
    });

    test('any other device does not', () {
      expect(
        layoutIsIphone(isIphone: false, isRenderedAsIphone: false),
        isFalse,
      );
    });
  });

  group('appWindowMediaFor', () {
    // A Galaxy Z Fold open and upright: its own bars, and a fold the engine
    // reports.
    const view = MediaQueryData(
      size: Size(768, 884),
      devicePixelRatio: 2.5,
      padding: EdgeInsets.only(top: 32, bottom: 20),
      viewPadding: EdgeInsets.only(top: 32, bottom: 20),
      systemGestureInsets: EdgeInsets.only(left: 30, right: 30),
      textScaler: TextScaler.linear(1.3),
      displayFeatures: [
        DisplayFeature(
          bounds: Rect.fromLTWH(384, 0, 0, 884),
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureHalfOpened,
        ),
      ],
    );

    test('with no emulation the view is handed back as it is', () {
      expect(identical(appWindowMediaFor(view, null), view), isTrue);
    });

    test('a matched window has the size, the safe area and the scale of '
        'the emulated one', () {
      final state = EmulatedDevice.iphoneDuo.innerLandscape;
      final window = appWindowMediaFor(
        view,
        DeviceEmulation(
          device: EmulatedDevice.iphoneDuo,
          kind: EmulatedWindowKind.innerLandscape,
          matchesWindowSize: true,
          windowSize: state.windowSize,
          safeArea: state.safeArea,
          scale: 0.8,
        ),
      );
      expect(window.size, const Size(951, 669));
      expect(window.padding, const EdgeInsets.only(right: 84));
      expect(window.viewPadding, const EdgeInsets.only(right: 84));
      expect(window.devicePixelRatio, 2);
      expect(window.viewInsets, EdgeInsets.zero);
      expect(window.systemGestureInsets, EdgeInsets.zero);
      expect(window.displayFeatures, isEmpty);
      expect(window.textScaler, const TextScaler.linear(1.3));
    });

    test('a window that keeps its size takes the safe area only', () {
      const safeArea = EdgeInsets.only(top: 32, right: 84, bottom: 20);
      final window = appWindowMediaFor(
        view,
        const DeviceEmulation(
          device: EmulatedDevice.iphoneDuo,
          kind: EmulatedWindowKind.innerLandscape,
          matchesWindowSize: false,
          windowSize: Size(768, 884),
          safeArea: safeArea,
        ),
      );
      expect(window.size, const Size(768, 884));
      expect(window.devicePixelRatio, 2.5);
      expect(window.viewPadding, safeArea);
      expect(window.padding, safeArea);
      expect(window.displayFeatures, view.displayFeatures);
    });

    test('the keyboard covers the bottom of a safe area that keeps its '
        'size', () {
      final window = appWindowMediaFor(
        view.copyWith(viewInsets: const EdgeInsets.only(bottom: 300)),
        const DeviceEmulation(
          device: EmulatedDevice.iphoneDuo,
          kind: EmulatedWindowKind.innerLandscape,
          matchesWindowSize: false,
          windowSize: Size(768, 884),
          safeArea: EdgeInsets.only(top: 32, right: 84, bottom: 20),
        ),
      );
      expect(window.padding, const EdgeInsets.only(top: 32, right: 84));
      expect(window.viewPadding.bottom, 20);
    });
  });

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
