import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/faces/refresh_face.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// Expressive stage container matching index.html .stage.
/// Displays a face, primary word headline, optional mono topic name,
/// and sub text.
class AppStage extends StatelessWidget {
  const AppStage({
    this.faceState,
    this.faceSize = 190.0,
    this.isLive = false,
    this.word,
    this.wordIsBig = false,
    this.wordFontSize,
    this.topicName,
    this.sub,
    this.padding = const EdgeInsets.fromLTRB(24, Spacing.s4, 24, 0),
    this.faceWidget,
    this.isHorizontal = false,
    super.key,
  });

  /// Horizontal stage matching index.html Settings mockup:
  /// 56px face aligned with subtext in a row.
  const AppStage.horizontal({
    required this.faceState,
    this.faceSize = 56.0,
    this.sub,
    this.isLive = false,
    this.padding = const EdgeInsets.fromLTRB(24, Spacing.s3, 24, 0),
    this.faceWidget,
    super.key,
  }) : word = null,
       wordIsBig = false,
       wordFontSize = null,
       topicName = null,
       isHorizontal = true;

  final FaceState? faceState;
  final double faceSize;
  final bool isLive;
  final String? word;
  final bool wordIsBig;
  final double? wordFontSize;
  final String? topicName;
  final String? sub;
  final EdgeInsetsGeometry padding;
  final Widget? faceWidget;
  final bool isHorizontal;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isShort = AppSize.of(context).isShort;

    if (isHorizontal) {
      return Padding(
        padding: padding,
        child: Row(
          children: [
            if (faceWidget != null)
              faceWidget!
            else if (faceState != null)
              stageFace(
                context,
                state: faceState!,
                size: faceSize,
                isLive: isLive,
              ),
            if (sub != null) ...[
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  sub!,
                  style: TextStyle(
                    fontFamily: AppTypography.fontBody,
                    fontFamilyFallback: AppTypography.fontBodyFallbacks,
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    color: colors.onCanvasMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final resolvedFontSize = wordFontSize ?? (wordIsBig ? 56.0 : 44.0);

    if (isShort) {
      // A short display has no room to stand the face above the words,
      // so the face sits beside them instead.
      return Padding(
        padding: padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (faceWidget != null)
              faceWidget!
            else if (faceState != null)
              stageFace(
                context,
                state: faceState!,
                size: faceSize.clamp(0.0, 96.0),
                isLive: isLive,
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (word != null) ...[
                    _buildWord(
                      colors,
                      resolvedFontSize * 0.7,
                      TextAlign.left,
                    ),
                  ],
                  if (topicName != null) ...[
                    const SizedBox(height: Spacing.s3),
                    _buildTopicName(colors, TextAlign.left),
                  ],
                  if (sub != null) ...[
                    const SizedBox(height: Spacing.s2),
                    _buildSub(colors, TextAlign.left),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (faceWidget != null)
            faceWidget!
          else if (faceState != null)
            stageFace(
              context,
              state: faceState!,
              size: faceSize,
              isLive: isLive,
            ),
          if (word != null) ...[
            SizedBox(height: faceSize > 120 ? Spacing.s5 : Spacing.s3),
            _buildWord(colors, resolvedFontSize, TextAlign.center),
          ],
          if (topicName != null) ...[
            const SizedBox(height: Spacing.s3),
            _buildTopicName(colors, TextAlign.center),
          ],
          if (sub != null) ...[
            const SizedBox(height: Spacing.s2),
            _buildSub(colors, TextAlign.center),
          ],
        ],
      ),
    );
  }

  Widget _buildWord(AppColors colors, double fontSize, TextAlign align) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        word!,
        textAlign: align,
        style: TextStyle(
          fontFamily: AppTypography.fontDisplay,
          fontFamilyFallback: AppTypography.fontDisplayFallbacks,
          fontWeight: FontWeight.w800,
          fontSize: fontSize,
          letterSpacing: -0.04 * fontSize,
          height: 1,
          color: colors.onCanvas,
        ),
      ),
    );
  }

  Widget _buildTopicName(AppColors colors, TextAlign align) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        topicName!,
        textAlign: align,
        style: TextStyle(
          fontFamily: AppTypography.fontMono,
          fontFamilyFallback: AppTypography.fontMonoFallbacks,
          fontWeight: FontWeight.w700,
          fontSize: 17,
          color: colors.onCanvas,
        ),
      ),
    );
  }

  Widget _buildSub(AppColors colors, TextAlign align) {
    return Text(
      sub!,
      textAlign: align,
      style: TextStyle(
        fontFamily: AppTypography.fontBody,
        fontFamilyFallback: AppTypography.fontBodyFallbacks,
        fontWeight: FontWeight.w500,
        fontSize: 15,
        color: colors.onCanvasMuted,
      ),
    );
  }
}
