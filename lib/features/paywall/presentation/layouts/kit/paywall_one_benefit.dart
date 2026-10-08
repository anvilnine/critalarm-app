import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_measure.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:flutter/material.dart';

/// The face and the card of [PaywallOneBenefit] at their chosen sizes.
const double oneBenefitFace = 96;
const double oneBenefitCard = 200;

/// The face when the text is large and the room is short.
const double oneBenefitSmallFace = 64;

/// The card never gets shorter than this. Under it the composition scrolls
/// in its own box.
const double oneBenefitMinCard = 120;

/// The sizes of the face and the card when [left] points are left for the
/// two of them, after the words and the gaps.
///
/// Both have one chosen size and keep it whenever there is room. Short of
/// room, the face gets smaller, then goes, and only then does the card
/// give up height. Neither is ever stretched to fill.
({double face, double card}) oneBenefitSizes(double left) {
  if (left >= oneBenefitFace + oneBenefitCard) {
    return (face: oneBenefitFace, card: oneBenefitCard);
  }
  if (left >= oneBenefitSmallFace + oneBenefitCard) {
    return (face: oneBenefitSmallFace, card: oneBenefitCard);
  }
  return (face: 0, card: left.clamp(oneBenefitMinCard, oneBenefitCard));
}

/// The composition for a product with one benefit: a face, the headline,
/// one card holding the benefit's preview, and its sentence under the card.
///
/// A layout draws this in place of its own composition when
/// `scope.benefits.length == 1`, so a product with one thing to show reads
/// as one thing and never as a list of one. It goes inside a
/// `PaywallFrame` builder and reads the scope above it.
class PaywallOneBenefit extends StatelessWidget {
  const PaywallOneBenefit({
    required this.benefit,
    required this.headline,
    this.tone = PaywallTone.canvas,
    super.key,
  });

  final PaywallBenefit benefit;
  final String headline;

  /// What the composition sits on.
  final PaywallTone tone;

  /// The same side inset the buy block keeps.
  static const double _side = 20;

  @override
  Widget build(BuildContext context) {
    final scope = PaywallLayoutScope.of(context);
    final colors = PaywallToneColors.of(context, tone);
    final width = scope.size.width - _side * 2;
    // One gap between each of the four parts.
    final gap = scope.isCompact ? Spacing.s4 : 20.0;

    final headlineStyle = AppTypography.headline(
      colors.ink,
      fontSize: scope.isCompact ? 28 : 32,
    );
    final lineStyle = AppTypography.lead(colors.note).copyWith(height: 1.35);
    final words =
        paywallTextHeight(context, headline, headlineStyle, width) +
        paywallTextHeight(context, benefit.line, lineStyle, width);

    final gaps = gap * 3;
    final sizes = oneBenefitSizes(scope.size.height - words - gaps);
    final hasFace = sizes.face > 0;
    final height = sizes.face + sizes.card + words + (hasFace ? gaps : gap * 2);
    // What is left over goes above and below, a little more of it below,
    // so the group sits just over the middle of its room.
    final spare = math.max(0, scope.size.height - height);

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(_side, spare * 0.42, _side, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasFace) ...[
            // Upright at rest, as every face is.
            ExcludeSemantics(
              child: FaceWidget(state: FaceState.happy, size: sizes.face),
            ),
            SizedBox(height: gap),
          ],
          Semantics(
            header: true,
            child: Text(
              headline,
              textAlign: TextAlign.center,
              style: headlineStyle,
            ),
          ),
          SizedBox(height: gap),
          PaywallClockBuilder(
            clock: scope.clock,
            // The card rises in once. Its preview plays on its own.
            builder: (context, t, child) {
              final p = AppCurves.easeOut.transform(phase(t, 0.1, 0.6));
              return Opacity(
                opacity: p,
                child: Transform.translate(
                  offset: Offset(0, 16 * (1 - p)),
                  child: child,
                ),
              );
            },
            // The preview draws its own surface, so it is the card.
            child: PaywallPreview(
              benefit.previewId,
              size: Size(width, sizes.card),
            ),
          ),
          SizedBox(height: gap),
          Semantics(
            label: benefit.title,
            child: Text(
              benefit.line,
              textAlign: TextAlign.center,
              style: lineStyle,
            ),
          ),
        ],
      ),
    );
  }
}
