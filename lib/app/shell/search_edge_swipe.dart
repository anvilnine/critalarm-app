import 'dart:async';

import 'package:flutter/material.dart';

/// The strip down the left edge that lets an iOS user swipe search closed.
///
/// Search is an overlay in the shell, not a route, so the system back swipe
/// has nothing to pop. This strip drives [reveal] from the finger: the panel
/// and the scrim follow it. Letting go past a third of the screen, or with a
/// fast flick, closes search through [onClose]. Anything less springs back.
///
/// Only [edgeWidth] wide and translucent, so taps and vertical scrolls in the
/// results underneath are not touched.
class SearchEdgeSwipe extends StatelessWidget {
  const SearchEdgeSwipe({
    required this.reveal,
    required this.screenWidth,
    required this.onStart,
    required this.onClose,
    required this.onSettled,
    super.key,
  });

  /// Where an iOS back swipe may begin.
  static const double edgeWidth = 20;

  /// A release past this share of the width closes search.
  static const double closeShare = 1 / 3;

  /// A flick faster than this closes search, wherever it lifts.
  static const double flingSpeed = 700;

  /// Search's open amount, 1 open and 0 gone. The drag moves it.
  final AnimationController reveal;

  final double screenWidth;

  /// The finger went down on the edge. The shell drops the keyboard.
  final VoidCallback onStart;

  /// The swipe was far or fast enough. The shell closes search from where the
  /// finger left it.
  final VoidCallback onClose;

  /// The panel sprang back, so the shell stops sliding it sideways.
  final VoidCallback onSettled;

  void _update(DragUpdateDetails details) {
    if (screenWidth <= 0) return;
    reveal.value = (reveal.value - details.delta.dx / screenWidth).clamp(
      0.0,
      1.0,
    );
  }

  void _end(DragEndDetails details) {
    final fast = details.velocity.pixelsPerSecond.dx > flingSpeed;
    final far = reveal.value < 1 - closeShare;
    if (fast || far) {
      onClose();
    } else {
      _springBack();
    }
  }

  void _springBack() {
    unawaited(reveal.forward().whenComplete(onSettled));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => onStart(),
      onHorizontalDragUpdate: _update,
      onHorizontalDragEnd: _end,
      onHorizontalDragCancel: _springBack,
    );
  }
}
