import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/bento/bento_board.dart';
import 'package:critalarm/features/paywall/presentation/layouts/bento/bento_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_frame.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_hero.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// A bento board: one large tile and a row of small ones, snug, on one
/// tile shape. The large tile is the stage, with the mascot reacting to
/// the benefit playing beside it. Each small tile is another benefit as
/// one still mark and a short name.
///
/// The benefits live on the board, so there is no list. When the benefit
/// changes, its small tile and the stage tile trade places, slowly enough
/// to see one go up as the other comes down. A tap on a small tile does
/// it, a swipe across the stage does it, and so does the loop.
///
/// The board is laid tile by tile: each small tile drops into place, then
/// the stage tile, and the mascot drops into that (`bentoMotion`).
///
/// The stage, the mascot, the loop and the hand are the kit's
/// (`kit/paywall_hero.dart`). A product with one benefit has no board to
/// lay out and draws the kit's one benefit composition.
class BentoPaywallLayout extends StatelessWidget {
  const BentoPaywallLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return PaywallFrame(
      // The product is named at the left of the top row.
      closeOnLeft: false,
      restAt: bentoStageLands + heroEntranceSeconds,
      builder: (context, scope) => scope.benefits.length < 2
          ? PaywallOneBenefit(
              benefit: scope.benefits.single,
              headline: _headlineFor(scope),
            )
          : _BentoComposition(scope: scope),
    );
  }
}

String _headlineFor(PaywallLayoutScope scope) => scope.isHosted
    ? LocaleKeys.paywall_bento_headline_hosted.tr()
    : LocaleKeys.paywall_bento_headline_pro.tr();

/// The product's name, the board, and the headline under it.
class _BentoComposition extends StatefulWidget {
  const _BentoComposition({required this.scope});

  final PaywallLayoutScope scope;

  @override
  State<_BentoComposition> createState() => _BentoCompositionState();
}

class _BentoCompositionState extends State<_BentoComposition> {
  HeroPlayer? _player;

  PaywallLayoutScope get scope => widget.scope;

  // A choice of the hand redraws the board: when nothing may move no
  // clock ticks to do it.
  void _onPlayer() => setState(() {});

  HeroPlayer get _playing => _player ??= HeroPlayer(
    clock: scope.clock,
    onChange: bentoTradeCue,
  )..addListener(_onPlayer);

  @override
  void dispose() {
    _player
      ?..removeListener(_onPlayer)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tones = PaywallToneColors.of(context, PaywallTone.canvas);
    final hero = HeroSizes.of(isCompact: scope.isCompact);
    final sizes = BentoSizes.of(isCompact: scope.isCompact);
    final width = scope.size.width - heroSideInset * 2;
    final benefits = scope.benefits;

    final headline = _headlineFor(scope);
    final headlineStyle = AppTypography.headline(
      tones.ink,
      fontSize: hero.headline,
    );
    // The tiles are cream in both themes, so their words are the ink that
    // reads on cream.
    final labelStyle = AppTypography.small(
      colors.ink,
      fontSize: sizes.label,
    ).copyWith(fontWeight: FontWeight.w600, height: 1.25);
    final captionStyle = AppTypography.title(
      colors.ink,
      fontSize: sizes.caption,
    ).copyWith(height: 1.25);

    final plan = bentoPlanFor(
      width: width,
      height: scope.size.height,
      small: benefits.length - 1,
      smallHeight:
          sizes.pad * 2 +
          sizes.mark +
          BentoSizes.markGap +
          paywallTextHeight(
            context,
            bentoNameFor(benefits.first),
            labelStyle,
            width,
          ).ceilToDouble(),
      words: paywallTextHeight(context, headline, headlineStyle, width),
      isCompact: scope.isCompact,
    );

    // After an intro the board is already half laid.
    final lead = bentoLeadFor(followsIntro: scope.followsIntro);
    final prelude = bentoStageLands - lead;
    final player = _playing
      ..clock = scope.clock
      ..loop = HeroLoop([
        for (final b in benefits) b.previewId,
      ], prelude: prelude);

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: heroSideInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: plan.top,
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: SizedBox(
                  height: bentoCrossRow,
                  child: Padding(
                    // Clear of the cross.
                    padding: const EdgeInsetsDirectional.only(
                      end: PaywallLayoutScope.closeCrossSize,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          LocaleKeys.paywall_bento_brand.tr(
                            namedArgs: {
                              'name': paywallProductName(scope.product),
                            },
                          ),
                          maxLines: 1,
                          style: AppTypography.title(tones.ink, fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            BentoBoardView(
              player: player,
              benefits: benefits,
              plan: plan,
              sizes: sizes,
              labelStyle: labelStyle,
              captionStyle: captionStyle,
              lead: lead,
            ),
            SizedBox(height: plan.gap),
            HeroRise(
              clock: scope.clock,
              index: 1,
              after: prelude,
              child: Semantics(
                header: true,
                child: Text(headline, style: headlineStyle),
              ),
            ),
            SizedBox(height: plan.under),
          ],
        ),
      ),
    );
  }
}
