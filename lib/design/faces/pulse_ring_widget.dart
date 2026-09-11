import 'dart:async';

import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:flutter/material.dart';

/// Double concentric expanding pulse ring matching index.html.
/// Used on the critical alarm screen to emphasize the urgency of the alarm.
class PulseRingWidget extends StatefulWidget {
  const PulseRingWidget({
    required this.size,
    this.color,
    this.child,
    super.key,
  });

  final double size;
  final Color? color;
  final Widget? child;

  @override
  State<PulseRingWidget> createState() => _PulseRingWidgetState();
}

class _PulseRingWidgetState extends State<PulseRingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.ring,
    );
    unawaited(_controller.repeat());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = widget.color ?? context.appColors.canvasGhostStrong;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (reduceMotion) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Center(child: widget.child),
      );
    }

    return SizedBox(
      width: widget.size * 1.6,
      height: widget.size * 1.6,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // First pulse ring
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              final curved = AppCurves.easeOut.transform(t);
              final scale = 1.0 + 0.6 * curved;
              final opacity = (1.0 - curved).clamp(0.0, 1.0);

              return Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ringColor, width: 4),
                    ),
                  ),
                ),
              );
            },
          ),
          // Second pulse ring (offset by half period)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = (_controller.value + 0.5) % 1.0;
              final curved = AppCurves.easeOut.transform(t);
              final scale = 1.0 + 0.6 * curved;
              final opacity = (1.0 - curved).clamp(0.0, 1.0);

              return Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ringColor, width: 4),
                    ),
                  ),
                ),
              );
            },
          ),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}
