import 'dart:math' as math;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_shell.dart';
import 'package:flutter/widgets.dart';

/// Wraps the page of one setup step so the system's own way of going back
/// follows the Back rule the shell's button follows.
///
/// While Back is offered, the Android back button and back gesture go one
/// step back instead of leaving the app, and on an iPhone a swipe in from
/// the start edge does the same. While it is not offered both are left
/// alone, so a screen opened on top of another still closes as it did.
class OnboardingStepFrame extends StatefulWidget {
  const OnboardingStepFrame({required this.child, super.key});

  final Widget child;

  @override
  State<OnboardingStepFrame> createState() => _OnboardingStepFrameState();
}

class _OnboardingStepFrameState extends State<OnboardingStepFrame> {
  /// How wide the strip at the start edge is that a swipe can begin in.
  static const double _edgeWidth = 20;

  /// How far, in logical pixels, a slow swipe has to travel to count.
  static const double _swipeDistance = 56;

  /// How fast, in logical pixels a second, a short swipe has to be.
  static const double _swipeVelocity = 300;

  double _dragged = 0;

  bool get _isIos =>
      getIt.isRegistered<PlatformCapabilities>() &&
      getIt<PlatformCapabilities>().isIos;

  @override
  Widget build(BuildContext context) {
    final onBack = OnboardingAmbientScope.onBackOf(context);
    // Towards the end of the line is the way a back swipe runs.
    final towardsEnd = Directionality.of(context) == TextDirection.ltr
        ? 1.0
        : -1.0;
    return PopScope(
      canPop: onBack == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBack?.call();
      },
      // The step stays the first child either way, so it keeps its state
      // when Back comes and goes.
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          if (onBack != null && _isIos)
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              width: math.max(
                _edgeWidth,
                Directionality.of(context) == TextDirection.ltr
                    ? MediaQuery.paddingOf(context).left
                    : MediaQuery.paddingOf(context).right,
              ),
              child: GestureDetector(
                // Taps in the strip still reach the step under it.
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: (_) => _dragged = 0,
                onHorizontalDragUpdate: (details) =>
                    _dragged += (details.primaryDelta ?? 0) * towardsEnd,
                onHorizontalDragEnd: (details) {
                  final velocity = (details.primaryVelocity ?? 0) * towardsEnd;
                  if (_dragged >= _swipeDistance ||
                      velocity >= _swipeVelocity) {
                    onBack();
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}
