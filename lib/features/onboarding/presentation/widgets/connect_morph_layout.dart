import 'package:critalarm/features/onboarding/domain/connect/connect_morph.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// The body of the connect step while it picks a server: one column for both
/// Crit Alarm Cloud and your own server.
///
/// The children run top to bottom. The one at [heroIndex] is the picture. It
/// is [heroBase] tall and takes its share of the spare room, and the rest of
/// the spare room is left under the last child. [own] says how far the step
/// has moved from the Cloud state (0) to the own server state (1), and so how
/// the spare room is shared. See [connectMorphSplit].
///
/// The column is at least [minHeight] tall, less [bottomRoom] that it keeps
/// clear under its content for the pinned bar, and grows past that when the
/// content is taller, so the page scrolls instead of overflowing.
///
/// It lays its children out itself and never asks them for an intrinsic
/// size, which a title that fits its words to the room cannot give.
class ConnectMorphLayout extends MultiChildRenderObjectWidget {
  const ConnectMorphLayout({
    required this.own,
    required this.heroIndex,
    required this.heroBase,
    required this.minHeight,
    required this.bottomRoom,
    required super.children,
    super.key,
  });

  final double own;
  final int heroIndex;
  final double heroBase;
  final double minHeight;
  final double bottomRoom;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMorph(
    own: own,
    heroIndex: heroIndex,
    heroBase: heroBase,
    minHeight: minHeight,
    bottomRoom: bottomRoom,
  );

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderMorph)
      ..own = own
      ..heroIndex = heroIndex
      ..heroBase = heroBase
      ..minHeight = minHeight
      ..bottomRoom = bottomRoom;
  }
}

class _MorphParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderMorph extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MorphParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _MorphParentData> {
  _RenderMorph({
    required this._own,
    required this._heroIndex,
    required this._heroBase,
    required this._minHeight,
    required this._bottomRoom,
  });

  double _own;
  double get own => _own;
  set own(double value) {
    if (_own == value) return;
    _own = value;
    markNeedsLayout();
  }

  int _heroIndex;
  int get heroIndex => _heroIndex;
  set heroIndex(int value) {
    if (_heroIndex == value) return;
    _heroIndex = value;
    markNeedsLayout();
  }

  double _heroBase;
  double get heroBase => _heroBase;
  set heroBase(double value) {
    if (_heroBase == value) return;
    _heroBase = value;
    markNeedsLayout();
  }

  double _minHeight;
  double get minHeight => _minHeight;
  set minHeight(double value) {
    if (_minHeight == value) return;
    _minHeight = value;
    markNeedsLayout();
  }

  double _bottomRoom;
  double get bottomRoom => _bottomRoom;
  set bottomRoom(double value) {
    if (_bottomRoom == value) return;
    _bottomRoom = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MorphParentData) {
      child.parentData = _MorphParentData();
    }
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final fixed = BoxConstraints(minWidth: width, maxWidth: width);

    var fixedHeight = 0.0;
    var index = 0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      if (index++ == _heroIndex) continue;
      child.layout(fixed, parentUsesSize: true);
      fixedHeight += child.size.height;
    }

    final room = _minHeight - _bottomRoom;
    final split = connectMorphSplit(
      own: _own,
      leftover: room - fixedHeight - _heroBase,
      heroBase: _heroBase,
    );

    var y = 0.0;
    index = 0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      if (index++ == _heroIndex) {
        child.layout(
          BoxConstraints.tightFor(width: width, height: split.hero),
          parentUsesSize: true,
        );
      }
      (child.parentData! as _MorphParentData).offset = Offset(0, y);
      y += child.size.height;
    }
    size = constraints.constrain(Size(width, y + split.tail + _bottomRoom));
  }

  @override
  double computeMinIntrinsicHeight(double width) => 0;

  @override
  double computeMaxIntrinsicHeight(double width) => 0;

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// Two faces of one card, one over the other. The card is as tall as the
/// first child at [own] 0 and as tall as the second at [own] 1, and its
/// height moves evenly between.
///
/// Both children are kept and laid out at the card's full width. Fading them
/// is the caller's business: this only sizes and clips them.
class ConnectMorphCross extends MultiChildRenderObjectWidget {
  const ConnectMorphCross({
    required this.own,
    required super.children,
    super.key,
  }) : assert(children.length == 2, 'Two faces: Cloud and your own server.');

  final double own;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCross(own: own);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderCross).own = own;
  }
}

class _RenderCross extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MorphParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _MorphParentData> {
  _RenderCross({required this._own});

  double _own;
  double get own => _own;
  set own(double value) {
    if (_own == value) return;
    _own = value;
    markNeedsLayout();
  }

  final LayerHandle<ClipRectLayer> _clip = LayerHandle<ClipRectLayer>();

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MorphParentData) {
      child.parentData = _MorphParentData();
    }
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final tight = BoxConstraints(minWidth: width, maxWidth: width);
    final cloud = firstChild!..layout(tight, parentUsesSize: true);
    final own = childAfter(cloud)!..layout(tight, parentUsesSize: true);
    final t = _own.clamp(0.0, 1.0);
    final height =
        cloud.size.height + (own.size.height - cloud.size.height) * t;
    size = constraints.constrain(Size(width, height));
  }

  @override
  double computeMinIntrinsicHeight(double width) => 0;

  @override
  double computeMaxIntrinsicHeight(double width) => 0;

  @override
  void paint(PaintingContext context, Offset offset) {
    // Whichever face is taller overflows while the card is between the two.
    if (_own <= 0 || _own >= 1) {
      _clip.layer = null;
      defaultPaint(context, offset);
      return;
    }
    _clip.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      defaultPaint,
      oldLayer: _clip.layer,
    );
  }

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
