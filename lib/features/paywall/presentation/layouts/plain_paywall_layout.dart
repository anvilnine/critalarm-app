import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_frame.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/plain/plain_density.dart';
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
/// - One benefit is not a list: hand it to [PaywallOneBenefit].
/// - Animate from the clock, so reduce motion gets the resting frame.
/// - Keep the buy block's side inset, so the screen has one left edge.
class PlainPaywallLayout extends StatelessWidget {
  const PlainPaywallLayout({super.key});

  /// The entrance is over by this second, so a still frame is complete.
  static const double _restAt = 2;

  /// The side inset of the buy block.
  static const double _side = 20;

  /// Past this text size the plans go side by side on every phone, so the
  /// rows above keep the height.
  static const double _stackedPlansMaxScale = 1.15;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);

    return PaywallFrame(
      restAt: _restAt,
      // A tall phone at the default text size has the room for one plan
      // per row.
      buyStyle: PaywallBuyBlockStyle(
        pickerStyle:
            PaywallFrame.isCompactOf(context) || scale > _stackedPlansMaxScale
            ? PaywallPlanPickerStyle.segments
            : PaywallPlanPickerStyle.rows,
      ),
      builder: (context, scope) {
        final headline = scope.isHosted
            ? LocaleKeys.paywall_kit_plain_headline_hosted.tr()
            : LocaleKeys.paywall_kit_plain_headline_pro.tr();
        if (scope.benefits.length == 1) {
          return PaywallOneBenefit(
            benefit: scope.benefits.single,
            headline: headline,
          );
        }
        return _Rows(scope: scope, headline: headline);
      },
    );
  }
}

/// What one density of the rows composition measures.
class _Sizes {
  const _Sizes({
    required this.face,
    required this.faceGap,
    required this.headlineGap,
    required this.thumb,
    required this.rowGap,
    required this.showsLine,
  });

  factory _Sizes.of(PlainDensity density, {required bool isCompact}) {
    final face = isCompact ? 72.0 : 96.0;
    final thumb = isCompact ? 44.0 : 48.0;
    final rowGap = isCompact ? Spacing.s3 : Spacing.s4;
    return switch (density) {
      PlainDensity.full => _Sizes(
        face: face,
        faceGap: Spacing.s4,
        headlineGap: isCompact ? 20 : Spacing.s5,
        thumb: thumb,
        rowGap: rowGap,
        showsLine: true,
      ),
      PlainDensity.titles => _Sizes(
        face: face,
        faceGap: Spacing.s4,
        headlineGap: Spacing.s4,
        thumb: thumb,
        rowGap: Spacing.s2,
        showsLine: false,
      ),
      PlainDensity.bare => const _Sizes(
        face: 56,
        faceGap: Spacing.s2,
        headlineGap: Spacing.s3,
        thumb: 0,
        rowGap: Spacing.s2,
        showsLine: false,
      ),
      PlainDensity.bareNoFace => const _Sizes(
        face: 0,
        faceGap: 0,
        headlineGap: Spacing.s3,
        thumb: 0,
        rowGap: Spacing.s2,
        showsLine: false,
      ),
    };
  }

  final double face;
  final double faceGap;
  final double headlineGap;

  /// The edge of a row's picture. Zero draws none.
  final double thumb;
  final double rowGap;
  final bool showsLine;

  static const double thumbGap = Spacing.s3;
}

class _Rows extends StatelessWidget {
  const _Rows({required this.scope, required this.headline});

  final PaywallLayoutScope scope;
  final String headline;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final width = scope.size.width - PlainPaywallLayout._side * 2;

    final headlineStyle = AppTypography.headline(
      colors.onCanvas,
      fontSize: scope.isCompact ? 26 : 32,
    );
    final titleStyle = AppTypography.small(
      colors.onCanvas,
      fontSize: 15,
    ).copyWith(fontWeight: FontWeight.w700, height: 1.25);
    final lineStyle = AppTypography.small(
      colors.onCanvasMuted,
      fontSize: 13,
    ).copyWith(height: 1.3);
    final headlineHeight = paywallTextHeight(
      context,
      headline,
      headlineStyle,
      width,
    );

    double heightOf(PlainDensity density) {
      final s = _Sizes.of(density, isCompact: scope.isCompact);
      final textWidth = s.thumb == 0
          ? width
          : width - s.thumb - _Sizes.thumbGap;
      var rows = 0.0;
      for (final benefit in scope.benefits) {
        var text = paywallTextHeight(
          context,
          benefit.title,
          titleStyle,
          textWidth,
        );
        if (s.showsLine) {
          text += paywallTextHeight(
            context,
            benefit.line,
            lineStyle,
            textWidth,
          );
        }
        rows += math.max(s.thumb, text);
      }
      return s.face +
          s.faceGap +
          headlineHeight +
          s.headlineGap +
          rows +
          s.rowGap * (scope.benefits.length - 1);
    }

    final density = plainDensityFor(
      room: scope.size.height,
      heightOf: heightOf,
    );
    final sizes = _Sizes.of(density, isCompact: scope.isCompact);
    // What is left over goes above and below the group, a little more of
    // it below.
    final spare = math.max(0, scope.size.height - heightOf(density));

    // At the default text size it fits. Where even the shortest density
    // does not, it scrolls in its own box, and the frame still does not.
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        PlainPaywallLayout._side,
        spare * 0.42,
        PlainPaywallLayout._side,
        0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sizes.face > 0) ...[
            // Upright at rest, as every face is.
            ExcludeSemantics(
              child: Center(
                child: FaceWidget(state: FaceState.happy, size: sizes.face),
              ),
            ),
            SizedBox(height: sizes.faceGap),
          ],
          Semantics(
            header: true,
            child: Text(
              headline,
              textAlign: TextAlign.center,
              style: headlineStyle,
            ),
          ),
          SizedBox(height: sizes.headlineGap),
          for (final (i, benefit) in scope.benefits.indexed) ...[
            if (i > 0) SizedBox(height: sizes.rowGap),
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
                sizes: sizes,
                titleStyle: titleStyle,
                lineStyle: lineStyle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.benefit,
    required this.sizes,
    required this.titleStyle,
    required this.lineStyle,
  });

  final PaywallBenefit benefit;
  final _Sizes sizes;
  final TextStyle titleStyle;
  final TextStyle lineStyle;

  @override
  Widget build(BuildContext context) {
    // With no picture a title is a line of a centred list, under the
    // centred headline.
    final hasThumb = sizes.thumb > 0;

    return Semantics(
      // The line is still said when there is no room to draw it.
      label: sizes.showsLine ? null : benefit.line,
      child: Row(
        children: [
          if (hasThumb) ...[
            PaywallPreview(benefit.previewId, size: Size.square(sizes.thumb)),
            const SizedBox(width: _Sizes.thumbGap),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: hasThumb
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Text(
                  benefit.title,
                  textAlign: hasThumb ? TextAlign.start : TextAlign.center,
                  style: titleStyle,
                ),
                if (sizes.showsLine) Text(benefit.line, style: lineStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
