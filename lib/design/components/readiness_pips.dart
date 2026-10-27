import 'dart:math' as math;

import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/design_system/motion.dart';
import 'package:flutter/material.dart';

/// What one pip says about one check.
enum AppPipTone {
  /// The check passes.
  fine,

  /// The check passes but something nearby needs a look.
  look,

  /// The check fails and an alarm may not ring.
  broken,

  /// Not answered yet, or a setup step still to do.
  open;

  /// The pip's fill on the dark card.
  Color color(AppColors colors) => switch (this) {
    AppPipTone.fine => colors.yellow,
    AppPipTone.look => colors.high,
    AppPipTone.broken => colors.crit,
    AppPipTone.open => colors.onPanel.withValues(alpha: 0.18),
  };
}

/// The tones for a row of pips, fine first and open last.
///
/// The pips are decoration: the numeral beside them carries the count, so a
/// reader who cannot tell the colours apart loses nothing.
List<AppPipTone> pipTones({
  required int fine,
  int look = 0,
  int broken = 0,
  int open = 0,
}) => [
  for (var i = 0; i < fine; i++) AppPipTone.fine,
  for (var i = 0; i < look; i++) AppPipTone.look,
  for (var i = 0; i < broken; i++) AppPipTone.broken,
  for (var i = 0; i < open; i++) AppPipTone.open,
];

/// The widest the gap between pips gets.
const double kPipGap = 5;

/// The narrowest a pip is allowed to get while the gap can still shrink.
const double kPipMinWidth = 10;

/// How wide each pip is and how wide the gaps are, for [count] pips in a row
/// [width] points wide.
///
/// The gap is [kPipGap] while the pips stay at least [kPipMinWidth] wide, and
/// shrinks before the pips do. Nine pips fit a 140 point card with a 4 point
/// gap.
({double pip, double gap}) pipLayout(double width, int count) {
  if (count <= 0) return (pip: 0, gap: 0);
  if (count == 1) return (pip: width, gap: 0);
  final gaps = count - 1;
  final roomForGaps = width - kPipMinWidth * count;
  final gap = (roomForGaps / gaps).clamp(1.0, kPipGap);
  return (pip: math.max(0, (width - gap * gaps) / count), gap: gap);
}

/// One to nine pips in a row, one per check.
///
/// Draw it inside the status card or on any dark panel. It is a picture only
/// and hidden from a screen reader.
class AppReadinessPips extends StatelessWidget {
  const AppReadinessPips({required this.tones, super.key});

  /// One tone per pip, left to right. Nothing is drawn for an empty list.
  final List<AppPipTone> tones;

  /// Pip height.
  static const double height = 7;

  @override
  Widget build(BuildContext context) {
    if (tones.isEmpty) return const SizedBox.shrink();
    final colors = context.appColors;
    final duration = context.motion(AppDurations.slow);

    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = pipLayout(constraints.maxWidth, tones.length);
          return Row(
            children: [
              for (var i = 0; i < tones.length; i++) ...[
                if (i > 0) SizedBox(width: layout.gap),
                // A pip fades to its new colour when its check changes.
                AnimatedContainer(
                  duration: duration,
                  curve: AppCurves.easeOut,
                  width: layout.pip,
                  height: height,
                  decoration: BoxDecoration(
                    color: tones[i].color(colors),
                    borderRadius: BorderRadius.circular(height / 2 + 0.5),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
