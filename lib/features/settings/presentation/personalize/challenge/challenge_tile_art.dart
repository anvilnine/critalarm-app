import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The height of the picture on a tile.
const double kChallengeArtHeight = 104;

/// The picture on a tile of the Wake-up challenge shelf, drawn in code and
/// still. It shows the first frame of the task, as the challenge itself
/// would: the topic text with the caret held visible, a two-line title,
/// `7 + 5 = ?`, a code under hatching, Crit upright.
///
/// A null [kind] is the "No challenge" tile: a check while it is the one in
/// use, a dash while it is not.
///
/// It is a picture. It is not scaled with the text size, takes no touch and
/// says nothing to a screen reader: the tile around it speaks.
class ChallengeTileArt extends StatelessWidget {
  const ChallengeTileArt({
    required this.kind,
    this.isOffChosen = false,
    super.key,
  });

  final ChallengeKind? kind;

  /// For the "No challenge" tile: whether it is the one in use.
  final bool isOffChosen;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final kind = this.kind;
    // A picture does not grow with the text size: it sits in a fixed frame.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: ExcludeSemantics(
        child: SizedBox(
          height: kChallengeArtHeight,
          width: double.infinity,
          child: switch (kind) {
            null => _OffArt(isChosen: isOffChosen),
            ChallengeKind.typeTopicName => ColoredBox(
              color: colors.panel,
              child: const Center(child: _TopicArt()),
            ),
            ChallengeKind.typeAlertTitle => ColoredBox(
              color: colors.onPanel,
              child: const Center(child: _TitleArt()),
            ),
            ChallengeKind.opsMath => ColoredBox(
              color: colors.highlight,
              child: const Center(child: _SumArt()),
            ),
            ChallengeKind.scratchCard => ColoredBox(
              color: colors.onPanel,
              child: const _ScratchArt(),
            ),
            ChallengeKind.shake => ColoredBox(
              color: colors.yellow,
              child: const Center(child: _CritArt()),
            ),
          },
        ),
      ),
    );
  }
}

/// The topic name, its first letters in yellow, the caret held visible and
/// the rest dim: the task as it opens.
class _TopicArt extends StatelessWidget {
  const _TopicArt();

  static const int _typed = 4;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final topic = LocaleKeys.personalize_sample_topic.tr();
    final cut = math.min(_typed, topic.length);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: topic.substring(0, cut),
                style: TextStyle(color: colors.yellow),
              ),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: SizedBox(
                    width: 3,
                    height: 26,
                    child: ColoredBox(color: colors.yellow),
                  ),
                ),
              ),
              TextSpan(
                text: topic.substring(cut),
                style: TextStyle(
                  color: colors.onPanelMuted.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          maxLines: 1,
          style: AppTypography.monoBold(colors.onPanel, fontSize: 25),
        ),
      ),
    );
  }
}

/// The alert title, set in two lines.
class _TitleArt extends StatelessWidget {
  const _TitleArt();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    // The sample title in two lines: its first word, then the rest.
    final title = LocaleKeys.personalize_sample_title.tr();
    final space = title.indexOf(' ');
    final lines = space < 0
        ? title
        : '${title.substring(0, space)}\n${title.substring(space + 1)}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          lines,
          textAlign: TextAlign.center,
          style: AppTypography.headline(colors.inkFixed, fontSize: 22).copyWith(
            letterSpacing: -0.44,
            height: 1.05,
          ),
        ),
      ),
    );
  }
}

/// One sum, with the answer left out.
class _SumArt extends StatelessWidget {
  const _SumArt();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: '7 + 5 = '), // l10n-ok: a sample sum
            TextSpan(
              text: '?', // l10n-ok: the missing answer
              style: TextStyle(color: colors.yellow),
            ),
          ],
        ),
        maxLines: 1,
        style: AppTypography.monoBold(colors.onHighlight, fontSize: 26),
      ),
    );
  }
}

/// Crit, upright, on the yellow tile. The face keeps its yellow fill and ink
/// outline in every theme.
class _CritArt extends StatelessWidget {
  const _CritArt();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return FaceWidget(
      state: FaceState.surprised,
      size: 66,
      tiltAngle: 0,
      overrideFillColor: colors.yellow,
      overrideStrokeColor: colors.inkFixed,
      overrideInkColor: colors.inkFixed,
    );
  }
}

/// A code with the card scratched half off: hatching over all of it but a
/// hole where the code shows.
class _ScratchArt extends StatelessWidget {
  const _ScratchArt();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Text(
            'K7Q2', // l10n-ok: a sample code
            maxLines: 1,
            style: AppTypography.monoBold(
              colors.inkFixed,
              fontSize: 26,
            ).copyWith(letterSpacing: 2.6),
          ),
        ),
        CustomPaint(
          painter: _HatchPainter(
            base: colors.yellow,
            stripe: Color.lerp(colors.yellow, colors.inkFixed, 0.08)!,
          ),
        ),
      ],
    );
  }
}

/// Diagonal hatching over the whole picture, cut by a hole.
class _HatchPainter extends CustomPainter {
  const _HatchPainter({required this.base, required this.stripe});

  final Color base;
  final Color stripe;

  /// The hole, on the 175 by 104 box it was drawn for.
  static Path _hole() => Path()
    ..moveTo(30, 66)
    ..cubicTo(40, 24, 96, 28, 118, 48)
    ..cubicTo(134, 66, 110, 82, 84, 78)
    ..cubicTo(60, 74, 40, 88, 30, 66)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    // The hole is widened about its middle and centred, so the whole code
    // shows in it at any width.
    final hole = _hole().transform(
      (Matrix4.diagonal3Values(size.width / 175, size.height / 104, 1)
            ..translateByDouble(87.5, 0, 0, 1)
            ..scaleByDouble(1.25, 1, 1, 1)
            ..translateByDouble(-82, 0, 0, 1))
          .storage,
    );
    final cover = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addPath(hole, Offset.zero);
    canvas
      ..save()
      ..clipPath(cover)
      ..drawRect(Offset.zero & size, Paint()..color = base)
      ..translate(size.width / 2, size.height / 2)
      ..rotate(math.pi / 4);
    final reach = size.longestSide;
    final paint = Paint()..color = stripe;
    for (var x = -reach; x < reach; x += 16) {
      canvas.drawRect(Rect.fromLTWH(x, -reach, 8, 2 * reach), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HatchPainter oldDelegate) =>
      oldDelegate.base != base || oldDelegate.stripe != stripe;
}

/// The "No challenge" tile's picture: a check while it is in use, a dash
/// while it is not.
class _OffArt extends StatelessWidget {
  const _OffArt({required this.isChosen});

  final bool isChosen;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: isChosen
          ? AppGlyph(
              GlyphType.check,
              size: 34,
              color: colors.yellow,
              strokeWidth: 3,
            )
          : AppGlyph(
              GlyphType.minus,
              size: 34,
              color: colors.onPanelMuted,
              strokeWidth: 3,
            ),
    );
  }
}
