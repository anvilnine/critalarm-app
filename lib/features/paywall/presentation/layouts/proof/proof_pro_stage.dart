import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/proof/proof_entrance.dart';
import 'package:flutter/material.dart';

/// How many tiles go in each row of the strip under the stage, for
/// [count] benefits. One row holds five. More than that makes two rows,
/// the longer one first.
List<int> proofStripRows(int count) {
  if (count <= 0) return const [];
  if (count <= 5) return [count];
  final first = (count / 2).ceil();
  return [first, count - first];
}

/// The Pro side of the Proof layout: one benefit on a dark stage, shown
/// as large as the room allows, and the others in a strip of tiles under
/// it. With one benefit the stage is the whole proof.
class ProofProStage extends StatelessWidget {
  const ProofProStage({
    required this.benefits,
    required this.clock,
    required this.height,
    required this.isCompact,
    super.key,
  });

  /// The first one takes the stage. The rest go in the strip.
  final List<PaywallBenefit> benefits;
  final PaywallClock clock;
  final double height;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    if (benefits.isEmpty) return SizedBox(height: height);
    final others = benefits.sublist(1);
    final gap = isCompact ? Spacing.s2 : Spacing.s3;

    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ProofEntrance(
              clock: clock,
              at: 0.1,
              seconds: 0.5,
              kind: ProofEntranceKind.pop,
              child: _Stage(benefit: benefits.first, clock: clock),
            ),
          ),
          if (others.isNotEmpty) ...[
            SizedBox(height: gap),
            _Strip(benefits: others, clock: clock, isCompact: isCompact),
          ],
        ],
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({required this.benefit, required this.clock});

  final PaywallBenefit benefit;
  final PaywallClock clock;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: Radii.xlAll,
        // The dark canvas is as dark as the panel, so the panel gets a
        // line to stand on.
        border: isDark ? Border.all(color: colors.hairline) : null,
      ),
      child: _Shadowed(
        isDark: isDark,
        child: ClipRRect(
          borderRadius: Radii.xlAll,
          child: ColoredBox(
            color: colors.panel,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;

                return Stack(
                  children: [
                    // Two soft discs, so the panel reads as a wallpaper and
                    // not as a hole.
                    Positioned(
                      left: -width * 0.45,
                      top: height * 0.28,
                      width: width * 1.2,
                      height: width * 1.2,
                      child: _Disc(
                        color: colors.onPanel.withValues(alpha: 0.07),
                      ),
                    ),
                    Positioned(
                      right: -width * 0.22,
                      top: -width * 0.24,
                      width: width * 0.6,
                      height: width * 0.6,
                      child: _Disc(
                        color: colors.onPanel.withValues(alpha: 0.04),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: ProofEntrance(
                                clock: clock,
                                at: 0.3,
                                kind: ProofEntranceKind.fromRight,
                                child: LayoutBuilder(
                                  builder: (context, box) => PaywallPreview(
                                    benefit.previewId,
                                    size: box.biggest,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: Spacing.s3),
                            ProofEntrance(
                              clock: clock,
                              at: 0.5,
                              child: Text(
                                benefit.line,
                                textAlign: TextAlign.center,
                                style: AppTypography.small(
                                  colors.onPanel,
                                  fontSize: 13,
                                ).copyWith(height: 1.3),
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Shadowed extends StatelessWidget {
  const _Shadowed({required this.isDark, required this.child});

  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: Radii.xlAll,
      boxShadow: AppShadows.shadowMd(isDark: isDark),
    ),
    child: child,
  );
}

class _Disc extends StatelessWidget {
  const _Disc({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

class _Strip extends StatelessWidget {
  const _Strip({
    required this.benefits,
    required this.clock,
    required this.isCompact,
  });

  final List<PaywallBenefit> benefits;
  final PaywallClock clock;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final rows = proofStripRows(benefits.length);
    var next = 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (r, length) in rows.indexed) ...[
          if (r > 0) const SizedBox(height: 6),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: ProofEntrance(
                      clock: clock,
                      at: 0.7 + next * 0.09,
                      seconds: 0.45,
                      kind: ProofEntranceKind.pop,
                      child: _Tile(
                        benefit: benefits[next++],
                        isCompact: isCompact,
                        // Fewer tiles are wider, so the picture can grow.
                        previewEdge: math.max(
                          30,
                          isCompact ? 30 : 46 - length * 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.benefit,
    required this.isCompact,
    required this.previewEdge,
  });

  final PaywallBenefit benefit;
  final bool isCompact;
  final double previewEdge;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(3, isCompact ? 8 : 11, 3, isCompact ? 7 : 9),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: Radii.mdAll,
        boxShadow: AppShadows.shadowSm(isDark: isDark),
      ),
      child: Column(
        children: [
          PaywallPreview(benefit.previewId, size: Size.square(previewEdge)),
          SizedBox(height: isCompact ? 5 : 8),
          Text(
            benefit.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style:
                AppTypography.small(
                  colors.ink2,
                  fontSize: 10.5,
                ).copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                  letterSpacing: -0.1,
                ),
          ),
        ],
      ),
    );
  }
}
