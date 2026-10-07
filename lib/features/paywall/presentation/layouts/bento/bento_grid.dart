import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/bento/bento_plan.dart';
import 'package:critalarm/features/paywall/presentation/layouts/bento/bento_tile.dart';
import 'package:critalarm/features/paywall/presentation/layouts/bento/bento_tile_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:flutter/material.dart';

/// The tiles of the bento layout, filling the box they are given.
///
/// `bentoPlan` places them and [clock] brings each one in, in reading
/// order. At rest every tile is flat and upright.
class BentoGrid extends StatelessWidget {
  const BentoGrid({
    required this.benefits,
    required this.clock,
    required this.isCompact,
    super.key,
  });

  /// One tile each, the first as the lead.
  final List<PaywallBenefit> benefits;
  final PaywallClock clock;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    if (benefits.isEmpty) return const SizedBox.shrink();

    final plan = bentoPlan(benefits.length, isCompact: isCompact);
    final turns = bentoEntranceOrder(plan);
    final gap = isCompact ? Spacing.s2 - Spacing.xxs : Spacing.s2;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final (i, benefit) in benefits.indexed)
              Positioned.fromRect(
                rect: bentoCellRect(plan.cells[i], plan, size, gap),
                child: PaywallClockBuilder(
                  clock: clock,
                  builder: (context, t, child) {
                    final at = bentoEntrance(turns[i], t);
                    if (identical(at, BentoEntrance.rest)) return child!;
                    return Opacity(
                      opacity: at.opacity,
                      child: Transform.translate(
                        offset: Offset(0, at.rise),
                        child: Transform.scale(scale: at.scale, child: child),
                      ),
                    );
                  },
                  child: BentoTile(
                    benefit: benefit,
                    isLead: i == 0,
                    isSolo: benefits.length == 1,
                    isCompact: isCompact,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
