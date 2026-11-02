part of 'critical_alarm_screen.dart';

/// The room the ripple of faces has on the test alarm's acknowledged
/// screen, once the words and the pinned button have theirs.
///
/// [room] is the height from the top to the pinned button, less the gap
/// under the words. [copyHeight] is how tall the words came out, which is
/// their own height or [room] when they are taller and scroll. The ripple
/// has what is left less the [gap] between the two, and none when there is
/// no more than that.
@visibleForTesting
double ackedDemoRippleHeightFor({
  required double room,
  required double copyHeight,
  required double gap,
}) {
  final left = room - copyHeight - gap;
  return left < 0 ? 0 : left;
}

/// The words of the test alarm's acknowledged screen in a scroll view, for
/// a large text size on a small phone. A soft edge at the bottom says there
/// is more while there is. Words that fit sit still with no edge.
class _ScrollingCopy extends StatefulWidget {
  const _ScrollingCopy({required this.child, required this.fadeColor});

  final Widget child;
  final Color fadeColor;

  @override
  State<_ScrollingCopy> createState() => _ScrollingCopyState();
}

class _ScrollingCopyState extends State<_ScrollingCopy> {
  bool _hasMore = false;

  bool _onMetrics(ScrollMetricsNotification note) {
    _update(note.metrics);
    return false;
  }

  bool _onScroll(ScrollNotification note) {
    _update(note.metrics);
    return false;
  }

  void _update(ScrollMetrics metrics) {
    final hasMore = metrics.extentAfter > 0.5;
    if (hasMore != _hasMore) setState(() => _hasMore = hasMore);
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: _onMetrics,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Stack(
          children: [
            SingleChildScrollView(child: widget.child),
            if (_hasMore)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AppScrollFade(
                  edge: ScrollFadeEdge.bottom,
                  height: 32,
                  color: widget.fadeColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _AckedDemoSlot { ripple, copy, bar }

/// The ripple, the words and the pinned button, one above the other. The
/// button sits at the bottom and the words above it, at their own height or
/// the room there is. The ripple has what is above the words.
class _AckedDemoColumn extends StatelessWidget {
  const _AckedDemoColumn({
    required this.ripple,
    required this.copy,
    required this.bar,
  });

  final Widget ripple;
  final Widget copy;
  final Widget bar;

  @override
  Widget build(BuildContext context) => CustomMultiChildLayout(
    delegate: _AckedDemoLayout(),
    children: [
      LayoutId(id: _AckedDemoSlot.ripple, child: ripple),
      LayoutId(id: _AckedDemoSlot.copy, child: copy),
      LayoutId(id: _AckedDemoSlot.bar, child: bar),
    ],
  );
}

class _AckedDemoLayout extends MultiChildLayoutDelegate {
  @override
  void performLayout(Size size) {
    final barSize = layoutChild(_AckedDemoSlot.bar, BoxConstraints.loose(size));
    final room = math.max<double>(0, size.height - barSize.height - Spacing.s6);
    // A child is laid out once. The words are held to the room: at their
    // own height when that is less, and scrolling when it is more.
    final copySize = layoutChild(
      _AckedDemoSlot.copy,
      BoxConstraints(maxWidth: size.width, maxHeight: room),
    );
    final rippleHeight = ackedDemoRippleHeightFor(
      room: room,
      copyHeight: copySize.height,
      gap: Spacing.s5,
    );
    layoutChild(
      _AckedDemoSlot.ripple,
      BoxConstraints.tight(Size(size.width, rippleHeight)),
    );
    positionChild(_AckedDemoSlot.ripple, Offset.zero);
    positionChild(
      _AckedDemoSlot.copy,
      Offset((size.width - copySize.width) / 2, room - copySize.height),
    );
    positionChild(
      _AckedDemoSlot.bar,
      Offset((size.width - barSize.width) / 2, size.height - barSize.height),
    );
  }

  @override
  bool shouldRelayout(_AckedDemoLayout oldDelegate) => false;
}
