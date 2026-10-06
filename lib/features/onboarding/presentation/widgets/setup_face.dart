import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/presentation/setup_text_scale.dart';
import 'package:flutter/material.dart';

/// The face every setup step shares, sized for the system text size.
///
/// At the default text size it is [base] and nothing else changes. As the
/// text grows the face shrinks, and on a short screen it goes away with its
/// [gap], so the words and the buttons keep the room. See
/// `setupFaceSizeFor`.
class SetupFace extends StatelessWidget {
  const SetupFace({
    required this.state,
    this.gap = 0,
    this.base = 80,
    super.key,
  });

  /// The shared flight tag, so the face flies from one step to the next.
  static const heroTag = 'onboarding-face';

  final FaceState state;

  /// Room kept under the face while it is drawn.
  final double gap;

  /// The size at the default text size.
  final double base;

  /// The size of a face that waits on something. It never goes away, because
  /// the line it carries is a live region and the wait needs a sign of life.
  static double waitingSizeOf(BuildContext context, {double base = 80}) {
    final size = setupFaceSizeOf(context, base: base);
    return size == 0 ? 32 : size;
  }

  @override
  Widget build(BuildContext context) {
    final size = setupFaceSizeOf(context, base: base);
    if (size == 0) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Hero(
          tag: heroTag,
          flightShuttleBuilder: faceFlightShuttleBuilder,
          child: FaceWidget(state: state, size: size, isLive: true),
        ),
        if (gap > 0) SizedBox(height: gap),
      ],
    );
  }
}
