import 'dart:async';

import 'package:critalarm/design/motion.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:flutter/material.dart';

/// Scope holding the current pulse value (0.0 to 1.0) for descendant
/// skeleton bones.
class _SkeletonScope extends InheritedWidget {
  const _SkeletonScope({
    required this.pulseValue,
    required super.child,
  });

  final double pulseValue;

  static double of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_SkeletonScope>()
            ?.pulseValue ??
        0.0;
  }

  @override
  bool updateShouldNotify(_SkeletonScope oldWidget) =>
      pulseValue != oldWidget.pulseValue;
}

/// A wrapper that drives a subtle breathing pulse across nested
/// [AppSkeletonBone] widgets.
///
/// Respects `context.reduceMotion` — if animations are reduced, it holds a
/// static baseline opacity without running the animation ticker.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.ring,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: AppCurves.easeOut,
  );

  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = context.reduceMotion;
    _syncAnimation();
  }

  void _syncAnimation() {
    if (_reduceMotion) {
      _controller
        ..stop()
        ..value = 0.0;
    } else {
      if (!_controller.isAnimating) {
        unawaited(_controller.repeat(reverse: true));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion) {
      return _SkeletonScope(
        pulseValue: 0,
        child: widget.child,
      );
    }
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => _SkeletonScope(
        pulseValue: _curve.value,
        child: child!,
      ),
      child: widget.child,
    );
  }
}

/// A single skeleton placeholder block.
///
/// Automatically shades using `context.appColors.ink` with opacities that look
/// natural and distinct in both Light and Dark themes.
class AppSkeletonBone extends StatelessWidget {
  const AppSkeletonBone({
    this.width,
    this.height,
    this.borderRadius,
    this.color,
    super.key,
  });

  const AppSkeletonBone.text({
    this.width,
    this.height = 13.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
    this.color,
    super.key,
  });

  final double? width;
  final double? height;
  final BorderRadiusGeometry? borderRadius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final pulse = _SkeletonScope.of(context);

    // Warm, tactile opacity tuned for contrast on both cream/white and dark ash surfaces.
    // In light mode: ink is #1A140F (0.075 -> 0.15)
    // In dark mode: ink is #F7F1EA (0.08 -> 0.16)
    const baseAlpha = 0.075;
    const peakAlpha = 0.15;
    final alpha = baseAlpha + (peakAlpha - baseAlpha) * pulse;

    final effectiveColor = color ?? colors.ink.withValues(alpha: alpha);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius:
            borderRadius ?? const BorderRadius.all(Radius.circular(4)),
      ),
    );
  }
}

/// Skeleton representation of `AppMessageCard` matching its exact dimensions,
/// padding, and shape.
class AppMessageCardSkeleton extends StatelessWidget {
  const AppMessageCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AppSkeleton(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.cream,
          borderRadius: Radii.mdAll,
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppSkeletonBone(
                  width: 130,
                  height: 15,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                AppSkeletonBone(
                  width: 50,
                  height: 12,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              ],
            ),
            SizedBox(height: 8),
            AppSkeletonBone(
              width: double.infinity,
              height: 13,
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
            SizedBox(height: 5),
            FractionallySizedBox(
              widthFactor: 0.65,
              child: AppSkeletonBone(
                height: 13,
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ),
            SizedBox(height: 8),
            AppSkeletonBone(
              width: 75,
              height: 11,
              borderRadius: BorderRadius.all(Radius.circular(3)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton representation of a token row (`_TokenRow` / `AppListRow`).
class AppTokenRowSkeleton extends StatelessWidget {
  const AppTokenRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: Radii.mdAll,
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppSkeletonBone(
                  width: 110,
                  height: 15,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                SizedBox(height: 6),
                AppSkeletonBone(
                  width: 140,
                  height: 12,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          AppSkeletonBone(
            width: 14,
            height: 14,
            borderRadius: BorderRadius.all(Radius.circular(3)),
          ),
        ],
      ),
    );
  }
}

/// Skeleton placeholder for buttons (e.g. ghost buttons).
class AppButtonSkeleton extends StatelessWidget {
  const AppButtonSkeleton({
    this.height = 36.0,
    this.isFullWidth = true,
    super.key,
  });

  final double height;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    return AppSkeletonBone(
      width: isFullWidth ? double.infinity : 120,
      height: height,
      borderRadius: Radii.fullAll,
    );
  }
}

/// Skeleton representation of the Tokens section when loading.
class AppTokensSectionSkeleton extends StatelessWidget {
  const AppTokensSectionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppSkeleton(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTokenRowSkeleton(),
          SizedBox(height: 8),
          AppTokenRowSkeleton(),
          SizedBox(height: 8),
          AppButtonSkeleton(),
        ],
      ),
    );
  }
}
