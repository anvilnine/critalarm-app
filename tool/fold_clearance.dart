// Used by tool/capture_responsive_matrix.dart. Not part of the app.
//
// Walks what is on screen at scroll offset 0 and lists every text, button
// and face whose box overlaps the fold band (lib/design/fold.dart). The
// decision itself is foldOverlaps / boxCrossesFold in lib/design/fold.dart,
// which has its own unit test. This file only collects the boxes.

import 'package:critalarm/design/components/buttons.dart';
import 'package:critalarm/design/components/floating_tab_bar.dart';
import 'package:critalarm/design/components/nav_rail.dart';
import 'package:critalarm/design/faces/face_widget.dart';
import 'package:critalarm/design/faces/ghost_field.dart';
import 'package:critalarm/design/faces/idle_face.dart';
import 'package:critalarm/design/faces/refresh_face.dart';
import 'package:critalarm/design/faces/ringing/ringing_face_widget.dart';
import 'package:critalarm/design/fold.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// One box on screen that overlaps the fold band.
typedef FoldOverlap = ({
  /// `Text`, `AppButton` or the face widget's type.
  String widget,

  /// The text, for a `Text`. Empty otherwise.
  String label,

  /// The box on screen, in logical pixels.
  Rect rect,

  /// True when the box is part of the shell's tab bar or rail.
  bool isChrome,
});

/// Where [box] is drawn on screen, after every transform above it (a
/// FittedBox that scales the tab bar, a slide), or null when it is not
/// painted: an offstage route, an unselected tab, a zero opacity.
Rect? paintedRect(RenderBox box) {
  if (!box.attached || !box.hasSize || box.size.isEmpty) return null;
  RenderObject child = box;
  var parent = child.parent;
  while (parent != null) {
    if (!parent.paintsChild(child)) return null;
    child = parent;
    parent = child.parent;
  }
  final transform = box.getTransformTo(null);
  return MatrixUtils.transformRect(transform, Offset.zero & box.size);
}

/// Every text, button and face in [tester]'s tree that overlaps [band],
/// clipped to [window]. Background ghost faces are left out: they are
/// decoration, not content.
List<FoldOverlap> findFoldOverlaps(
  WidgetTester tester,
  Rect band,
  Rect window,
) {
  final found = <FoldOverlap>[];
  final seen = <Rect>{};

  bool hasAncestor<T extends Widget>(Element e) =>
      e.findAncestorWidgetOfExactType<T>() != null;

  void check(Finder finder, String Function(Element e) name) {
    for (final element in finder.evaluate()) {
      if (hasAncestor<GhostWatermarkFace>(element)) continue;
      final render = element.renderObject;
      if (render is! RenderBox) continue;
      final rect = paintedRect(render)?.intersect(window);
      if (rect == null || rect.isEmpty) continue;
      if (!boxCrossesFold(rect, band)) continue;
      final widget = element.widget;
      final label = widget is Text
          ? (widget.data ?? widget.textSpan?.toPlainText() ?? '')
          : '';
      // A face inside a face (the refresh face draws the face widget) is
      // the same box: report it once.
      if (widget is! Text && !seen.add(rect)) continue;
      found.add((
        widget: name(element),
        label: label.length > 40 ? '${label.substring(0, 40)}...' : label,
        rect: rect,
        isChrome:
            hasAncestor<AppFloatingTabBar>(element) ||
            hasAncestor<AppNavRail>(element),
      ));
    }
  }

  check(find.byType(Text), (_) => 'Text');
  check(find.byType(AppButton), (_) => 'AppButton');
  for (final type in const [
    RefreshFace,
    IdleFace,
    RingingFaceWidget,
    FaceWidget,
  ]) {
    check(find.byType(type), (e) => e.widget.runtimeType.toString());
  }
  return found;
}
