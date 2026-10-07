import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_preview.dart';
import 'package:flutter/material.dart';

/// The three paywall previews of a Hosted limit lifting (topics, pushes,
/// history), each at the sizes a layout may give it.
class PaywallLimitsPreviewsSection extends StatelessWidget {
  const PaywallLimitsPreviewsSection({super.key});

  /// Edge lengths shown, smallest first.
  static const sizes = <double>[56, 120, 240];

  static const _previews = <(PaywallPreviewId, String)>[
    (PaywallPreviewId.topics, 'Critical topics'),
    (PaywallPreviewId.pushes, 'Pushes a day'),
    (PaywallPreviewId.history, 'History kept'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Paywall previews: limits',
          style: AppTypography.headline(colors.onCanvas),
        ),
        const SizedBox(height: 6),
        Text(
          'Each one plays a Hosted limit lifting, in turn, and rests on its '
          'finished picture. Small boxes get the one part that says it.',
          style: AppTypography.body(colors.onCanvasMuted),
        ),
        for (final (id, name) in _previews) ...[
          const SizedBox(height: Spacing.s5),
          Text(name, style: AppTypography.title(colors.onCanvas)),
          const SizedBox(height: Spacing.s3),
          Wrap(
            spacing: Spacing.s4,
            runSpacing: Spacing.s4,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              for (final edge in sizes)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PaywallPreview(id, size: Size.square(edge)),
                    const SizedBox(height: Spacing.s1),
                    Text(
                      '${edge.round()}',
                      style: AppTypography.mono(
                        colors.onCanvasMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}
