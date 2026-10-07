import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_preview.dart';
import 'package:flutter/material.dart';

/// The paywall previews that are not a Hosted limit, each at the three
/// size classes: widgets, app icons, the weekly check, wake-up challenges,
/// alarm sounds and alarm screens.
class PaywallExtrasPreviewsSection extends StatelessWidget {
  const PaywallExtrasPreviewsSection({this.edges = _sizes, super.key});

  /// The tile edges drawn. The capture tool passes its own.
  final List<double> edges;

  static const _sizes = <double>[56, 120, 200];

  static const _previews = <(String, PaywallPreviewId)>[
    ('Home screen widgets', PaywallPreviewId.widgets),
    ('App icons', PaywallPreviewId.appIcons),
    ('Weekly delivery check', PaywallPreviewId.weeklyCheck),
    ('Wake-up challenges', PaywallPreviewId.wakeUpChallenges),
    ('Your own alarm sounds', PaywallPreviewId.customSounds),
    ('Your own alarm screens', PaywallPreviewId.customAlarmScreens),
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
          'holds its resting frame. The small size does not move.',
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
              for (final edge in edges)
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
