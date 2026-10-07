import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_preview.dart';
import 'package:flutter/material.dart';

/// The paywall previews for widgets, app icons and the weekly check, each
/// at the three sizes a layout is most likely to ask for.
class PaywallExtrasPreviewsSection extends StatelessWidget {
  const PaywallExtrasPreviewsSection({super.key});

  static const _sizes = <double>[56, 120, 240];

  static const _previews = <(String, PaywallPreviewId)>[
    ('Home screen widgets', PaywallPreviewId.widgets),
    ('App icons', PaywallPreviewId.appIcons),
    ('Weekly delivery check', PaywallPreviewId.weeklyCheck),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Paywall previews: extras',
          style: AppTypography.headline(colors.onCanvas),
        ),
        const SizedBox(height: Spacing.s2),
        Text(
          'Each one loops on its own clock here. With reduce motion on it '
          'holds its resting frame.',
          style: AppTypography.body(colors.onCanvasMuted),
        ),
        for (final (name, id) in _previews) ...[
          const SizedBox(height: Spacing.s5),
          Text(name, style: AppTypography.title(colors.onCanvas)),
          const SizedBox(height: Spacing.s3),
          Wrap(
            spacing: Spacing.s4,
            runSpacing: Spacing.s4,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              for (final edge in _sizes)
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
