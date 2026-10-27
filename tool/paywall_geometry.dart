// Measures a paywall from the render tree for the responsive capture matrix
// (tool/capture_responsive_matrix.dart): the stage, the pips, the headline,
// the plans, the buy button and the close cross, with a PASS or FAIL for the
// layout rules at the size it was drawn at. A tool, not a test.
//
// Developer tool.

import 'package:critalarm/design/components/buttons.dart';
import 'package:critalarm/design/faces/face_widget.dart';
import 'package:critalarm/design/fold.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_pips.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_stage.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_frame.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fold_clearance.dart';

String _r(Rect r) =>
    '[${r.left.toStringAsFixed(1)}, ${r.top.toStringAsFixed(1)}, '
    '${r.right.toStringAsFixed(1)}, ${r.bottom.toStringAsFixed(1)}]';

Rect? _painted(Finder finder) {
  for (final element in finder.evaluate()) {
    final render = element.renderObject;
    if (render is! RenderBox) continue;
    final rect = paintedRect(render);
    if (rect != null) return rect;
  }
  return null;
}

(String, bool) _check(bool ok, String what) =>
    ('${ok ? 'PASS' : 'FAIL'} $what', !ok);

/// The paywall's geometry lines, or null when no paywall is on screen. Each
/// line comes with true when its check failed.
List<(String, bool)>? measurePaywall(
  WidgetTester tester, {
  required Size window,
  required AppSize size,
  required AppFold fold,
}) {
  final buy = _painted(find.byType(PaywallBuyBlock));
  if (buy == null) return null;
  final button = _painted(
    find.descendant(
      of: find.byType(PaywallBuyBlock),
      matching: find.byType(AppButton),
    ),
  );
  final plans = _painted(find.byType(PaywallPlanPicker));
  final stage = _painted(find.byType(HeroStage));
  final pips = _painted(find.byType(HeroPips));
  final headline = _painted(
    find.byWidgetPredicate(
      (w) => w is Semantics && (w.properties.header ?? false),
    ),
  );
  final cross = _painted(find.byType(PaywallCloseCross));
  Rect? face;
  for (final element in find.byType(FaceWidget).evaluate()) {
    final render = element.renderObject;
    if (render is! RenderBox) continue;
    final rect = paintedRect(render);
    if (rect != null && (face == null || rect.width > face.width)) face = rect;
  }

  String part(String name, Rect? rect) =>
      rect == null ? '' : ', $name ${_r(rect)}';
  String widthOf(Rect? rect) =>
      rect == null ? '' : ' w ${rect.width.toStringAsFixed(1)}';
  final lines = <(String, bool)>[
    (
      'paywall buy ${_r(buy)}${part('plans', plans)}${widthOf(plans)}'
          '${part('button', button)}${widthOf(button)}',
      false,
    ),
    (
      'paywall stage ${stage == null ? 'none' : _r(stage)}'
          '${part('face', face)}${widthOf(face)}'
          '${part('pips', pips)}${part('headline', headline)}',
      false,
    ),
  ];

  // A full screen paywall is a PaywallFrame. The sheet layout puts the
  // frame's body in its own sheet, with the cross at the sheet's top.
  final frames = find.byType(PaywallFrame).evaluate();
  final isSheet = frames.isEmpty;
  final splits = frames.any((e) => (e.widget as PaywallFrame).splits);
  final split = splits
      ? paywallSplitFor(window: window, size: size, fold: fold)
      : null;

  // The close control: the bare cross, in the window's top end corner (the
  // sheet's, for the sheet).
  if (cross == null) {
    lines.add(_check(false, 'close cross on screen'));
  } else if (isSheet) {
    lines.add(
      _check(
        cross.right >= window.width - 64,
        'close is the bare PaywallCloseCross at the sheet top end '
        '${_r(cross)}',
      ),
    );
  } else {
    final ok = cross.right >= window.width - 64 && cross.top <= 64;
    lines.add(
      _check(ok, 'close is the bare PaywallCloseCross at ${_r(cross)}'),
    );
  }

  final width = button?.width ?? buy.width;
  final plansWidth = plans?.width ?? 0;
  if (split == null && !fold.isNone) {
    lines.add((
      'one column layout on a fold: fold clearance is the walk below',
      false,
    ));
  } else if (split == null && !size.isCompact) {
    final centre = window.width / 2;
    lines
      ..add(
        _check(
          plansWidth <= paywallColumnMaxWidth && width <= paywallColumnMaxWidth,
          'one column: plans ${plansWidth.toStringAsFixed(1)} and Get Cloud '
          '${width.toStringAsFixed(1)} <= $paywallColumnMaxWidth',
        ),
      )
      ..add(
        _check(
          (buy.center.dx - centre).abs() < 0.5,
          'one column centred on ${centre.toStringAsFixed(1)}',
        ),
      );
  } else if (!fold.isNone) {
    // Fold clearance is the matrix tool's own walk. Here: the two parts
    // stand on the two sides of the band.
    final band = fold.band;
    if (stage != null) {
      final apart = fold.isBook
          ? stage.right <= band.left + 0.5 && buy.left >= band.right - 0.5
          : stage.bottom <= band.top + 0.5 && buy.top >= band.bottom - 0.5;
      lines.add(
        _check(
          apart,
          'stage and offer on the two sides of the band ${_r(band)}',
        ),
      );
    }
  } else if (size.isExpanded) {
    lines
      ..add(
        _check(
          (buy.width - paywallOfferWidth).abs() < 0.5,
          'offer column ${buy.width.toStringAsFixed(1)} == $paywallOfferWidth',
        ),
      )
      ..add(
        _check(
          width <= paywallOfferWidth,
          'Get Cloud ${width.toStringAsFixed(1)} <= $paywallOfferWidth',
        ),
      );
    if (stage != null) {
      lines.add(
        _check(
          stage.right <= buy.left,
          'stage beside the offer (stage right '
          '${stage.right.toStringAsFixed(1)} <= offer left '
          '${buy.left.toStringAsFixed(1)})',
        ),
      );
    }
  }
  if (splits && split == null && !size.isCompact && stage != null) {
    final centre = window.width / 2;
    lines.add(
      _check(
        (stage.center.dx - centre).abs() < 0.5 && stage.top >= 0,
        'stage centred above the offer, ${_r(stage)}',
      ),
    );
  }
  if (size.isCover && pips != null && headline != null) {
    lines.add(
      _check(
        pips.bottom <= headline.top,
        'cover pips bottom ${pips.bottom.toStringAsFixed(1)} <= headline '
        'top ${headline.top.toStringAsFixed(1)}',
      ),
    );
  }
  return lines;
}
