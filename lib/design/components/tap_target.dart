import 'package:flutter/widgets.dart';

/// The least a finger has to hit, in logical pixels, on either side.
const double kMinTapTarget = 48;

/// Gives a small control a [kMinTapTarget] square to be hit in, without
/// changing the control.
///
/// The child keeps its own size and sits in the middle of the box. The room
/// around it is empty and takes a tap when the gesture detector outside this
/// widget is [HitTestBehavior.opaque]. A child that is already 48 on a side
/// is not made bigger on that side.
///
/// Give [onTap] when the control inside draws its own ink and takes its own
/// taps, as an ink well does: the tap that lands in the empty room then
/// does what a tap on the control does. The control says what it is, so this
/// adds nothing for a screen reader.
///
/// The box takes up layout room, so where it is added to a tight row or bar
/// the padding around it has to give up the same amount to keep every pixel
/// where it was.
class AppTapTarget extends StatelessWidget {
  const AppTapTarget({
    required this.child,
    this.onTap,
    this.minWidth = kMinTapTarget,
    this.minHeight = kMinTapTarget,
    super.key,
  });

  final Widget child;

  /// What a tap in the room around the control does. Null leaves the taps to
  /// a gesture detector the caller has put outside this widget.
  final VoidCallback? onTap;
  final double minWidth;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final box = ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth, minHeight: minHeight),
      child: Align(
        widthFactor: 1,
        heightFactor: 1,
        child: child,
      ),
    );
    if (onTap == null) return box;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: onTap,
      child: box,
    );
  }
}
