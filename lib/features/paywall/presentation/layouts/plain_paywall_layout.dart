import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_frame.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_preview.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The reference layout: a face, one headline and the benefits as rows.
///
/// Copy this file to start a layout. It shows the whole contract:
/// - Return a [PaywallFrame]. It draws the close cross and the buy block,
///   so there is no button, price or legal text in here.
/// - Draw from the scope: `product`, `benefits`, `size`, `isCompact`.
/// - Draw a benefit's picture with [PaywallPreview], never your own.
/// - Animate from the clock, so reduce motion gets the resting frame.
class PlainPaywallLayout extends StatelessWidget {
  const PlainPaywallLayout({super.key});

  /// The entrance is over by this second, so a still frame is complete.
  static const double _restAt = 2;

  @override
  Widget build(BuildContext context) {
    return PaywallFrame(
      restAt: _restAt,
      // A short phone gets the shorter picker, so the rows keep their room.
      buyStyle: PaywallBuyBlockStyle(
        pickerStyle: PaywallFrame.isCompactOf(context)
            ? PaywallPlanPickerStyle.segments
            : PaywallPlanPickerStyle.rows,
      ),
      builder: (context, scope) {
        final colors = context.appColors;
        final gap = scope.isCompact ? Spacing.s2 : Spacing.s4;

        // The whole composition sits in the middle of the room it has. At
        // the default text size it fits. At a large one it scrolls in its
        // own box, and the frame still does not.
        return Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.s5,
              vertical: Spacing.s2,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Upright at rest, as every face is.
                ExcludeSemantics(
                  child: FaceWidget(
                    state: FaceState.happy,
                    size: scope.isCompact ? 64 : 96,
                  ),
                ),
                SizedBox(height: gap),
                Semantics(
                  header: true,
                  child: Text(
                    scope.isHosted
                        ? LocaleKeys.paywall_kit_plain_headline_hosted.tr()
                        : LocaleKeys.paywall_kit_plain_headline_pro.tr(),
                    textAlign: TextAlign.center,
                    style: AppTypography.headline(
                      colors.onCanvas,
                      fontSize: scope.isCompact ? 26 : 32,
                    ),
                  ),
                ),
                SizedBox(height: gap),
                for (final (i, benefit) in scope.benefits.indexed)
                  PaywallClockBuilder(
                    clock: scope.clock,
                    // Each row fades and rises in, one after another.
                    builder: (context, t, child) {
                      final p = AppCurves.easeOut.transform(
                        phase(stagger(i, t, each: 0.09), 0.1, 0.5),
                      );
                      return Opacity(
                        opacity: p,
                        child: Transform.translate(
                          offset: Offset(0, 12 * (1 - p)),
                          child: child,
                        ),
                      );
                    },
                    child: _BenefitRow(
                      benefit: benefit,
                      isCompact: scope.isCompact,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.benefit, required this.isCompact});

  final PaywallBenefit benefit;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: EdgeInsets.only(top: isCompact ? Spacing.s2 : Spacing.s3),
      child: Row(
        children: [
          PaywallPreview(
            benefit.previewId,
            size: Size.square(isCompact ? 36 : 44),
          ),
          const SizedBox(width: Spacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  benefit.title,
                  style: AppTypography.small(
                    colors.onCanvas,
                    fontSize: 15,
                  ).copyWith(fontWeight: FontWeight.w700, height: 1.25),
                ),
                Text(
                  benefit.line,
                  style: AppTypography.small(
                    colors.onCanvasMuted,
                    fontSize: 13,
                  ).copyWith(height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
