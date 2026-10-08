import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/bento/bento_grid.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_frame.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The bento layout: a grid of tiles of unequal sizes, one benefit each
/// with its preview playing, and the first benefit as the lead.
///
/// The grid takes all the height between the headline and the buy block,
/// whatever the number of benefits. `bentoPlan` decides the tiles.
class BentoPaywallLayout extends StatelessWidget {
  const BentoPaywallLayout({super.key});

  /// Every tile has landed well before this second, with seven or more.
  static const double _restAt = 2;

  @override
  Widget build(BuildContext context) {
    return PaywallFrame(
      restAt: _restAt,
      builder: (context, scope) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(scope: scope),
            Padding(
              padding: EdgeInsets.fromLTRB(
                Spacing.s5 - Spacing.s1,
                scope.isCompact ? 0 : Spacing.s1,
                Spacing.s5 - Spacing.s1,
                scope.isCompact ? Spacing.s2 : Spacing.s3,
              ),
              child: _Headline(scope: scope),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  Spacing.s5 - Spacing.s1,
                  0,
                  Spacing.s5 - Spacing.s1,
                  scope.isCompact ? Spacing.s2 : Spacing.s3,
                ),
                child: BentoGrid(
                  benefits: scope.benefits,
                  clock: scope.clock,
                  isCompact: scope.isCompact,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The row the close cross sits in, with the product named at its far end.
class _Header extends StatelessWidget {
  const _Header({required this.scope});

  final PaywallLayoutScope scope;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return SizedBox(
      height: PaywallLayoutScope.closeCrossSize,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          // Clear of the cross.
          start: PaywallLayoutScope.closeCrossSize + Spacing.s2,
          end: Spacing.s5 - Spacing.s1,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  LocaleKeys.paywall_bento_brand.tr(
                    namedArgs: {'name': paywallProductName(scope.product)},
                  ),
                  maxLines: 1,
                  style: AppTypography.title(colors.onCanvas, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(width: Spacing.s2),
            // Upright, as every face is.
            const ExcludeSemantics(
              child: FaceWidget(state: FaceState.happy, size: 26),
            ),
          ],
        ),
      ),
    );
  }
}

/// One line, whatever its length and the text size.
class _Headline extends StatelessWidget {
  const _Headline({required this.scope});

  final PaywallLayoutScope scope;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          scope.isHosted
              ? LocaleKeys.paywall_bento_headline_hosted.tr()
              : LocaleKeys.paywall_bento_headline_pro.tr(),
          maxLines: 1,
          style: AppTypography.headline(
            context.appColors.onCanvas,
            fontSize: scope.isCompact ? 28 : 33,
          ),
        ),
      ),
    );
  }
}
