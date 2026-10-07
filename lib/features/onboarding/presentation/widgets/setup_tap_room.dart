import 'package:critalarm/features/onboarding/domain/setup_layout_rules.dart';
import 'package:flutter/widgets.dart';

/// Gives a small control a full-size tap area without changing how it looks.
///
/// The control keeps its own size and sits at the bottom of the room, so the
/// room that is added is above it and whatever is under it stays where it
/// was. A tap in that room does what a tap on the control does. Once the
/// control is tall enough on its own, at a large text size, this adds
/// nothing. See `setupTapRoomFor`.
class SetupTapRoom extends StatelessWidget {
  const SetupTapRoom({required this.onTap, required this.child, super.key});

  /// What the control does when tapped. Null while the control is off.
  final VoidCallback? onTap;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // The control says what it is. This only widens where it is hit.
      excludeFromSemantics: true,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: setupMinTapHeight),
        child: Align(
          alignment: Alignment.bottomCenter,
          widthFactor: 1,
          heightFactor: 1,
          child: child,
        ),
      ),
    );
  }
}
