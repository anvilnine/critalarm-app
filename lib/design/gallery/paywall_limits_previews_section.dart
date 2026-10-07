import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_preview.dart';
import 'package:flutter/material.dart';

/// The six paywall previews side by side at their small size, then the
/// three of a Hosted limit lifting (topics, pushes, history) at each size
/// class.
class PaywallLimitsPreviewsSection extends StatelessWidget {
  const PaywallLimitsPreviewsSection({this.edges = sizes, super.key});

  /// The tile edges drawn. The capture tool passes its own.
  final List<double> edges;

  /// Edge lengths shown, smallest first: the three size classes.
  static const sizes = <double>[56, 120, 200];

  /// Every preview built, in the order a paywall lists them.
  static const _set = <PaywallPreviewId>[
    PaywallPreviewId.topics,
    PaywallPreviewId.pushes,
    PaywallPreviewId.history,
    PaywallPreviewId.widgets,
    PaywallPreviewId.appIcons,
    PaywallPreviewId.weeklyCheck,
  ];

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
          'Paywall previews: the set',
          style: AppTypography.headline(colors.onCanvas),
        ),
        const SizedBox(height: 6),
        Text(
          'Small, every preview is one mark on one tile, and nothing on it '
          'moves. On the canvas and on a sheet.',
          style: AppTypography.body(colors.onCanvasMuted),
        ),
        const SizedBox(height: Spacing.s3),
        _SetRow(ids: _set, edge: edges.first),
        const SizedBox(height: Spacing.s3),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: Radii.mdAll,
          ),
          child: Padding(
            padding: const EdgeInsets.all(Spacing.s3),
            child: _SetRow(ids: _set, edge: edges.first),
          ),
        ),
        const SizedBox(height: Spacing.s6),
        Text(
          'Paywall previews: limits',
          style: AppTypography.headline(colors.onCanvas),
        ),
        const SizedBox(height: 6),
        Text(
          'Each one plays a Hosted limit lifting, in turn, and rests on its '
          'finished picture. A preview has three sizes, 56, 120 and 200, and '
          'never grows past the one it was given.',
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

/// The whole set in one row, at one tile size.
class _SetRow extends StatelessWidget {
  const _SetRow({required this.ids, required this.edge});

  final List<PaywallPreviewId> ids;
  final double edge;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: Spacing.s3,
    runSpacing: Spacing.s3,
    children: [
      for (final id in ids) PaywallPreview(id, size: Size.square(edge)),
    ],
  );
}
