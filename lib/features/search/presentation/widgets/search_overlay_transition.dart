import 'dart:ui';

import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:flutter/material.dart';

/// Brings search in over whatever screen is showing.
///
/// The screen behind stays put and goes out of focus, so it reads as a layer on
/// top rather than a place the user navigated to. Three things move together:
/// the blur behind, the dim over it, and the panel itself fading down into
/// place.
class SearchOverlayTransition extends StatelessWidget {
  const SearchOverlayTransition({
    required this.animation,
    required this.child,
    super.key,
  });

  /// How far out of focus the screen behind goes.
  static const double maxBlur = 18;

  /// How much the screen behind is dimmed at rest.
  static const double maxDim = 0.55;

  /// How far the panel travels down into place.
  static const double slide = 10;

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final curved = CurvedAnimation(
      parent: animation,
      curve: AppCurves.easeOut,
      reverseCurve: Curves.easeInCubic,
    );

    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) {
        final t = curved.value.clamp(0.0, 1.0);
        return Stack(
          children: <Widget>[
            // The scrim is also the way out: a tap anywhere off the panel
            // closes search. HitTestBehavior.opaque so the whole area counts,
            // not just the painted pixels.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: maxBlur * t,
                    sigmaY: maxBlur * t,
                  ),
                  child: ColoredBox(
                    color: colors.canvas.withValues(alpha: maxDim * t),
                  ),
                ),
              ),
            ),
            Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, -slide * (1 - t)),
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}
