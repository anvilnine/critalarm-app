import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/proof/proof_replay.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// One limit drawn as a bar on the canvas: how far the free plan goes and
/// how far the paid one does. The paid part fills when the replay on the
/// topic list lifts the cap, and rests full.
class ProofLimitBar extends StatelessWidget {
  const ProofLimitBar({
    required this.label,
    required this.freeText,
    required this.paidText,
    required this.paidName,
    required this.freeShare,
    required this.clock,
    super.key,
  });

  /// What is limited.
  final String label;

  /// The free amount and the paid amount, as written.
  final String freeText;
  final String paidText;

  /// The paid plan's name.
  final String paidName;

  /// The free amount as a share of the paid one, 0 to 1.
  final double freeShare;
  final PaywallClock clock;

  static const double _trackHeight = 12;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final labelStyle = AppTypography.small(
      colors.onCanvas,
      fontSize: 12.5,
    ).copyWith(fontWeight: FontWeight.w600, height: 1.2);
    final quiet = labelStyle.copyWith(
      fontWeight: FontWeight.w500,
      color: colors.onCanvasMuted,
    );
    final number = AppTypography.monoBold(
      colors.onCanvas,
      fontSize: 12,
    ).copyWith(height: 1.2);

    // One line height for the words and the mono numbers, so the label and
    // the amounts share a baseline.
    final strut = StrutStyle(
      fontFamily: labelStyle.fontFamily,
      fontSize: 12.5,
      height: 1.2,
      forceStrutHeight: true,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The amounts drop under the label when both will not fit a line.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: Spacing.s2,
          children: [
            Text(label, style: labelStyle, strutStyle: strut),
            Text.rich(
              strutStyle: strut,
              TextSpan(
                children: [
                  TextSpan(
                    text: LocaleKeys.paywall_proof_free_label.tr(),
                    style: quiet,
                  ),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: freeText,
                    style: number.copyWith(color: colors.onCanvasMuted),
                  ),
                  const TextSpan(text: '   '),
                  TextSpan(text: paidName, style: labelStyle),
                  const TextSpan(text: ' '),
                  TextSpan(text: paidText, style: number),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(_trackHeight / 2),
          child: SizedBox(
            height: _trackHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final freeWidth = math.max(6, width * freeShare).toDouble();

                return Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(color: colors.canvasGhostStrong),
                    ),
                    PaywallClockBuilder(
                      clock: clock,
                      builder: (context, t, _) {
                        final filled = AppCurves.easeOut.transform(
                          ProofFrame.atClock(t).barsFilled,
                        );
                        return Container(
                          width: freeWidth + (width - freeWidth) * filled,
                          decoration: BoxDecoration(
                            color: colors.highlight,
                            borderRadius: BorderRadius.circular(
                              _trackHeight / 2,
                            ),
                          ),
                        );
                      },
                    ),
                    // The free part, with a sliver of canvas after it so
                    // it stays apart from the paid part.
                    Container(
                      width: freeWidth,
                      decoration: BoxDecoration(
                        color: colors.onCanvas,
                        border: Border(
                          right: BorderSide(color: colors.canvas, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
