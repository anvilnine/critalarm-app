import 'dart:async';

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/topics/domain/setup_finish_glow.dart';
import 'package:flutter/material.dart';

/// A soft ring and tint over [child], shown once and then gone. Home puts
/// it on the topic setup made, so the eye lands on it.
///
/// It is drawn over the row and never under a finger: it takes no room,
/// moves nothing and lets every tap through. It starts the first time
/// [isPlaying] is true and then runs to its end. Under reduced motion it is
/// a still highlight that fades.
class SetupGlow extends StatefulWidget {
  const SetupGlow({
    required this.isPlaying,
    required this.child,
    super.key,
  });

  final bool isPlaying;
  final Widget child;

  @override
  State<SetupGlow> createState() => _SetupGlowState();
}

class _SetupGlowState extends State<SetupGlow>
    with SingleTickerProviderStateMixin {
  // Under reduced motion a controller runs its time short by default. The
  // still highlight has to stay its full two seconds, so this one keeps time.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );
  bool _hasStarted = false;
  bool _isStill = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startIfAsked();
  }

  @override
  void didUpdateWidget(SetupGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _startIfAsked();
  }

  void _startIfAsked() {
    if (_hasStarted || !widget.isPlaying) return;
    _hasStarted = true;
    _isStill = context.reduceMotion;
    _clock.duration = setupGlowTakes(isStill: _isStill);
    unawaited(_clock.forward());
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _clock,
              builder: (context, _) {
                if (!_hasStarted || _clock.isCompleted) {
                  return const SizedBox.shrink();
                }
                final strength = setupGlowStrengthAt(
                  setupGlowTakes(isStill: _isStill) * _clock.value,
                  isStill: _isStill,
                );
                return Opacity(
                  opacity: AppCurves.easeOut.transform(strength),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: _tint),
                      borderRadius: Radii.mdAll,
                      border: Border.all(
                        color: colors.primary,
                        width: _ringWidth,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// How much of the primary colour washes the row inside the ring.
  static const double _tint = 0.08;
  static const double _ringWidth = 2;
}
