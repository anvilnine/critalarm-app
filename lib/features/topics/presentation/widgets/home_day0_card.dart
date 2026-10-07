import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/hosted_benefit.dart';
import 'package:critalarm/features/topics/presentation/widgets/home_setup_section.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The day-0 card in Home's list: what the free plan keeps for good, what
/// Hosted adds, a way to see the plans and a way to close it.
///
/// A quiet card on the same block as the widgets card. No timer, no badge,
/// no colour of its own. It draws and reports taps. `Day0CardCubit` decides
/// when it shows and ends it.
class HomeDay0Card extends StatelessWidget {
  const HomeDay0Card({
    required this.onSeePlans,
    required this.onDismiss,
    super.key,
  });

  final VoidCallback onSeePlans;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final small = AppTypography.small(colors.ink2);
    final hostedList = hostedBenefitSentence(HostedSurface.homeDay0Card);

    return SetupBlock(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const ExcludeSemantics(
                child: FaceWidget(state: FaceState.calm, size: 32),
              ),
              const SizedBox(width: Spacing.s3),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    LocaleKeys.home_day0_title.tr(),
                    style: AppTypography.body(
                      colors.ink,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              // The way out is always there and never the loud thing.
              AppIconButton(
                glyph: GlyphType.close,
                ariaLabel: LocaleKeys.home_day0_dismiss_button.tr(),
                glyphSize: 14,
                color: colors.ink2,
                onPressed: onDismiss,
              ),
            ],
          ),
          const SizedBox(height: Spacing.s1),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(LocaleKeys.home_day0_free_line.tr(), style: small),
                const SizedBox(height: Spacing.s2),
                Text(
                  LocaleKeys.home_day0_hosted_line.tr(
                    namedArgs: {'list': hostedList},
                  ),
                  style: small,
                ),
                const SizedBox(height: Spacing.s2),
                if (HostedSurface.homeDay0Card.ownServerLine case final line?)
                  Text(line, style: small),
                const SizedBox(height: Spacing.s3),
                AppButton(
                  label: LocaleKeys.home_day0_plans_button.tr(),
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.sm,
                  isFullWidth: true,
                  onPressed: onSeePlans,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
